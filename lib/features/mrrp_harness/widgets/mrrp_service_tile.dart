// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/protocol/sip/mrrp_messages_advert.dart';
import '../../../services/protocol/sip/mrrp_types.dart';

/// Tile showing a single MRRP service descriptor with version, flags,
/// and optional raw hex expansion.
class MrrpServiceTile extends StatefulWidget {
  final MrrpAdvertDescriptor descriptor;
  final DateTime? cachedAt;
  final bool isExpired;

  const MrrpServiceTile({
    required this.descriptor,
    this.cachedAt,
    this.isExpired = false,
    super.key,
  });

  @override
  State<MrrpServiceTile> createState() => _MrrpServiceTileState();
}

class _MrrpServiceTileState extends State<MrrpServiceTile> {
  bool _showRawHex = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = widget.descriptor;
    final serviceName = MrrpServiceId.nameOf(d.serviceId);
    final flags = _decodeFlags(d.serviceFlags);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color:
                      (widget.isExpired
                              ? SemanticColors.muted
                              : context.accentColor)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(
                  _serviceIcon(d.serviceId),
                  size: 14,
                  color: widget.isExpired
                      ? SemanticColors.muted
                      : context.accentColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text(
                  serviceName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: widget.isExpired
                        ? SemanticColors.muted
                        : context.textPrimary,
                  ),
                ),
              ),
              Text(
                l10n.mrrpHarnessServiceVersion(d.versionMajor, d.versionMinor),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: context.textTertiary,
                ),
              ),
            ],
          ),
          if (flags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: AppTheme.spacing4),
              child: Wrap(
                spacing: AppTheme.spacing4,
                runSpacing: AppTheme.spacing4,
                children: flags.map((f) => _FlagChip(label: f)).toList(),
              ),
            ),
          if (d.metadata.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: AppTheme.spacing4),
              child: Text(
                String.fromCharCodes(d.metadata),
                style: TextStyle(
                  color: context.textTertiary,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ),
          // Raw hex toggle
          Padding(
            padding: const EdgeInsets.only(left: 36, top: AppTheme.spacing4),
            child: GestureDetector(
              // lint-allow: haptic-feedback — toggle control, not navigation action
              onTap: () => setState(() => _showRawHex = !_showRawHex),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showRawHex
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 14,
                    color: context.accentColor,
                  ),
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    l10n.mrrpHarnessRawHex,
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showRawHex)
            Padding(
              padding: const EdgeInsets.only(
                left: 36,
                top: AppTheme.spacing6,
                bottom: AppTheme.spacing4,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing12,
                  vertical: AppTheme.spacing8,
                ),
                decoration: BoxDecoration(
                  color: context.textPrimary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  border: Border.all(
                    color: context.border.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  _buildRawHex(d),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: context.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _serviceIcon(int serviceId) {
    if (serviceId == MrrpServiceId.meetupV1) return Icons.handshake;
    if (serviceId == MrrpServiceId.profileV1) return Icons.person;
    if (serviceId == MrrpServiceId.boardV1) return Icons.dashboard;
    if (serviceId == MrrpServiceId.echoTest) return Icons.repeat;
    return Icons.extension;
  }

  List<String> _decodeFlags(int flags) {
    final result = <String>[];
    if (flags & MrrpServiceFlags.requiresHandshake != 0) {
      result.add('handshake'); // lint-allow: hardcoded-string
    }
    if (flags & MrrpServiceFlags.requiresIdentity != 0) {
      result.add('identity'); // lint-allow: hardcoded-string
    }
    if (flags & MrrpServiceFlags.supportsRequest != 0) {
      result.add('request'); // lint-allow: hardcoded-string
    }
    if (flags & MrrpServiceFlags.supportsResponse != 0) {
      result.add('response'); // lint-allow: hardcoded-string
    }
    if (flags & MrrpServiceFlags.supportsCachedResponse != 0) {
      result.add('cached'); // lint-allow: hardcoded-string
    }
    if (flags & MrrpServiceFlags.ephemeralOnly != 0) {
      result.add('ephemeral'); // lint-allow: hardcoded-string
    }
    if (flags & MrrpServiceFlags.userVisible != 0) {
      result.add('visible'); // lint-allow: hardcoded-string
    }
    if (flags & MrrpServiceFlags.testOnly != 0) {
      result.add('test'); // lint-allow: hardcoded-string
    }
    return result;
  }

  String _buildRawHex(MrrpAdvertDescriptor d) {
    final hex = StringBuffer();
    hex.write(d.serviceId.toRadixString(16).padLeft(8, '0'));
    hex.write(' '); // lint-allow: hardcoded-string
    hex.write(d.serviceType.code.toRadixString(16).padLeft(2, '0'));
    hex.write(' '); // lint-allow: hardcoded-string
    hex.write(d.versionMajor.toRadixString(16).padLeft(2, '0'));
    hex.write(d.versionMinor.toRadixString(16).padLeft(2, '0'));
    hex.write(' '); // lint-allow: hardcoded-string
    hex.write(d.serviceFlags.toRadixString(16).padLeft(4, '0'));
    return hex.toString().toUpperCase();
  }
}

class _FlagChip extends StatelessWidget {
  final String label;

  const _FlagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final chipColor = _flagColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  static Color _flagColor(String label) {
    return switch (label) {
      'request' => AccentColors.teal, // lint-allow: hardcoded-string
      'response' => AccentColors.indigo, // lint-allow: hardcoded-string
      'handshake' => AccentColors.orange, // lint-allow: hardcoded-string
      'identity' => AccentColors.purple, // lint-allow: hardcoded-string
      'cached' => AccentColors.yellow, // lint-allow: hardcoded-string
      'test' => SemanticColors.muted, // lint-allow: hardcoded-string
      'ephemeral' => AccentColors.pink, // lint-allow: hardcoded-string
      'visible' => SemanticColors.success, // lint-allow: hardcoded-string
      _ => SemanticColors.muted,
    };
  }
}
