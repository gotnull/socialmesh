// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/config/remote_flag_overrides_service.dart';

/// Admin diagnostic surface for the remote env-flag overlay.
///
/// Lists every allowlisted env key (AppFeatureFlags `*_ENABLED` +
/// AppLogging `*_LOGGING_ENABLED`), its original `.env` boot value,
/// any remote override currently in effect, and a switch to set or
/// clear the remote override via Firestore.
///
/// Visible from the AdminScreen "Remote flags" tile.
class RemoteFlagsAdminSheet extends StatefulWidget {
  const RemoteFlagsAdminSheet({super.key});

  @override
  State<RemoteFlagsAdminSheet> createState() => _RemoteFlagsAdminSheetState();
}

class _RemoteFlagsAdminSheetState extends State<RemoteFlagsAdminSheet> {
  final RemoteFlagOverridesService _service =
      RemoteFlagOverridesService.instance;
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _filterController.addListener(() {
      setState(() {
        _filter = _filterController.text.trim().toUpperCase();
      });
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  List<String> get _visibleKeys {
    final all = RemoteFlagOverridesService.allowedKeys.toList()..sort();
    if (_filter.isEmpty) return all;
    return all.where((k) => k.contains(_filter)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: 'Remote flags', // lint-allow: hardcoded-string
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload from Firestore', // lint-allow: hardcoded-string
            onPressed: () {
              HapticFeedback.selectionClick();
              // The service is always live-listening; this just nudges
              // the UI to recheck the listener's last snapshot.
              setState(() {});
            },
          ),
        ],
        slivers: [
          SliverToBoxAdapter(child: _buildSearch(context)),
          SliverToBoxAdapter(child: _buildSummary(context)),
          ValueListenableBuilder<int>(
            valueListenable: _service.revision,
            builder: (context, _, _) {
              final rows = _buildGroupedRows();
              if (rows.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing24),
                    child: Center(
                      child: Text(
                        'No keys match filter', // lint-allow: hardcoded-string
                        style: TextStyle(
                          color: context.textTertiary,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return SliverList(delegate: SliverChildListDelegate(rows));
            },
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height:
                  MediaQuery.of(context).padding.bottom + AppTheme.spacing16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: TextField(
        controller: _filterController,
        maxLength: 64,
        decoration: InputDecoration(
          hintText: 'Filter keys', // lint-allow: hardcoded-string
          prefixIcon: Icon(Icons.search, color: context.textSecondary),
          counterText: '',
          filled: true,
          fillColor: context.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
        ),
        style: TextStyle(fontFamily: AppTheme.fontFamily),
      ),
    );
  }

  /// Group keys by the first underscore-separated token so related
  /// flags sit together. Behavior flags sort before logging/debug
  /// flags inside a group; otherwise alphabetical.
  List<Widget> _buildGroupedRows() {
    final keys = _visibleKeys;
    if (keys.isEmpty) return const [];

    final grouped = <String, List<String>>{};
    for (final key in keys) {
      final group = key.split('_').first;
      grouped.putIfAbsent(group, () => <String>[]).add(key);
    }

    final groupNames = grouped.keys.toList()..sort();

    int sortRank(String k) {
      final isDebugOrLogging = k.endsWith('_DEBUG') || k.contains('_LOGGING');
      return isDebugOrLogging ? 1 : 0;
    }

    final widgets = <Widget>[];
    for (final group in groupNames) {
      final entries = grouped[group]!
        ..sort((a, b) {
          final rankA = sortRank(a);
          final rankB = sortRank(b);
          if (rankA != rankB) return rankA - rankB;
          return a.compareTo(b);
        });
      widgets.add(_GroupHeader(label: group, count: entries.length));
      for (final key in entries) {
        widgets.add(_FlagRow(envKey: key, service: _service));
      }
    }
    return widgets;
  }

  Widget _buildSummary(BuildContext context) {
    final overrides = _service.currentOverrides;
    return ValueListenableBuilder<int>(
      valueListenable: _service.revision,
      builder: (context, _, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing4,
          ),
          child: Text(
            '${RemoteFlagOverridesService.allowedKeys.length} keys, '
            '${overrides.length} overridden', // lint-allow: hardcoded-string
            style: TextStyle(
              fontSize: 12,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing20,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: 10,
              color: context.textTertiary.withValues(alpha: 0.6),
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagRow extends StatelessWidget {
  const _FlagRow({required this.envKey, required this.service});

  final String envKey;
  final RemoteFlagOverridesService service;

  @override
  Widget build(BuildContext context) {
    final originalValue = service.originalEnvValueFor(envKey);
    final override = service.getRemoteOverride(envKey);
    final effectiveBool = service.effectiveBoolFor(envKey);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing2,
      ),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      envKey,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      _subtitle(originalValue, override, effectiveBool),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              ThemedSwitch(
                value: effectiveBool,
                onChanged: (value) async {
                  HapticFeedback.selectionClick();
                  await service.setRemoteFlag(envKey, value);
                },
              ),
              const SizedBox(width: AppTheme.spacing4),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.restart_alt,
                  size: 18,
                  color: override == null
                      ? context.textTertiary.withValues(alpha: 0.4)
                      : AccentColors.orange,
                ),
                tooltip: 'Clear override', // lint-allow: hardcoded-string
                onPressed: override == null
                    ? null
                    : () async {
                        HapticFeedback.selectionClick();
                        await service.removeRemoteFlag(envKey);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(String? original, bool? override, bool effective) {
    final originalLabel = original == null || original.isEmpty
        ? 'unset' // lint-allow: hardcoded-string
        : original;
    final overrideLabel = override == null
        ? 'none' // lint-allow: hardcoded-string
        : override.toString();
    return 'env: $originalLabel   override: $overrideLabel   effective: $effective'; // lint-allow: hardcoded-string
  }
}
