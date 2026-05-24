// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold (embedded tab panel, GlassScaffold provided by container)

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../utils/text_sanitizer.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../nodedex/widgets/tappable_node_avatar.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../models/presence_confidence.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/file_transfer_providers.dart';
import '../../../providers/presence_providers.dart';
import '../../../services/file_transfer/file_transfer_engine.dart';
import '../../../services/haptic_service.dart';
import '../../../providers/voice_quality_provider.dart';
import '../../../services/voice/voice_constants.dart';
import '../../../services/voice/voice_message_service.dart';
import '../../../services/voice/voice_permission_service.dart';
import '../../../utils/presence_utils.dart';
import '../../../utils/snackbar.dart';
import '../../nodes/node_display_name_resolver.dart';
import '../../nodedex/widgets/sigil_painter.dart';
import '../widgets/file_content_preview.dart';
import '../widgets/file_transfer_card.dart';
import '../widgets/file_transfer_image_gallery.dart';

import '../widgets/voice_recording_overlay.dart';

// ---------------------------------------------------------------------------
// Filter enum
// ---------------------------------------------------------------------------

enum _FileContactFilter { all, active, hasFiles, favorites }

enum _RecordingAction { send, cancel }

// ---------------------------------------------------------------------------
// Contact model
// ---------------------------------------------------------------------------

/// Unified contact model — includes presence + transfer stats.
class _Contact {
  final int nodeNum;
  final String displayName;
  final String? shortName;
  final int? avatarColor;
  final PresenceConfidence presence;
  final Duration? lastHeardAge;
  final DateTime? lastHeard;
  final bool isFavorite;

  // Transfer stats (0 when no transfers yet)
  final int transferCount;
  final int sentCount;
  final int receivedCount;
  final int totalBytes;
  final int activeTransferCount;
  final DateTime? lastTransferAt;
  final String? lastTransferFilename;

  const _Contact({
    required this.nodeNum,
    required this.displayName,
    this.shortName,
    this.avatarColor,
    this.presence = PresenceConfidence.unknown,
    this.lastHeardAge,
    this.lastHeard,
    this.isFavorite = false,
    this.transferCount = 0,
    this.sentCount = 0,
    this.receivedCount = 0,
    this.totalBytes = 0,
    this.activeTransferCount = 0,
    this.lastTransferAt,
    this.lastTransferFilename,
  });

  bool get hasTransfers => transferCount > 0;
  bool get hasActiveTransfers => activeTransferCount > 0;
  bool get isOnline =>
      PresenceCalculator.isOnline(lastHeard, now: DateTime.now());
}

// ---------------------------------------------------------------------------
// Contacts tab
// ---------------------------------------------------------------------------

/// Contacts tab showing ALL known mesh nodes, with transfer stats for nodes
/// the user has exchanged files with. Mirrors the Messages Contacts tab.
class FileTransferContactsScreen extends ConsumerStatefulWidget {
  const FileTransferContactsScreen({super.key});

  @override
  ConsumerState<FileTransferContactsScreen> createState() =>
      _FileTransferContactsScreenState();
}

class _FileTransferContactsScreenState
    extends ConsumerState<FileTransferContactsScreen>
    with LifecycleSafeMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  _FileContactFilter _currentFilter = _FileContactFilter.all;
  bool _showSectionHeaders = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final presenceMap = ref.watch(presenceMapProvider);
    final transferState = ref.watch(fileTransferStateProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Accumulate transfer stats per node from the transfer list
    final accMap = <int, _ContactAccumulator>{};
    for (final t in transferState.sortedTransfers) {
      final nodeNum = t.direction == TransferDirection.outbound
          ? t.targetNodeNum
          : t.sourceNodeNum;
      if (nodeNum == null) continue;
      final acc = accMap[nodeNum] ??= _ContactAccumulator(nodeNum: nodeNum);
      acc.transferCount++;
      if (t.isActive) acc.activeTransferCount++;
      if (t.direction == TransferDirection.outbound) {
        acc.sentCount++;
      } else {
        acc.receivedCount++;
      }
      acc.totalBytes += t.totalBytes;
      final dt = t.completedAt ?? t.createdAt;
      if (acc.lastTransferAt == null || dt.isAfter(acc.lastTransferAt!)) {
        acc.lastTransferAt = dt;
        acc.lastTransferFilename = t.filename;
      }
    }

    // Build contacts from ALL nodes except self (like Messages contacts tab)
    final contacts = <_Contact>[];
    for (final node in nodes.values) {
      if (node.nodeNum == myNodeNum) continue;
      final acc = accMap[node.nodeNum];
      contacts.add(
        _Contact(
          nodeNum: node.nodeNum,
          displayName: node.displayName,
          shortName: node.shortName,
          avatarColor: node.avatarColor,
          presence: presenceConfidenceFor(presenceMap, node),
          lastHeardAge: lastHeardAgeFor(presenceMap, node),
          lastHeard: node.lastHeard,
          isFavorite: node.isFavorite,
          transferCount: acc?.transferCount ?? 0,
          sentCount: acc?.sentCount ?? 0,
          receivedCount: acc?.receivedCount ?? 0,
          totalBytes: acc?.totalBytes ?? 0,
          activeTransferCount: acc?.activeTransferCount ?? 0,
          lastTransferAt: acc?.lastTransferAt,
          lastTransferFilename: acc?.lastTransferFilename,
        ),
      );
    }

    // Also include nodes that have transfers but left the mesh
    for (final acc in accMap.values) {
      if (nodes.containsKey(acc.nodeNum)) continue;
      contacts.add(
        _Contact(
          nodeNum: acc.nodeNum,
          displayName: NodeDisplayNameResolver.defaultName(acc.nodeNum),
          shortName: NodeDisplayNameResolver.defaultShortName(acc.nodeNum),
          isFavorite: false,
          transferCount: acc.transferCount,
          sentCount: acc.sentCount,
          receivedCount: acc.receivedCount,
          totalBytes: acc.totalBytes,
          activeTransferCount: acc.activeTransferCount,
          lastTransferAt: acc.lastTransferAt,
          lastTransferFilename: acc.lastTransferFilename,
        ),
      );
    }

    // Sort: has transfers → favorites → active → alphabetical
    contacts.sort((a, b) {
      if (a.hasTransfers != b.hasTransfers) return a.hasTransfers ? -1 : 1;
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      if (a.isOnline != b.isOnline) {
        return a.isOnline ? -1 : 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    // Compute counts for filter chips
    final favoritesCount = contacts.where((c) => c.isFavorite).length;
    final activeCount = contacts.where((c) => c.isOnline).length;
    final hasFilesCount = contacts.where((c) => c.hasTransfers).length;

    // Apply filter chip
    var filtered = contacts;
    switch (_currentFilter) {
      case _FileContactFilter.all:
        break;
      case _FileContactFilter.active:
        filtered = contacts.where((c) => c.isOnline).toList();
      case _FileContactFilter.hasFiles:
        filtered = contacts.where((c) => c.hasTransfers).toList();
      case _FileContactFilter.favorites:
        filtered = contacts.where((c) => c.isFavorite).toList();
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        return c.displayName.toLowerCase().contains(q) ||
            (c.shortName?.toLowerCase().contains(q) ?? false) ||
            '!${c.nodeNum.toRadixString(16)}'.contains(q);
      }).toList();
    }

    final textScaler = MediaQuery.textScalerOf(context);

    final bodyContent = CustomScrollView(
      // Always embedded inside TabBarView within GlassScaffold's outer
      // CustomScrollView. Use ClampingScrollPhysics to avoid bounce-fighting
      // with the outer BouncingScrollPhysics (kGlassScrollPhysics), and
      // primary: false so it doesn't compete for PrimaryScrollController.
      physics: const ClampingScrollPhysics(),
      primary: false,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: SearchFilterHeaderDelegate(
            searchController: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            hintText: context.l10n.fileTransferContactsSearchHint,
            textScaler: textScaler,
            rebuildKey: Object.hashAll([
              _currentFilter,
              contacts.length,
              activeCount,
              hasFilesCount,
              favoritesCount,
              _showSectionHeaders,
            ]),
            trailingControls: [
              SectionHeadersToggle(
                enabled: _showSectionHeaders,
                onToggle: () =>
                    setState(() => _showSectionHeaders = !_showSectionHeaders),
              ),
            ],
            filterChips: [
              StatusFilterChip(
                label: context.l10n.fileTransferContactsFilterAll,
                count: contacts.length,
                isSelected: _currentFilter == _FileContactFilter.all,
                onTap: () =>
                    setState(() => _currentFilter = _FileContactFilter.all),
              ),
              StatusFilterChip(
                label: context.l10n.fileTransferContactsFilterActive,
                count: activeCount,
                isSelected: _currentFilter == _FileContactFilter.active,
                color: AccentColors.green,
                onTap: () =>
                    setState(() => _currentFilter = _FileContactFilter.active),
              ),
              StatusFilterChip(
                label: context.l10n.fileTransferContactsFilterHasFiles,
                count: hasFilesCount,
                isSelected: _currentFilter == _FileContactFilter.hasFiles,
                icon: Icons.attach_file,
                color: AppTheme.primaryBlue,
                onTap: () => setState(
                  () => _currentFilter = _FileContactFilter.hasFiles,
                ),
              ),
              StatusFilterChip(
                label: context.l10n.fileTransferContactsFilterFavorites,
                count: favoritesCount,
                isSelected: _currentFilter == _FileContactFilter.favorites,
                icon: Icons.star,
                color: AppTheme.warningYellow,
                onTap: () => setState(
                  () => _currentFilter = _FileContactFilter.favorites,
                ),
              ),
            ],
          ),
        ),

        // Empty state
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: AppTheme.spacing64 + AppTheme.spacing8,
                    height: AppTheme.spacing64 + AppTheme.spacing8,
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius16),
                    ),
                    child: Icon(
                      Icons.people_outline,
                      size: AppTheme.spacing40,
                      color: context.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing24),
                  Text(
                    _searchQuery.isNotEmpty
                        ? context.l10n.fileTransferContactsNoMatchSearch(
                            _searchQuery,
                          )
                        : _currentFilter != _FileContactFilter.all
                        ? context.l10n.fileTransferContactsNoMatchFilter(
                            _currentFilter.name,
                          )
                        : context.l10n.fileTransferContactsNoNodes,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.textSecondary,
                    ),
                  ),
                  if (_searchQuery.isEmpty) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      context.l10n.fileTransferContactsDiscoveredHint,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacing12),
                    TextButton(
                      onPressed: () => setState(() => _searchQuery = ''),
                      child: Text(context.l10n.fileTransferContactsClearSearch),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          ..._buildContactSlivers(filtered),
      ],
    );

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Container(color: context.background, child: bodyContent),
    );
  }

  List<Widget> _buildContactSlivers(List<_Contact> contacts) {
    final animationsEnabled = ref.watch(animationsEnabledProvider);

    if (!_showSectionHeaders) {
      return [
        SliverPadding(
          padding: const EdgeInsets.only(top: AppTheme.spacing8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, index) => Perspective3DSlide(
                index: index,
                direction: SlideDirection.left,
                enabled: animationsEnabled,
                child: _ContactTile(
                  contact: contacts[index],
                  onTap: () => _openContactDetail(contacts[index]),
                ),
              ),
              childCount: contacts.length,
            ),
          ),
        ),
      ];
    }

    // Grouped sections: Has Files first, then Favorites (without files),
    // then Active (without files, not favorite), then Inactive remainder.
    final withFiles = contacts.where((c) => c.hasTransfers).toList();
    final favorites = contacts
        .where((c) => c.isFavorite && !c.hasTransfers)
        .toList();
    final active = contacts
        .where((c) => !c.hasTransfers && !c.isFavorite && c.isOnline)
        .toList();
    final inactive = contacts
        .where((c) => !c.hasTransfers && !c.isFavorite && !c.isOnline)
        .toList();

    Widget buildSection(String title, List<_Contact> group) {
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: SectionHeader(title: title, count: group.length),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, index) => Perspective3DSlide(
                index: index,
                direction: SlideDirection.left,
                enabled: animationsEnabled,
                child: _ContactTile(
                  contact: group[index],
                  onTap: () => _openContactDetail(group[index]),
                ),
              ),
              childCount: group.length,
            ),
          ),
        ],
      );
    }

    return [
      if (withFiles.isNotEmpty)
        buildSection(
          context.l10n.fileTransferContactsSectionWithFiles,
          withFiles,
        ),
      if (favorites.isNotEmpty)
        buildSection(
          context.l10n.fileTransferContactsSectionFavorites,
          favorites,
        ),
      if (active.isNotEmpty)
        buildSection(context.l10n.fileTransferContactsSectionActive, active),
      if (inactive.isNotEmpty)
        buildSection(
          context.l10n.fileTransferContactsSectionInactive,
          inactive,
        ),
    ];
  }

  void _openContactDetail(_Contact contact) {
    final transfers = ref.read(nodeTransfersProvider(contact.nodeNum));
    _ContactDetailSheet.show(
      context: context,
      contact: contact,
      transfers: transfers,
      onSendFile: () => _sendFileToContact(contact.nodeNum),
      onSendImage: () => _sendImageToContact(contact.nodeNum),
      onSendVoice: AppFeatureFlags.isVoiceMessagesEnabled
          ? () => _sendVoiceToContact(contact.nodeNum)
          : null,
    );
    ref.read(hapticServiceProvider).trigger(HapticType.light);
  }

  Future<void> _sendFileToContact(int nodeNum) async {
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    await haptics.trigger(HapticType.medium);
    if (!mounted) return;

    final transfer = await notifier.pickAndSendFile(targetNodeNum: nodeNum);
    if (!mounted) return;
    if (transfer != null) {
      showSuccessSnackBar(
        context,
        context.l10n.fileTransferContactsStarted(transfer.filename),
      );
    }
  }

  Future<void> _sendImageToContact(int nodeNum) async {
    AppLogging.fileTransfer(
      '_sendImageToContact: target=!${nodeNum.toRadixString(16)}',
    );
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    await haptics.trigger(HapticType.medium);
    if (!mounted) return;

    final transfer = await notifier.pickAndSendImage(targetNodeNum: nodeNum);
    if (!mounted) return;
    if (transfer != null) {
      AppLogging.fileTransfer(
        '_sendImageToContact: transfer started — '
        'id=${transfer.fileIdHex}, file=${transfer.filename}, '
        '${transfer.totalBytes} bytes, ${transfer.chunkCount} chunks',
      );
      showSuccessSnackBar(
        context,
        context.l10n.fileTransferContactsStarted(transfer.filename),
      );
    } else {
      AppLogging.fileTransfer(
        '_sendImageToContact: pickAndSendImage returned null for '
        'node !${nodeNum.toRadixString(16)}',
      );
    }
  }

  Future<void> _sendVoiceToContact(int nodeNum) async {
    AppLogging.voice(
      '_sendVoiceToContact: target=!${nodeNum.toRadixString(16)}',
    );
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    await haptics.trigger(HapticType.medium);
    if (!mounted) return;

    final nav = Navigator.of(context, rootNavigator: true);

    final quality = ref.read(voiceQualityProvider);
    final qualityNotifier = ValueNotifier<VoiceQuality>(quality);

    // Persist quality preference when the user changes it in the overlay.
    void onQualityChanged() {
      ref.read(voiceQualityProvider.notifier).setQuality(qualityNotifier.value);
    }

    qualityNotifier.addListener(onQualityChanged);
    var voiceService = VoiceMessageService(quality: quality);
    final actionCompleter = Completer<_RecordingAction>();
    final autoStopNotifier = ValueNotifier<bool>(false);
    var wasAutoStopped = false;
    // Holds the Future from stopSession() once the user taps the stop circle
    // or auto-stop fires. Allows the .send case to await it idempotently.
    Future<VoiceMessageResult>? pendingStop;

    Future<bool> startFresh() async {
      return voiceService.startSession(
        onAutoStop: () {
          wasAutoStopped = true;
          // Stop the recording and signal the overlay to enter review mode.
          // The user must tap Send to confirm; we no longer auto-send.
          pendingStop ??= voiceService.stopSession();
          autoStopNotifier.value = true;
        },
      );
    }

    // Check microphone permission before showing the overlay. The overlay
    // starts in idle state — recording only begins when the user taps record.
    final hasMic = await VoicePermissionService.requestMicrophonePermission();
    if (!hasMic) {
      AppLogging.voice('_sendVoiceToContact: microphone permission denied');
      autoStopNotifier.dispose();
      await voiceService.dispose();
      if (!mounted) return;
      final showSettings =
          Platform.isIOS ||
          await VoicePermissionService.isMicrophonePermanentlyDenied();
      if (!mounted) return;
      _showVoicePermissionSnackBar(showSettings);
      return;
    }

    if (!mounted) {
      autoStopNotifier.dispose();
      await voiceService.dispose();
      return;
    }

    // Show the fullscreen recording overlay in idle state. Using
    // showGeneralDialog ensures the overlay inherits the MaterialApp theme.
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) =>
          VoiceRecordingOverlay(
            maxRecordingDuration: quality.maxRecordingDuration,
            qualityNotifier: qualityNotifier,
            // User tapped the big red record button from idle state.
            onStartRecording: () async {
              // Tear down any previous session (after retake).
              if (pendingStop != null) {
                pendingStop = null;
              } else {
                await voiceService.cancelSession();
              }
              await voiceService.dispose();
              // Create a fresh service with the current quality.
              pendingStop = null;
              wasAutoStopped = false;
              autoStopNotifier.value = false;
              final currentQuality = qualityNotifier.value;
              voiceService = VoiceMessageService(quality: currentQuality);
              final started = await startFresh();
              if (!started) return null;
              return voiceService.amplitudeStream;
            },
            // Circle tapped: stop the mic; overlay transitions to review mode.
            onRecordingStopped: () {
              pendingStop ??= voiceService.stopSession();
            },
            onPauseRecording: () => voiceService.pauseSession(),
            onResumeRecording: () => voiceService.resumeSession(),
            // Provide the encoded .c2 payload for in-place preview playback.
            onGetPreviewPayload: () async {
              final result = await (pendingStop ?? voiceService.stopSession());
              return result.payload;
            },
            // Send confirmed in review phase.
            onSend: () {
              if (!actionCompleter.isCompleted) {
                actionCompleter.complete(_RecordingAction.send);
              }
            },
            onCancel: () {
              if (!actionCompleter.isCompleted) {
                actionCompleter.complete(_RecordingAction.cancel);
              }
            },
            onRestart: () async {
              // Discard any in-flight stop, tear down current session.
              if (pendingStop == null) await voiceService.cancelSession();
              await voiceService.dispose();
              // Reset stateful locals for the fresh session.
              pendingStop = null;
              wasAutoStopped = false;
              autoStopNotifier.value = false;
              final currentQuality = qualityNotifier.value;
              voiceService = VoiceMessageService(quality: currentQuality);
              await startFresh();
              return voiceService.amplitudeStream;
            },
            autoStopNotifier: autoStopNotifier,
          ),
    );

    final action = await actionCompleter.future;
    if (nav.canPop()) nav.pop();
    autoStopNotifier.dispose();
    qualityNotifier.removeListener(onQualityChanged);
    qualityNotifier.dispose();
    if (!mounted) {
      if (pendingStop == null) await voiceService.cancelSession();
      await voiceService.dispose();
      return;
    }

    switch (action) {
      case _RecordingAction.send:
        AppLogging.voice(
          '_sendVoiceToContact: user confirmed send '
          '(autoStopped=$wasAutoStopped)',
        );
        if (wasAutoStopped) {
          showInfoSnackBar(context, context.l10n.voiceMessageAutoStopped);
        }
        // pendingStop is always set before .send can fire (the Stop circle
        // or auto-stop must have fired first in review phase).
        final result = await (pendingStop ?? voiceService.stopSession());
        AppLogging.voice(
          '_sendVoiceToContact: stopSession result='
          '${result.outcome.name}'
          '${result.payload != null ? ", ${result.payload!.length} bytes" : ""}',
        );
        if (!mounted) return;
        await _handleVoiceResult(result, nodeNum, notifier);
        await voiceService.dispose();

      case _RecordingAction.cancel:
        AppLogging.voice('_sendVoiceToContact: user cancelled');
        // If pendingStop is set, stopSession() is already running; just
        // let it finish and discard. Otherwise cancel normally.
        if (pendingStop == null) await voiceService.cancelSession();
        await voiceService.dispose();
    }
  }

  void _showVoicePermissionSnackBar(bool permanently) {
    if (!mounted) return;
    if (permanently) {
      showActionSnackBar(
        context,
        context.l10n.voiceMessagePermissionDenied,
        actionLabel: context.l10n.voiceMessagePermissionSettings,
        onAction: () => VoicePermissionService.openSettings(),
      );
    } else {
      showInfoSnackBar(context, context.l10n.voiceMessagePermissionDenied);
    }
  }

  void _showVoiceSendResultSnackBar(bool sent) {
    if (!mounted) return;
    if (sent) {
      showSuccessSnackBar(context, context.l10n.voiceMessageSent);
    } else {
      showErrorSnackBar(context, context.l10n.voiceMessageFailed);
    }
  }

  Future<void> _handleVoiceResult(
    VoiceMessageResult result,
    int nodeNum,
    FileTransferStateNotifier notifier,
  ) async {
    if (!mounted) return;
    switch (result.outcome) {
      case VoiceMessageOutcome.success:
        AppLogging.voice(
          '_handleVoiceResult: success, '
          '${result.payload!.length} bytes, '
          'target=!${nodeNum.toRadixString(16)}',
        );
        final transfer = await notifier.sendVoiceMessage(
          result.payload!,
          targetNodeNum: nodeNum,
        );
        if (!mounted) return;
        AppLogging.voice(
          '_handleVoiceResult: sendVoiceMessage '
          '${transfer != null ? "OK (id=${transfer.fileIdHex})" : "FAILED"}',
        );
        _showVoiceSendResultSnackBar(transfer != null);
      case VoiceMessageOutcome.tooShort:
        AppLogging.voice('_handleVoiceResult: tooShort');
        showInfoSnackBar(context, context.l10n.voiceMessageTooShort);
      case VoiceMessageOutcome.failed:
        AppLogging.voice('_handleVoiceResult: failed');
        showErrorSnackBar(context, context.l10n.voiceMessageFailed);
    }
  }
}

// ---------------------------------------------------------------------------
// Transfer stats accumulator (internal build helper)
// ---------------------------------------------------------------------------

class _ContactAccumulator {
  final int nodeNum;
  int transferCount = 0;
  int activeTransferCount = 0;
  int sentCount = 0;
  int receivedCount = 0;
  int totalBytes = 0;
  DateTime? lastTransferAt;
  String? lastTransferFilename;

  _ContactAccumulator({required this.nodeNum});
}

// ---------------------------------------------------------------------------
// Contact tile — mirrors Messages _ContactTile exactly
// ---------------------------------------------------------------------------

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});

  final _Contact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shortText = contact.shortName ?? safeTruncate(contact.displayName, 2);

    final subtitle = contact.hasTransfers
        ? '${contact.transferCount} '
              'file${contact.transferCount == 1 ? '' : 's'} transferred'
        : presenceStatusText(contact.presence, contact.lastHeardAge);

    final subtitleColor = !contact.hasTransfers && contact.presence.isActive
        ? AppTheme.successGreen
        : context.textTertiary;

    final cardContent = Padding(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      child: Row(
        children: [
          // Avatar with presence dot
          Stack(
            children: [
              TappableNodeAvatar(
                nodeNum: contact.nodeNum,
                text: shortText,
                color: contact.avatarColor != null
                    ? Color(contact.avatarColor!)
                    : AppTheme.graphPurple,
                size: 48,
              ),
              if (contact.presence.isActive)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.card, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppTheme.spacing12),

          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        contact.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Active transfers badge (mirrors unread badge in Messages)
                    if (contact.hasActiveTransfers) ...[
                      const SizedBox(width: AppTheme.spacing8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing8,
                          vertical: AppTheme.spacing2,
                        ),
                        decoration: BoxDecoration(
                          color: context.accentColor,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius10,
                          ),
                        ),
                        child: Text(
                          '${contact.activeTransferCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: subtitleColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: AppTheme.spacing8),
          if (contact.isFavorite)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacing8),
              child: Icon(Icons.star, color: AccentColors.yellow, size: 20),
            ),
          Icon(Icons.chevron_right, color: context.textTertiary),
        ],
      ),
    );

    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.98,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing4,
        ),
        decoration: !contact.isFavorite
            ? BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(AppTheme.radius16),
                border: Border.all(
                  color: context.border.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              )
            : null,
        child: contact.isFavorite
            ? GradientBorderContainer(
                borderRadius: 16,
                borderWidth: 1,
                accentOpacity: 1.0,
                accentColor: AccentColors.yellow,
                backgroundColor: context.card,
                child: cardContent,
              )
            : cardContent,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact detail sheet
// ---------------------------------------------------------------------------

class _ContactDetailSheet extends StatelessWidget {
  const _ContactDetailSheet({
    required this.contact,
    required this.transfers,
    required this.onSendFile,
    required this.onSendImage,
    required this.scrollController,
    this.onSendVoice,
  });

  final _Contact contact;
  final List<FileTransferState> transfers;
  final VoidCallback onSendFile;
  final VoidCallback onSendImage;
  final VoidCallback? onSendVoice;
  final ScrollController scrollController;

  static void show({
    required BuildContext context,
    required _Contact contact,
    required List<FileTransferState> transfers,
    required VoidCallback onSendFile,
    required VoidCallback onSendImage,
    VoidCallback? onSendVoice,
  }) {
    // Taller initial size when there are transfers so they're immediately
    // visible; fall back to a compact size when there's nothing to show.
    final initialSize = transfers.isNotEmpty ? 0.72 : 0.48;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: initialSize,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: ctx.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radius20),
              ),
            ),
            child: _ContactDetailSheet(
              contact: contact,
              transfers: transfers,
              onSendFile: onSendFile,
              onSendImage: onSendImage,
              onSendVoice: onSendVoice,
              scrollController: scrollController,
            ),
          );
        },
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB';
  }

  String _relativeTime(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return context.l10n.fileTransferContactsJustNow;
    if (diff.inMinutes < 60) {
      return context.l10n.fileTransferContactsMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return context.l10n.fileTransferContactsHoursAgo(diff.inHours);
    }
    if (diff.inDays < 7) {
      return context.l10n.fileTransferContactsDaysAgo(diff.inDays);
    }
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final shortText = contact.shortName ?? safeTruncate(contact.displayName, 2);

    final isActive = contact.presence.isActive;

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        // ── Drag pill ────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppTheme.spacing12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
            ),
          ),
        ),

        // ── Compact identity row ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing20,
              AppTheme.spacing16,
              AppTheme.spacing20,
              AppTheme.spacing12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SigilAvatar(nodeNum: contact.nodeNum, size: AppTheme.spacing48),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Row(
                        children: [
                          Text(
                            '!${contact.nodeNum.toRadixString(16)}',
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacing6,
                              vertical: AppTheme.spacing1,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.successGreen.withValues(
                                      alpha: 0.15,
                                    )
                                  : context.border.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius4,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppTheme.successGreen
                                        : context.textTertiary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacing4),
                                Text(
                                  presenceStatusText(
                                    contact.presence,
                                    contact.lastHeardAge,
                                  ),
                                  style: TextStyle(
                                    color: isActive
                                        ? AppTheme.successGreen
                                        : context.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // NodeAvatar fallback (shown when sigil is not available)
                if (contact.avatarColor != null)
                  TappableNodeAvatar(
                    nodeNum: contact.nodeNum,
                    text: shortText,
                    color: Color(contact.avatarColor!),
                    size: AppTheme.spacing40,
                  ),
              ],
            ),
          ),
        ),

        // ── Stats strip ──────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing10,
              ),
              decoration: BoxDecoration(
                color: context.cardAlt,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(
                  color: context.border.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  _InlineStat(
                    icon: Icons.arrow_upward,
                    value: '${contact.sentCount}',
                    label: context.l10n.fileTransferContactsDetailSent,
                    color: AppTheme.primaryBlue,
                  ),
                  _StatDivider(),
                  _InlineStat(
                    icon: Icons.arrow_downward,
                    value: '${contact.receivedCount}',
                    label: context.l10n.fileTransferContactsDetailReceived,
                    color: AppTheme.primaryPurple,
                  ),
                  _StatDivider(),
                  _InlineStat(
                    icon: Icons.data_usage,
                    value: _formatBytes(contact.totalBytes),
                    label: context.l10n.fileTransferContactsDetailTotal,
                    color: context.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Action pills ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing20,
              AppTheme.spacing12,
              AppTheme.spacing20,
              AppTheme.spacing4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ActionPill(
                    icon: Icons.attach_file,
                    label: context.l10n.fileTransferContactsSendFile,
                    color: context.accentColor,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSendFile();
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: _ActionPill(
                    icon: Icons.image_outlined,
                    label: context.l10n.fileTransferContactsSendImage,
                    color: context.accentColor,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSendImage();
                    },
                  ),
                ),
                if (onSendVoice != null) ...[
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: _ActionPill(
                      icon: Icons.mic_none,
                      label: context.l10n.fileTransferContactsSendVoice,
                      color: AccentColors.cyan,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSendVoice!();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Recent transfers header ───────────────────────────────────────────
        if (transfers.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing20,
                AppTheme.spacing20,
                AppTheme.spacing20,
                AppTheme.spacing8,
              ),
              child: Row(
                children: [
                  Text(
                    'RECENT TRANSFERS',
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing6,
                      vertical: AppTheme.spacing1,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radius4),
                    ),
                    child: Text(
                      '${transfers.length}',
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (transfers.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing20,
                AppTheme.spacing24,
                AppTheme.spacing20,
                AppTheme.spacing8,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 36,
                    color: context.textTertiary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    'No transfers yet',
                    style: TextStyle(color: context.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

        // ── Transfer history list ─────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing4,
            AppTheme.spacing16,
            AppTheme.spacing8,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((ctx, index) {
              final t = transfers[index];
              final canPreview =
                  (t.fileBytes != null && t.fileBytes!.isNotEmpty) ||
                  t.savedFilePath != null;
              return _CompactTransferRow(
                transfer: t,
                relativeTime: _relativeTime(ctx, t.completedAt ?? t.createdAt),
                onTap: canPreview
                    ? () {
                        if (FileTransferImageGallery.canShow(t)) {
                          FileTransferImageGallery.show(ctx, transfer: t);
                        } else {
                          FileContentPreview.show(context: ctx, transfer: t);
                        }
                      }
                    : null,
              );
            }, childCount: transfers.length),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing24)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Inline stat (compact horizontal stat cell)
// ---------------------------------------------------------------------------

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppTheme.spacing4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: context.textTertiary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat divider (thin vertical separator between inline stats)
// ---------------------------------------------------------------------------

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
      color: context.border.withValues(alpha: 0.3),
    );
  }
}

// ---------------------------------------------------------------------------
// Action pill button
// ---------------------------------------------------------------------------

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppTheme.spacing6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact transfer row (in detail sheet)
// ---------------------------------------------------------------------------

class _CompactTransferRow extends StatelessWidget {
  const _CompactTransferRow({
    required this.transfer,
    required this.relativeTime,
    this.onTap,
  });

  final FileTransferState transfer;
  final String relativeTime;
  final VoidCallback? onTap;

  IconData get _stateIcon => switch (transfer.state) {
    TransferState.created ||
    TransferState.offerSent ||
    TransferState.awaitingAccept => Icons.schedule,
    TransferState.offerPending => Icons.inbox,
    TransferState.chunking =>
      transfer.direction == TransferDirection.outbound
          ? Icons.upload
          : Icons.download,
    TransferState.waitingMissing => Icons.sync_problem,
    TransferState.complete => Icons.check_circle,
    TransferState.failed => Icons.error_outline,
    TransferState.cancelled => Icons.cancel_outlined,
  };

  Color _stateColor(BuildContext context) => switch (transfer.state) {
    TransferState.created ||
    TransferState.offerSent ||
    TransferState.awaitingAccept ||
    TransferState.cancelled => context.textTertiary,
    TransferState.offerPending ||
    TransferState.waitingMissing => SemanticColors.warning,
    TransferState.chunking => context.accentColor,
    TransferState.complete => SemanticColors.success,
    TransferState.failed => SemanticColors.error,
  };

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024.0).toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final isOutbound = transfer.direction == TransferDirection.outbound;
    final row = Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing6),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing10,
      ),
      decoration: BoxDecoration(
        color: context.cardAlt,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: context.border.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                FileTypeIcon(mimeType: transfer.mimeType, size: 32),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isOutbound
                          ? AppTheme.primaryBlue
                          : AppTheme.primaryPurple,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.background,
                        width: AppTheme.spacing2,
                      ),
                    ),
                    child: Icon(
                      isOutbound ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 7,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transfer.filename,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatSize(transfer.totalBytes),
                  style: TextStyle(color: context.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(_stateIcon, size: 14, color: _stateColor(context)),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            relativeTime,
            style: TextStyle(color: context.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return BouncyTap(onTap: onTap!, child: row);
  }
}
