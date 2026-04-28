// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/bottom_action_bar.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/rns_companion_providers.dart';
import '../../services/rns_companion/rns_companion_client.dart';
import '../../utils/snackbar.dart';

class RnsCompanionSettingsScreen extends ConsumerStatefulWidget {
  const RnsCompanionSettingsScreen({super.key});

  @override
  ConsumerState<RnsCompanionSettingsScreen> createState() =>
      _RnsCompanionSettingsScreenState();
}

class _RnsCompanionSettingsScreenState
    extends ConsumerState<RnsCompanionSettingsScreen>
    with LifecycleSafeMixin {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  bool _hydrated = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _hydrate(RnsCompanionEndpoint ep) {
    if (_hydrated) return;
    _hostController.text = ep.host;
    _portController.text = ep.port.toString();
    _hydrated = true;
  }

  Future<void> _save() async {
    HapticFeedback.selectionClick();
    final host = _hostController.text.trim().isEmpty
        ? kRnsCompanionDefaultHost
        : _hostController.text.trim();
    final port =
        int.tryParse(_portController.text.trim()) ?? kRnsCompanionDefaultPort;
    await ref
        .read(rnsCompanionEndpointProvider.notifier)
        .setEndpoint(host, port);
    if (!mounted) return;
    showInfoSnackBar(context, context.l10n.rnsCompanionSettingsSavedSnack);
  }

  @override
  Widget build(BuildContext context) {
    final ep = ref.watch(rnsCompanionEndpointProvider);
    _hydrate(ep);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: context.l10n.rnsCompanionSettingsTitle,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
            sliver: SliverList.list(
              children: [
                const _SectionHeader(),
                _Hint(text: context.l10n.rnsCompanionSettingsHint),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                  ),
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
                          controller: _hostController,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: context.textPrimary),
                          decoration: _decoration(
                            context,
                            label: context.l10n.rnsCompanionSettingsHostLabel,
                            hint: context.l10n.rnsCompanionSettingsHostHint,
                            icon: Icons.dns,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        TextField(
                          maxLength: 5,
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          style: TextStyle(color: context.textPrimary),
                          decoration: _decoration(
                            context,
                            label: context.l10n.rnsCompanionSettingsPortLabel,
                            hint: context.l10n.rnsCompanionSettingsPortHint,
                            icon: Icons.numbers,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing24),
              ],
            ),
          ),
        ],
        bottomNavigationBar: BottomActionBar(
          child: _GradientActionButton(
            label: context.l10n.rnsCompanionSettingsSave,
            icon: Icons.save_outlined,
            onPressed: _save,
          ),
        ),
      ),
    );
  }

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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

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
        context.l10n.rnsCompanionSettingsSectionEndpoint,
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

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        0,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: context.textTertiary,
          height: 1.4,
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
