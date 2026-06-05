// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../features/nodes/node_display_name_resolver.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../utils/text_sanitizer.dart';
import 'carplay_feature_flags.dart';

/// Dart side of the in-process CarPlay/SiriKit communication bridge.
///
/// The native SiriKit intent handlers (in the Runner target) relay
/// send/search/mark-read requests over the `com.socialmesh/carplay` channel.
/// This service answers them against [ProtocolService] and the message/node/
/// channel providers — the same paths the in-app UI uses. iOS-only.
///
/// Conversation id scheme (matches the native converters):
///   `dm-<nodeNum>` | `channel-<index>`.
class CarPlayIntentService {
  CarPlayIntentService(this._ref);

  static const MethodChannel _channel = MethodChannel('com.socialmesh/carplay');

  // Cap search results so Siri read-back stays bounded.
  static const int _maxSearchResults = 20;

  final Ref _ref;
  bool _isSetup = false;
  StreamSubscription<Message>? _donationSub;

  /// Register the handler and tell native the engine is ready (drains any
  /// intent that fired during cold start). Mirrors [AppIntentsService.setup].
  void setup() {
    if (_isSetup) return;
    if (!Platform.isIOS) return;
    _channel.setMethodCallHandler(_handleMethodCall);
    _isSetup = true;
    _channel.invokeMethod<void>('engineReady').catchError((Object e) {
      AppLogging.carplay('engineReady signal failed: $e');
      return null;
    });

    // Donation: when enabled, mirror each inbound/outbound message to SiriKit so
    // conversations appear in CarPlay Messages and Siri can read them aloud.
    // Opt-in (CARPLAY_COMMUNICATION_ENABLED) so notification behaviour is
    // unchanged for users who have not enabled the surface.
    if (CarPlayFeatureFlags.fromEnv().enabled) {
      final protocol = _ref.read(protocolServiceProvider);
      _donationSub = protocol.messageStream.listen(_donateMessage);
      AppLogging.carplay('Donation enabled; observing message stream.');
    }
    AppLogging.carplay('Intent service ready.');
  }

  void dispose() {
    _donationSub?.cancel();
    _donationSub = null;
  }

  void _donateMessage(Message m) {
    if (m.isEmoji) return;
    if (m.text.trim().isEmpty) return;
    final myNodeNum = _ref.read(myNodeNumProvider);
    if (myNodeNum == null) return;

    final bool isChannel = m.isBroadcast;
    final String conversationId;
    final String senderName;
    if (isChannel) {
      final idx = m.channel ?? 0;
      conversationId = 'channel-$idx';
      senderName = _channelName(idx);
    } else {
      final peer = m.from == myNodeNum ? m.to : m.from;
      if (peer == myNodeNum || peer == 0 || peer == 0xFFFFFFFF) return;
      conversationId = 'dm-$peer';
      senderName = _nodeName(
        _ref.read(nodesProvider),
        m.from == myNodeNum ? m.to : m.from,
        myNodeNum,
      );
    }

    _channel
        .invokeMethod<void>('donateMessage', {
          'conversationId': conversationId,
          'text': sanitizeExternalText(m.text),
          'senderName': senderName,
          'direction': m.from == myNodeNum ? 'outgoing' : 'incoming',
          'messageId': m.id,
          'isChannel': isChannel,
        })
        .catchError((Object e) {
          AppLogging.carplay('donateMessage failed: $e');
          return null;
        });
  }

  String _channelName(int index) {
    final channels = _ref.read(channelsProvider);
    for (final c in channels) {
      if (c.index == index) {
        final name = c.name.trim();
        if (name.isNotEmpty) return name;
      }
    }
    return index == 0 ? 'Primary Channel' : 'Channel $index';
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'carplaySend':
        return _handleSend(_asMap(call.arguments));
      case 'carplaySearch':
        return _handleSearch(_asMap(call.arguments));
      case 'carplayMarkRead':
        return _handleMarkRead(_asMap(call.arguments));
      case 'carplayMarkReadConversation':
        return _handleMarkReadConversation(_asMap(call.arguments));
      case 'carplayListConversations':
        return _handleListConversations();
      default:
        throw PlatformException(
          code: 'UNSUPPORTED',
          message: 'CarPlay method ${call.method} not supported',
        );
    }
  }

  Map<String, dynamic> _asMap(Object? args) =>
      (args as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

  // MARK: - Send

  Future<Map<String, dynamic>> _handleSend(Map<String, dynamic> args) async {
    final kind = args['kind'] as String?;
    final value = (args['value'] as num?)?.toInt();
    final text = (args['text'] as String?)?.trim() ?? '';
    if (kind == null || value == null || text.isEmpty) {
      return {'connected': true, 'sent': false};
    }

    final transport = _ref.read(transportProvider);
    if (!transport.isConnected) {
      AppLogging.carplay('Send blocked: radio not connected.');
      return {'connected': false, 'sent': false};
    }

    final to = kind == 'dm' ? value : 0;
    final channel = kind == 'channel' ? value : 0;

    try {
      final protocol = _ref.read(protocolServiceProvider);
      await protocol.sendMessage(
        text: text,
        to: to,
        channel: channel,
        source: MessageSource.siri,
      );
      AppLogging.carplay('Sent CarPlay message ($kind:$value).');
      return {'connected': true, 'sent': true};
    } on StateError catch (e) {
      // Not ready / disconnected mid-send.
      AppLogging.carplay('Send failed (state): $e');
      return {'connected': false, 'sent': false};
    } catch (e) {
      AppLogging.carplay('Send failed: $e');
      return {'connected': true, 'sent': false};
    }
  }

  // MARK: - Search

  Future<List<Map<String, dynamic>>> _handleSearch(
    Map<String, dynamic> args,
  ) async {
    final myNodeNum = _ref.read(myNodeNumProvider);
    if (myNodeNum == null) return const [];

    final convoFilter = (args['conversationIds'] as List?)
        ?.map((e) => e.toString())
        .toSet();
    final unreadOnly = args['unread'] as bool?;

    final messages = _ref.read(messagesProvider);
    final nodes = _ref.read(nodesProvider);

    final rows = <Map<String, dynamic>>[];
    // Newest first so Siri reads the most recent; cap the count.
    for (final m in messages.reversed) {
      if (rows.length >= _maxSearchResults) break;
      if (m.isEmoji) continue;

      final bool isChannel = m.isBroadcast;
      final String conversationId;
      final String senderName;
      if (isChannel) {
        conversationId = 'channel-${m.channel ?? 0}';
        senderName = _nodeName(nodes, m.from, myNodeNum);
      } else {
        final peer = m.from == myNodeNum ? m.to : m.from;
        if (peer == myNodeNum || peer == 0 || peer == 0xFFFFFFFF) continue;
        conversationId = 'dm-$peer';
        senderName = _nodeName(nodes, m.from, myNodeNum);
      }

      if (convoFilter != null && !convoFilter.contains(conversationId)) {
        continue;
      }
      if (unreadOnly == true && (m.read || m.from == myNodeNum)) continue;
      if (unreadOnly == false && !m.read && m.from != myNodeNum) continue;

      rows.add({
        'id': m.id,
        'text': sanitizeExternalText(m.text),
        'tsMs': m.timestamp.millisecondsSinceEpoch,
        'conversationId': conversationId,
        'senderName': senderName,
        'sentByMe': m.from == myNodeNum,
        'isChannel': isChannel,
      });
    }
    return rows;
  }

  // MARK: - Mark read

  Future<Map<String, dynamic>> _handleMarkRead(
    Map<String, dynamic> args,
  ) async {
    final identifiers = (args['identifiers'] as List?)
        ?.map((e) => e.toString())
        .toSet();
    if (identifiers == null || identifiers.isEmpty) {
      return {'ok': true};
    }

    final myNodeNum = _ref.read(myNodeNumProvider);
    final messages = _ref.read(messagesProvider);
    final notifier = _ref.read(messagesProvider.notifier);

    // Map each message id to its conversation, then mark that conversation read.
    final dmPeers = <int>{};
    final channels = <int>{};
    for (final m in messages) {
      if (!identifiers.contains(m.id)) continue;
      if (m.isBroadcast) {
        channels.add(m.channel ?? 0);
      } else {
        final peer = m.from == myNodeNum ? m.to : m.from;
        dmPeers.add(peer);
      }
    }
    for (final peer in dmPeers) {
      notifier.markConversationAsRead(peer);
    }
    for (final ch in channels) {
      notifier.markChannelAsRead(ch);
    }
    return {'ok': true};
  }

  // Read-tracking from the CarPlay communication notification tap (Phase 2).
  Future<Map<String, dynamic>> _handleMarkReadConversation(
    Map<String, dynamic> args,
  ) async {
    final conversationId = args['conversationId'] as String?;
    if (conversationId == null) return {'ok': true};
    final notifier = _ref.read(messagesProvider.notifier);
    if (conversationId.startsWith('dm-')) {
      final peer = int.tryParse(conversationId.substring(3));
      if (peer != null) notifier.markConversationAsRead(peer);
    } else if (conversationId.startsWith('channel-')) {
      final idx = int.tryParse(conversationId.substring(8));
      if (idx != null) notifier.markChannelAsRead(idx);
    }
    return {'ok': true};
  }

  // Build the CarPlay browse-UI snapshot: channel + DM conversations with last
  // message + unread count, channels first then DMs newest-first.
  Future<List<Map<String, dynamic>>> _handleListConversations() async {
    final myNodeNum = _ref.read(myNodeNumProvider);
    if (myNodeNum == null) return const [];

    final messages = _ref.read(messagesProvider);
    final nodes = _ref.read(nodesProvider);
    final channels = _ref.read(channelsProvider);

    final dmLast = <int, Message>{};
    final dmUnread = <int, int>{};
    final chanLast = <int, Message>{};
    final chanUnread = <int, int>{};

    for (final m in messages) {
      if (m.isEmoji) continue;
      if (m.isBroadcast) {
        final idx = m.channel ?? 0;
        final prev = chanLast[idx];
        if (prev == null || m.timestamp.isAfter(prev.timestamp)) {
          chanLast[idx] = m;
        }
        if (m.received && !m.read) {
          chanUnread[idx] = (chanUnread[idx] ?? 0) + 1;
        }
      } else {
        final peer = m.from == myNodeNum ? m.to : m.from;
        if (peer == myNodeNum || peer == 0 || peer == 0xFFFFFFFF) continue;
        final prev = dmLast[peer];
        if (prev == null || m.timestamp.isAfter(prev.timestamp)) {
          dmLast[peer] = m;
        }
        if (m.received && !m.read && m.from == peer) {
          dmUnread[peer] = (dmUnread[peer] ?? 0) + 1;
        }
      }
    }

    final rows = <Map<String, dynamic>>[];
    for (final c in channels) {
      final last = chanLast[c.index];
      rows.add({
        'conversationId': 'channel-${c.index}',
        'displayName': _channelName(c.index),
        'lastText': last == null ? '' : sanitizeExternalText(last.text),
        'lastTsMs': last?.timestamp.millisecondsSinceEpoch ?? 0,
        'unreadCount': chanUnread[c.index] ?? 0,
        'isChannel': true,
      });
    }

    final peers = dmLast.keys.toList()
      ..sort((a, b) => dmLast[b]!.timestamp.compareTo(dmLast[a]!.timestamp));
    for (final peer in peers) {
      final last = dmLast[peer]!;
      rows.add({
        'conversationId': 'dm-$peer',
        'displayName': _nodeName(nodes, peer, myNodeNum),
        'lastText': sanitizeExternalText(last.text),
        'lastTsMs': last.timestamp.millisecondsSinceEpoch,
        'unreadCount': dmUnread[peer] ?? 0,
        'isChannel': false,
      });
    }
    return rows;
  }

  String _nodeName(Map<int, MeshNode> nodes, int nodeNum, int myNodeNum) {
    if (nodeNum == myNodeNum) return 'Me';
    final node = nodes[nodeNum];
    return NodeDisplayNameResolver.resolve(
      nodeNum: nodeNum,
      longName: node?.longName,
      shortName: node?.shortName,
    );
  }
}

/// Provider for the in-process CarPlay intent service.
final carPlayIntentServiceProvider = Provider<CarPlayIntentService>((ref) {
  final service = CarPlayIntentService(ref);
  ref.onDispose(service.dispose);
  return service;
});
