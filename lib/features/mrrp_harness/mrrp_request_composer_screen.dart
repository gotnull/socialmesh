// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/mrrp_providers.dart';
import '../../providers/sip_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/protocol/sip/mrrp_advert_engine.dart';
import '../../services/protocol/sip/mrrp_constants.dart';
import '../../services/protocol/sip/mrrp_frame.dart';
import '../../services/protocol/sip/mrrp_types.dart';
import 'mrrp_response_viewer_screen.dart';

/// Request composer — build and send MRRP requests to discovered peers.
class MrrpRequestComposerScreen extends ConsumerStatefulWidget {
  final int? initialPeerNodeId;
  final int? initialServiceId;

  const MrrpRequestComposerScreen({
    this.initialPeerNodeId,
    this.initialServiceId,
    super.key,
  });

  @override
  ConsumerState<MrrpRequestComposerScreen> createState() =>
      _MrrpRequestComposerScreenState();
}

class _MrrpRequestComposerScreenState
    extends ConsumerState<MrrpRequestComposerScreen> {
  int? _selectedPeerId;
  int? _selectedServiceId;
  int? _selectedActionId;
  int _ttlSeconds = 15;
  final _payloadController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _selectedPeerId = widget.initialPeerNodeId;
    _selectedServiceId = widget.initialServiceId;
  }

  @override
  void dispose() {
    _payloadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cachedServices = ref.watch(mrrpCachedServicesProvider);
    final rateLimiter = ref.watch(sipRateLimiterProvider);

    final peerIds = cachedServices.keys.toList()..sort();

    // Services for selected peer.
    final peerServices = _selectedPeerId != null
        ? (cachedServices[_selectedPeerId] ?? <MrrpCachedService>[])
        : <MrrpCachedService>[];

    // Actions for selected service.
    final actions = _selectedServiceId != null
        ? _actionsForService(_selectedServiceId!)
        : <_ActionEntry>[];

    // Compute encoded size.
    final payloadBytes = _parseHexPayload(_payloadController.text);
    final encodedSize =
        MrrpConstants.mrrpHeaderMin + (payloadBytes?.length ?? 0);
    final exceedsMax =
        encodedSize >
        MrrpConstants.mrrpMaxPayload + MrrpConstants.mrrpHeaderMin;

    final canSend =
        _selectedPeerId != null &&
        _selectedServiceId != null &&
        _selectedActionId != null &&
        !exceedsMax &&
        rateLimiter.remainingBytes >= encodedSize &&
        !_sending;

    // lint-allow: haptic-feedback — keyboard dismissal, not interactive action
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: l10n.mrrpHarnessComposerTitle,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // --- Peer selector ---
                _buildDropdown<int>(
                  context: context,
                  label: l10n.mrrpHarnessSelectPeer,
                  value: _selectedPeerId,
                  items: peerIds.map((id) {
                    final hex =
                        '0x${id.toRadixString(16).padLeft(8, '0').toUpperCase()}';
                    return DropdownMenuItem(value: id, child: Text(hex));
                  }).toList(),
                  onChanged: (v) => setState(() {
                    _selectedPeerId = v;
                    _selectedServiceId = null;
                    _selectedActionId = null;
                  }),
                ),
                const SizedBox(height: AppTheme.spacing12),

                // --- Service selector ---
                _buildDropdown<int>(
                  context: context,
                  label: l10n.mrrpHarnessSelectService,
                  value: _selectedServiceId,
                  items: peerServices.map((svc) {
                    final name = MrrpServiceId.nameOf(svc.descriptor.serviceId);
                    return DropdownMenuItem(
                      value: svc.descriptor.serviceId,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() {
                    _selectedServiceId = v;
                    _selectedActionId = null;
                  }),
                ),
                const SizedBox(height: AppTheme.spacing12),

                // --- Action selector ---
                _buildDropdown<int>(
                  context: context,
                  label: l10n.mrrpHarnessSelectAction,
                  value: _selectedActionId,
                  items: actions
                      .map(
                        (a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedActionId = v),
                ),
                const SizedBox(height: AppTheme.spacing16),

                // --- Payload editor ---
                Text(
                  l10n.mrrpHarnessPayloadRawHex,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppTheme.spacing4),
                TextField(
                  controller: _payloadController,
                  maxLength: MrrpConstants.mrrpMaxPayload * 2,
                  decoration: InputDecoration(
                    hintText: 'DEADBEEF', // lint-allow: hardcoded-string
                    border: const OutlineInputBorder(),
                    errorText:
                        payloadBytes == null &&
                            _payloadController.text.isNotEmpty
                        ? 'Invalid hex' // lint-allow: hardcoded-string
                        : null,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace', // lint-allow: hardcoded-string
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppTheme.spacing8),

                // --- TTL selector ---
                Text(
                  l10n.mrrpHarnessRequestTtl,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppTheme.spacing4),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 5,
                      label: Text('5s'),
                    ), // lint-allow: hardcoded-string
                    ButtonSegment(
                      value: 10,
                      label: Text('10s'),
                    ), // lint-allow: hardcoded-string
                    ButtonSegment(
                      value: 15,
                      label: Text('15s'),
                    ), // lint-allow: hardcoded-string
                    ButtonSegment(
                      value: 30,
                      label: Text('30s'),
                    ), // lint-allow: hardcoded-string
                  ],
                  selected: {_ttlSeconds},
                  onSelectionChanged: (v) =>
                      setState(() => _ttlSeconds = v.first),
                ),
                const SizedBox(height: AppTheme.spacing16),

                // --- Encoded size ---
                Text(
                  l10n.mrrpHarnessEncodedSize(encodedSize),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: exceedsMax
                        ? SemanticColors.error
                        : context.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing24),

                // --- Send button ---
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canSend ? _onSend : null,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(l10n.mrrpHarnessSend),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required BuildContext context,
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing4,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _onSend() async {
    if (_selectedPeerId == null ||
        _selectedServiceId == null ||
        _selectedActionId == null) {
      return;
    }

    final localContext = context;
    ref.read(hapticServiceProvider).trigger(HapticType.medium);

    setState(() => _sending = true);

    final payload = _parseHexPayload(_payloadController.text) ?? Uint8List(0);

    final frame = MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.request,
      flags: MrrpFlags.ackRequired,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: 0, // will be assigned by dispatcher
      serviceId: _selectedServiceId!,
      actionId: _selectedActionId!,
      payloadLen: payload.length,
      payload: payload,
    );

    AppLogging.mrrpHarness(
      'MRRP_HARNESS: composer send to '
      'node=0x${_selectedPeerId!.toRadixString(16)} '
      'service=${MrrpServiceId.nameOf(_selectedServiceId!)} '
      'action=0x${_selectedActionId!.toRadixString(16)} '
      '${payload.length}B', // lint-allow: hardcoded-string
    );

    final dispatcher = ref.read(mrrpDispatcherProvider);
    if (dispatcher == null || !localContext.mounted) {
      setState(() => _sending = false);
      return;
    }

    final sentAt = DateTime.now();

    // Navigate to response viewer immediately.
    if (!localContext.mounted) return;
    Navigator.of(localContext).push(
      MaterialPageRoute<void>(
        builder: (_) => MrrpResponseViewerScreen(
          peerNodeId: _selectedPeerId!,
          serviceId: _selectedServiceId!,
          actionId: _selectedActionId!,
          sentAt: sentAt,
          resultFuture: dispatcher.sendRequest(frame),
        ),
      ),
    );

    if (mounted) {
      setState(() => _sending = false);
    }
  }

  List<_ActionEntry> _actionsForService(int serviceId) {
    if (serviceId == MrrpServiceId.meetupV1) {
      return [
        _ActionEntry(
          MeetupAction.create,
          'create',
        ), // lint-allow: hardcoded-string
        _ActionEntry(
          MeetupAction.accept,
          'accept',
        ), // lint-allow: hardcoded-string
        _ActionEntry(
          MeetupAction.cancel,
          'cancel',
        ), // lint-allow: hardcoded-string
        _ActionEntry(
          MeetupAction.inspect,
          'inspect',
        ), // lint-allow: hardcoded-string
      ];
    }
    if (serviceId == MrrpServiceId.profileV1) {
      return [
        _ActionEntry(
          ProfileAction.getSummary,
          'getSummary',
        ), // lint-allow: hardcoded-string
        _ActionEntry(
          ProfileAction.getContactCard,
          'getContactCard',
        ), // lint-allow: hardcoded-string
        _ActionEntry(
          ProfileAction.getCapabilities,
          'getCapabilities',
        ), // lint-allow: hardcoded-string
      ];
    }
    if (serviceId == MrrpServiceId.boardV1) {
      return [
        _ActionEntry(
          BoardAction.listRecent,
          'listRecent',
        ), // lint-allow: hardcoded-string
        _ActionEntry(
          BoardAction.postShort,
          'postShort',
        ), // lint-allow: hardcoded-string
        _ActionEntry(
          BoardAction.getPost,
          'getPost',
        ), // lint-allow: hardcoded-string
      ];
    }
    if (serviceId == MrrpServiceId.echoTest) {
      return [
        _ActionEntry(EchoAction.echo, 'echo'), // lint-allow: hardcoded-string
        _ActionEntry(
          EchoAction.echoError,
          'echoError',
        ), // lint-allow: hardcoded-string
        _ActionEntry(
          EchoAction.echoDelay,
          'echoDelay',
        ), // lint-allow: hardcoded-string
      ];
    }
    return [];
  }

  Uint8List? _parseHexPayload(String text) {
    final hex = text.replaceAll(RegExp(r'\s+'), '');
    if (hex.isEmpty) return Uint8List(0);
    if (hex.length.isOdd) return null;
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) return null;

    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }
}

class _ActionEntry {
  final int id;
  final String name;
  const _ActionEntry(this.id, this.name);
}
