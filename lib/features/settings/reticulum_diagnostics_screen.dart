// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_empty_state.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/reticulum_providers.dart';
import '../../services/protocol/reticulum/reticulum_capture_writer.dart';
import '../../services/protocol/reticulum/reticulum_flags.dart';
import '../../services/protocol/reticulum/reticulum_reassembler.dart';
import '../../services/protocol/reticulum/reticulum_stats.dart';
import '../../utils/snackbar.dart';
import 'reticulum_capture_library_screen.dart';
import 'reticulum_replay_screen.dart';

class ReticulumDiagnosticsScreen extends ConsumerStatefulWidget {
  const ReticulumDiagnosticsScreen({super.key});

  @override
  ConsumerState<ReticulumDiagnosticsScreen> createState() =>
      _ReticulumDiagnosticsScreenState();
}

class _ReticulumDiagnosticsScreenState
    extends ConsumerState<ReticulumDiagnosticsScreen>
    with LifecycleSafeMixin {
  Future<void> _toggleCapture(bool value) async {
    HapticFeedback.selectionClick();
    await ref.read(reticulumFlagsProvider.notifier).setCaptureEnabled(value);
  }

  Future<void> _toggleReassembly(bool value) async {
    HapticFeedback.selectionClick();
    await ref.read(reticulumFlagsProvider.notifier).setReassemblyEnabled(value);
  }

  Future<void> _shareCaptures() async {
    HapticFeedback.selectionClick();
    final writer = ref.read(reticulumCaptureWriterProvider);
    final files = await writer.listCaptureFiles();
    if (!mounted) return;
    if (files.isEmpty) {
      showInfoSnackBar(context, context.l10n.reticulumDiagShareNoFiles);
      return;
    }
    await Share.shareXFiles(
      files.map((f) => XFile(f.path)).toList(growable: false),
    );
  }

  void _openReplay() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ReticulumReplayScreen()),
    );
  }

  void _openLibrary() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ReticulumCaptureLibraryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(reticulumFlagsProvider);
    final stats = ref.watch(reticulumStatsProvider);
    final reasmStats = ref.watch(reticulumReassemblerStatsProvider);
    final writer = ref.watch(reticulumCaptureWriterProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: context.l10n.reticulumDiagTitle,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
            sliver: SliverList.list(
              children: [
                _ExperimentalHeader(),
                if (stats.totalFragments == 0)
                  _EmptyState()
                else
                  _OverviewSection(stats: stats),
                const SizedBox(height: AppTheme.spacing16),
                _ReassemblySection(
                  enabled: flags.reassemblyEnabled,
                  stats: reasmStats,
                  onToggle: _toggleReassembly,
                ),
                const SizedBox(height: AppTheme.spacing16),
                _CaptureSection(
                  flags: flags,
                  writer: writer,
                  onToggle: _toggleCapture,
                  onShare: _shareCaptures,
                ),
                const SizedBox(height: AppTheme.spacing16),
                _ReplaySection(onOpen: _openReplay),
                const SizedBox(height: AppTheme.spacing16),
                _LibrarySection(onOpen: _openLibrary),
                const SizedBox(height: AppTheme.spacing24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _ExperimentalHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing8,
                vertical: AppTheme.spacing4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.warningYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                border: Border.all(
                  color: AppTheme.warningYellow.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                context.l10n.reticulumDiagExperimental,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warningYellow,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              context.l10n.reticulumDiagDescription,
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing24),
      child: AnimatedEmptyState(
        config: AnimatedEmptyStateConfig(
          icons: const [
            Icons.podcasts,
            Icons.lan_outlined,
            Icons.hub_outlined,
            Icons.router_outlined,
            Icons.settings_input_antenna,
          ],
          taglines: [
            context.l10n.reticulumDiagEmptyTagline1,
            context.l10n.reticulumDiagEmptyTagline2,
            context.l10n.reticulumDiagEmptyTagline3,
          ],
          titlePrefix: context.l10n.reticulumDiagEmptyTitlePrefix,
          titleKeyword: context.l10n.reticulumDiagEmptyTitleKeyword,
          titleSuffix: context.l10n.reticulumDiagEmptyTitleSuffix,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.stats});
  final ReticulumStats stats;

  String _formatLastSeen(BuildContext context) {
    final ms = stats.lastSeenMs;
    if (ms == null) return context.l10n.reticulumDiagNeverSeen;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return dt.toIso8601String();
  }

  String _formatRate(double v) => v.toStringAsFixed(2);

  String _formatBytes(double v) =>
      '${v.toStringAsFixed(0)} B'; // lint-allow: hardcoded-string

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: context.l10n.reticulumDiagSectionOverview),
          InfoTable(
            rows: [
              InfoTableRow(
                label: context.l10n.reticulumDiagFragmentCount,
                value: '${stats.totalFragments}',
                icon: Icons.podcasts,
              ),
              InfoTableRow(
                label: context.l10n.reticulumDiagLastSeen,
                value: _formatLastSeen(context),
                icon: Icons.schedule_outlined,
              ),
              InfoTableRow(
                label: context.l10n.reticulumDiagDistinctSources,
                value: '${stats.distinctSourceCount}',
                icon: Icons.account_tree_outlined,
              ),
              InfoTableRow(
                label: context.l10n.reticulumDiagAvgFragmentSize,
                value: _formatBytes(stats.avgFragmentSize),
                icon: Icons.straighten_outlined,
              ),
              InfoTableRow(
                label: context.l10n.reticulumDiagFragmentsPerSecond,
                value: _formatRate(stats.fragmentsPerSecond),
                icon: Icons.speed_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _ReassemblySection extends StatelessWidget {
  const _ReassemblySection({
    required this.enabled,
    required this.stats,
    required this.onToggle,
  });
  final bool enabled;
  final ReticulumReassemblerStats stats;
  final ValueChanged<bool> onToggle;

  String _fmtRate(double v) => v.toStringAsFixed(2);

  String _fmtPercent(double v01) => '${(v01 * 100).toStringAsFixed(1)}%';

  String _fmtAvg(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: context.l10n.reticulumDiagSectionReassembly),
        _SettingsTile(
          icon: Icons.merge_outlined,
          iconColor: enabled ? context.accentColor : null,
          title: context.l10n.reticulumDiagReassemblyEnable,
          subtitle: context.l10n.reticulumDiagReassemblyEnableSubtitle,
          trailing: ThemedSwitch(value: enabled, onChanged: onToggle),
        ),
        if (!enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing8,
              AppTheme.spacing16,
              AppTheme.spacing8,
            ),
            child: Text(
              context.l10n.reticulumDiagReassemblyDisabledHint,
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary,
                height: 1.4,
              ),
            ),
          ),
        if (enabled) ...[
          const SizedBox(height: AppTheme.spacing8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            child: InfoTable(
              rows: [
                InfoTableRow(
                  label: context.l10n.reticulumDiagFramesReassembled,
                  value: '${stats.framesEmitted}',
                  icon: Icons.merge_outlined,
                ),
                InfoTableRow(
                  label: context.l10n.reticulumDiagFramesPerSecond,
                  value: _fmtRate(stats.framesPerSecond),
                  icon: Icons.speed_outlined,
                ),
                InfoTableRow(
                  label: context.l10n.reticulumDiagAvgFragmentsPerFrame,
                  value: _fmtAvg(stats.avgFragmentsPerFrame),
                  icon: Icons.linear_scale,
                ),
                InfoTableRow(
                  label: context.l10n.reticulumDiagSuccessRate,
                  value: _fmtPercent(stats.successRate),
                  icon: Icons.check_circle_outline,
                ),
                InfoTableRow(
                  label: context.l10n.reticulumDiagDroppedDecodeError,
                  value: '${stats.droppedDecodeError}',
                  icon: Icons.error_outline,
                ),
                InfoTableRow(
                  label: context.l10n.reticulumDiagDroppedTimeoutInactivity,
                  value: '${stats.droppedTimeoutInactivity}',
                  icon: Icons.hourglass_disabled_outlined,
                ),
                InfoTableRow(
                  label: context.l10n.reticulumDiagDroppedTimeoutAbsolute,
                  value: '${stats.droppedTimeoutAbsolute}',
                  icon: Icons.timer_off_outlined,
                ),
                InfoTableRow(
                  label: context.l10n.reticulumDiagDroppedOverflow,
                  value: '${stats.droppedOverflow}',
                  icon: Icons.dynamic_feed_outlined,
                ),
                InfoTableRow(
                  label: context.l10n.reticulumDiagDroppedOversize,
                  value: '${stats.droppedOversize}',
                  icon: Icons.straighten_outlined,
                ),
                InfoTableRow(
                  label: context.l10n.reticulumDiagDuplicateFragments,
                  value: '${stats.duplicateFragments}',
                  icon: Icons.content_copy_outlined,
                ),
                InfoTableRow(
                  label: context.l10n.reticulumDiagActiveBuffers,
                  value: '${stats.activeBuffers}',
                  icon: Icons.storage_outlined,
                ),
                InfoTableRow(
                  label: context.l10n.reticulumDiagBufferedBytes,
                  value: '${stats.bufferedBytes}',
                  icon: Icons.data_array,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------

class _CaptureSection extends StatelessWidget {
  const _CaptureSection({
    required this.flags,
    required this.writer,
    required this.onToggle,
    required this.onShare,
  });

  final ReticulumFlags flags;
  final ReticulumCaptureWriter writer;
  final ValueChanged<bool> onToggle;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final activeFile = writer.currentFile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: context.l10n.reticulumDiagSectionCapture),
        _SettingsTile(
          icon: Icons.fiber_manual_record_outlined,
          iconColor: flags.captureEnabled ? context.accentColor : null,
          title: context.l10n.reticulumDiagCaptureEnable,
          subtitle: context.l10n.reticulumDiagCaptureEnableSubtitle,
          trailing: ThemedSwitch(
            value: flags.captureEnabled,
            onChanged: onToggle,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: InfoTable(
            rows: [
              InfoTableRow(
                label: context.l10n.reticulumDiagCaptureCurrentFile,
                value: activeFile == null
                    ? context.l10n.reticulumDiagCaptureNoActiveFile
                    : _basename(activeFile),
                icon: Icons.description_outlined,
              ),
              InfoTableRow(
                label: context.l10n.reticulumDiagCaptureBytes,
                value: '${writer.bytesInCurrentFile}',
                icon: Icons.data_array,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: _GradientActionButton(
            label: context.l10n.reticulumDiagShareCaptures,
            icon: Icons.ios_share,
            onPressed: onShare,
          ),
        ),
      ],
    );
  }

  String _basename(File f) {
    final segs = f.path.split(Platform.pathSeparator);
    return segs.isEmpty ? f.path : segs.last;
  }
}

// -----------------------------------------------------------------------------

class _ReplaySection extends StatelessWidget {
  const _ReplaySection({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: context.l10n.reticulumDiagSectionReplay),
        InkWell(
          onTap: onOpen,
          child: _SettingsTile(
            icon: Icons.play_circle_outline,
            title: context.l10n.reticulumDiagOpenReplay,
            subtitle: context.l10n.reticulumDiagOpenReplaySubtitle,
            trailing: Icon(Icons.chevron_right, color: context.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: _SettingsTile(
        icon: Icons.library_books_outlined,
        title: context.l10n.reticulumDiagOpenLibrary,
        subtitle: context.l10n.reticulumDiagOpenLibrarySubtitle,
        trailing: Icon(Icons.chevron_right, color: context.textTertiary),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? context.textSecondary),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    subtitle,
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacing12,
            horizontal: AppTheme.spacing16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.accentColor,
                context.accentColor.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
