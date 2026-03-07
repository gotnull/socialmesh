// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/bottom_action_bar.dart';
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
        bottomNavigationBar: BottomActionBar(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canSend ? _onSend : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: context.border.withValues(alpha: 0.3),
                disabledForegroundColor: context.textTertiary,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacing12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(l10n.mrrpHarnessSend),
            ),
          ),
        ),
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
                _SectionLabel(label: l10n.mrrpHarnessPayloadRawHex),
                const SizedBox(height: AppTheme.spacing8),
                TextField(
                  controller: _payloadController,
                  maxLength: MrrpConstants.mrrpMaxPayload * 2,
                  decoration: InputDecoration(
                    hintText: '0xDEADBEEF', // lint-allow: hardcoded-string
                    hintStyle: TextStyle(
                      color: context.textSecondary.withAlpha(128),
                    ),
                    errorText:
                        payloadBytes == null &&
                            _payloadController.text.isNotEmpty
                        ? 'Invalid hex' // lint-allow: hardcoded-string
                        : null,
                    filled: true,
                    fillColor: context.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      borderSide: BorderSide(
                        color: context.accentColor,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      borderSide: const BorderSide(color: SemanticColors.error),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      borderSide: const BorderSide(
                        color: SemanticColors.error,
                        width: 2,
                      ),
                    ),
                    counterText: '',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: AppTheme.fontFamily,
                    color: context.textPrimary,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppTheme.spacing16),

                // --- TTL selector ---
                _SectionLabel(label: l10n.mrrpHarnessRequestTtl),
                const SizedBox(height: AppTheme.spacing8),
                Wrap(
                  spacing: AppTheme.spacing8,
                  runSpacing: AppTheme.spacing8,
                  children: [5, 10, 15, 30].map((seconds) {
                    final isSelected = seconds == _ttlSeconds;
                    return BouncyTap(
                      onTap: () => setState(() => _ttlSeconds = seconds),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.accentColor.withValues(alpha: 0.15)
                              : context.card,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius20,
                          ),
                          border: Border.all(
                            color: isSelected
                                ? context.accentColor
                                : context.border.withValues(alpha: 0.5),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          '${seconds}s', // lint-allow: hardcoded-string
                          style: TextStyle(
                            color: isSelected
                                ? context.accentColor
                                : context.textSecondary,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: context.border.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              items: items,
              onChanged: onChanged,
              dropdownColor: context.card,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
              ),
              iconEnabledColor: context.textSecondary,
            ),
          ),
        ],
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
    var hex = text.replaceAll(RegExp(r'\s+'), '');
    if (hex.startsWith('0x') || hex.startsWith('0X')) {
      hex = hex.substring(2);
    }
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: context.textTertiary,
        letterSpacing: 1.2,
      ),
    );
  }
}
