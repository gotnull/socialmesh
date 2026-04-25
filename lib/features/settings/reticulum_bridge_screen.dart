// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/bottom_action_bar.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/reticulum_bridge_provider.dart';
import '../../providers/reticulum_providers.dart';
import '../../services/reticulum/reticulum_bridge_service.dart';

class ReticulumBridgeScreen extends ConsumerStatefulWidget {
  const ReticulumBridgeScreen({super.key});

  @override
  ConsumerState<ReticulumBridgeScreen> createState() =>
      _ReticulumBridgeScreenState();
}

class _ReticulumBridgeScreenState extends ConsumerState<ReticulumBridgeScreen>
    with LifecycleSafeMixin {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  bool _controllersHydrated = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _hydrateControllers(ReticulumBridgeUiState state) {
    if (_controllersHydrated) return;
    _hostController.text = state.host;
    _portController.text = state.port.toString();
    _controllersHydrated = true;
  }

  Future<void> _toggleEnabled(bool value) async {
    HapticFeedback.selectionClick();
    await ref.read(reticulumFlagsProvider.notifier).setBridgeEnabled(value);
  }

  Future<void> _saveAndConnect() async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(reticulumBridgeProvider.notifier);
    final host = _hostController.text.trim().isEmpty
        ? kReticulumBridgeDefaultHost
        : _hostController.text.trim();
    final port =
        int.tryParse(_portController.text.trim()) ??
        kReticulumBridgeDefaultPort;
    await notifier.setHost(host);
    if (!mounted) return;
    await notifier.setPort(port);
    if (!mounted) return;
    await ref.read(reticulumFlagsProvider.notifier).setBridgeEnabled(true);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(reticulumBridgeProvider);
    final flags = ref.watch(reticulumFlagsProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: context.l10n.reticulumBridgeTitle,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
            sliver: SliverList.list(
              children: [
                const _ExperimentalHeader(),
                if (!flags.reassemblyEnabled) const _ReassemblyRequiredBanner(),
                ...asyncState.when(
                  data: (state) {
                    _hydrateControllers(state);
                    return [
                      _ConnectionSection(
                        state: state,
                        onToggle: _toggleEnabled,
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      _EndpointSection(
                        hostController: _hostController,
                        portController: _portController,
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      _CountersSection(state: state),
                      const SizedBox(height: AppTheme.spacing16),
                      _UptimeSection(state: state),
                      const SizedBox(height: AppTheme.spacing24),
                    ];
                  },
                  loading: () => const <Widget>[
                    Padding(
                      padding: EdgeInsets.all(AppTheme.spacing24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (e, _) => <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      child: Text(
                        e.toString(),
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        bottomNavigationBar: BottomActionBar(
          child: _GradientActionButton(
            label: context.l10n.reticulumBridgeSaveAndConnect,
            icon: Icons.bolt,
            onPressed: _saveAndConnect,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _ExperimentalHeader extends StatelessWidget {
  const _ExperimentalHeader();

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
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warningYellow,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              context.l10n.reticulumBridgeDescription,
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

class _ReassemblyRequiredBanner extends StatelessWidget {
  const _ReassemblyRequiredBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        0,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: AppTheme.warningYellow.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          border: Border.all(
            color: AppTheme.warningYellow.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: AppTheme.warningYellow,
              size: 18,
            ),
            const SizedBox(width: AppTheme.spacing8),
            Expanded(
              child: Text(
                context.l10n.reticulumBridgeRequiresReassembly,
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionSection extends StatelessWidget {
  const _ConnectionSection({required this.state, required this.onToggle});

  final ReticulumBridgeUiState state;
  final ValueChanged<bool> onToggle;

  String _statusLabel(BuildContext context) {
    switch (state.status.kind) {
      case ReticulumBridgeStatusKind.disconnected:
        return context.l10n.reticulumBridgeStatusDisconnected;
      case ReticulumBridgeStatusKind.connecting:
        return context.l10n.reticulumBridgeStatusConnecting;
      case ReticulumBridgeStatusKind.connected:
        return context.l10n.reticulumBridgeStatusConnected;
      case ReticulumBridgeStatusKind.error:
        return context.l10n.reticulumBridgeStatusError;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: context.l10n.reticulumBridgeSectionConnection),
        _SettingsTile(
          icon: Icons.link,
          iconColor: state.enabled ? context.accentColor : null,
          title: context.l10n.reticulumBridgeEnable,
          subtitle: context.l10n.reticulumBridgeEnableSubtitle,
          trailing: ThemedSwitch(value: state.enabled, onChanged: onToggle),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: InfoTable(
            rows: [
              InfoTableRow(
                label: context.l10n.reticulumBridgeStatusLabel,
                value: _statusLabel(context),
                icon: Icons.bolt,
              ),
              InfoTableRow(
                label: context.l10n.reticulumBridgeLastErrorLabel,
                value:
                    state.status.lastError ??
                    context.l10n.reticulumBridgeNoLastError,
                icon: Icons.error_outline,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EndpointSection extends StatelessWidget {
  const _EndpointSection({
    required this.hostController,
    required this.portController,
  });

  final TextEditingController hostController;
  final TextEditingController portController;

  InputDecoration _decoration(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.textSecondary),
      hintText: hint,
      hintStyle: TextStyle(color: SemanticColors.muted),
      filled: true,
      fillColor: context.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        borderSide: BorderSide(color: context.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        borderSide: BorderSide(color: context.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        borderSide: BorderSide(color: context.accentColor),
      ),
      prefixIcon: Icon(icon, color: context.textSecondary),
      counterText: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: context.l10n.reticulumBridgeSectionEndpoint),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Column(
              children: [
                TextField(
                  maxLength: 253,
                  controller: hostController,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: context.textPrimary),
                  decoration: _decoration(
                    context,
                    label: context.l10n.reticulumBridgeHostLabel,
                    hint: context.l10n.reticulumBridgeHostHint,
                    icon: Icons.dns,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                TextField(
                  maxLength: 5,
                  controller: portController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: TextStyle(color: context.textPrimary),
                  decoration: _decoration(
                    context,
                    label: context.l10n.reticulumBridgePortLabel,
                    hint: context.l10n.reticulumBridgePortHint,
                    icon: Icons.numbers,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CountersSection extends StatelessWidget {
  const _CountersSection({required this.state});
  final ReticulumBridgeUiState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: context.l10n.reticulumBridgeSectionCounters),
          InfoTable(
            rows: [
              InfoTableRow(
                label: context.l10n.reticulumBridgeForwarded,
                value: '${state.counters.forwarded}',
                icon: Icons.send_outlined,
              ),
              InfoTableRow(
                label: context.l10n.reticulumBridgeDroppedNoConnection,
                value: '${state.counters.droppedNoConnection}',
                icon: Icons.signal_wifi_off_outlined,
              ),
              InfoTableRow(
                label: context.l10n.reticulumBridgeDroppedBackpressure,
                value: '${state.counters.droppedBackpressure}',
                icon: Icons.dynamic_feed_outlined,
              ),
              InfoTableRow(
                label: context.l10n.reticulumBridgeDroppedFramingError,
                value: '${state.counters.droppedFramingError}',
                icon: Icons.error_outline,
              ),
              InfoTableRow(
                label: context.l10n.reticulumBridgeConnectErrors,
                value: '${state.counters.connectErrors}',
                icon: Icons.cloud_off_outlined,
              ),
              InfoTableRow(
                label: context.l10n.reticulumBridgeQueueDepthLabel,
                value: '${state.queueDepth} / ${state.queueCapacity}',
                icon: Icons.storage_outlined,
              ),
              InfoTableRow(
                label: context.l10n.reticulumBridgeDropPolicyLabel,
                value: context.l10n.reticulumBridgeDropPolicyValue,
                icon: Icons.rule,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UptimeSection extends StatelessWidget {
  const _UptimeSection({required this.state});
  final ReticulumBridgeUiState state;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: context.l10n.reticulumBridgeSectionUptime),
          InfoTable(
            rows: [
              InfoTableRow(
                label: context.l10n.reticulumBridgeCurrentSession,
                value: _fmt(state.currentSessionUptime),
                icon: Icons.timer_outlined,
              ),
              InfoTableRow(
                label: context.l10n.reticulumBridgeTotalUptime,
                value: _fmt(state.totalUptime),
                icon: Icons.history,
              ),
            ],
          ),
        ],
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
