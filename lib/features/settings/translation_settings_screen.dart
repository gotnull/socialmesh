// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/translation_providers.dart';
import '../../services/translation/byo_translation_adapter.dart';
import '../../services/translation/translation_key_repository.dart';
import '../../services/translation/translation_models.dart';
import '../../utils/snackbar.dart';

/// Settings screen for translation provider mode, privacy, BYO key, and cache.
class TranslationSettingsScreen extends ConsumerStatefulWidget {
  const TranslationSettingsScreen({super.key});

  @override
  ConsumerState<TranslationSettingsScreen> createState() =>
      _TranslationSettingsScreenState();
}

class _TranslationSettingsScreenState
    extends ConsumerState<TranslationSettingsScreen>
    with LifecycleSafeMixin {
  String? _maskedKey;
  bool _isLoadingKey = true;
  bool _isTestingKey = false;

  @override
  void initState() {
    super.initState();
    _loadMaskedKey();
  }

  Future<void> _loadMaskedKey() async {
    final repo = TranslationKeyRepository();
    final masked = await repo.maskedKey();
    if (!mounted) return;
    setState(() {
      _maskedKey = masked;
      _isLoadingKey = false;
    });
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(translationSettingsProvider);
    final quota = ref.watch(translationQuotaProvider);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        title: l10n.translationSettingsTitle,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Provider Mode
                _SectionHeader(
                  title: l10n.translationSettingsProviderModeLabel,
                ),
                const SizedBox(height: AppTheme.spacing8),
                _buildProviderModeSelector(context, settings),
                const SizedBox(height: AppTheme.spacing24),

                // BYO Key (visible when BYO mode)
                if (settings.providerMode == TranslationProviderMode.byo) ...[
                  _SectionHeader(title: l10n.translationSettingsByoKeyLabel),
                  const SizedBox(height: AppTheme.spacing8),
                  _buildByoKeySection(context),
                  const SizedBox(height: AppTheme.spacing24),
                ],

                // Privacy Mode
                _SectionHeader(title: l10n.translationSettingsPrivacyModeLabel),
                const SizedBox(height: AppTheme.spacing8),
                _buildPrivacyModeSelector(context, settings),
                const SizedBox(height: AppTheme.spacing24),

                // Quota (visible when managed mode)
                if (settings.providerMode ==
                    TranslationProviderMode.managed) ...[
                  _SectionHeader(title: l10n.translationSettingsQuotaLabel),
                  const SizedBox(height: AppTheme.spacing8),
                  _buildQuotaDisplay(context, quota),
                  const SizedBox(height: AppTheme.spacing24),
                ],

                // Clear cache
                _buildClearCacheButton(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Provider mode selector
  // ---------------------------------------------------------------------------

  Widget _buildProviderModeSelector(
    BuildContext context,
    TranslationSettings settings,
  ) {
    return Column(
      children: [
        _ModeOptionTile(
          icon: Icons.cloud,
          title: context.l10n.translationSettingsProviderManaged,
          subtitle: context.l10n.translationSettingsProviderManagedDesc,
          isSelected: settings.providerMode == TranslationProviderMode.managed,
          onTap: () {
            HapticFeedback.selectionClick();
            ref
                .read(translationSettingsProvider.notifier)
                .setProviderMode(TranslationProviderMode.managed);
          },
        ),
        const SizedBox(height: AppTheme.spacing8),
        _ModeOptionTile(
          icon: Icons.key,
          title: context.l10n.translationSettingsProviderByo,
          subtitle: context.l10n.translationSettingsProviderByoDesc,
          isSelected: settings.providerMode == TranslationProviderMode.byo,
          onTap: () {
            HapticFeedback.selectionClick();
            ref
                .read(translationSettingsProvider.notifier)
                .setProviderMode(TranslationProviderMode.byo);
          },
        ),
        const SizedBox(height: AppTheme.spacing8),
        _ModeOptionTile(
          icon: Icons.block,
          title: context.l10n.translationSettingsProviderDisabled,
          subtitle: context.l10n.translationSettingsProviderDisabledDesc,
          isSelected: settings.providerMode == TranslationProviderMode.disabled,
          onTap: () {
            HapticFeedback.selectionClick();
            ref
                .read(translationSettingsProvider.notifier)
                .setProviderMode(TranslationProviderMode.disabled);
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Privacy mode selector
  // ---------------------------------------------------------------------------

  Widget _buildPrivacyModeSelector(
    BuildContext context,
    TranslationSettings settings,
  ) {
    return Column(
      children: [
        _ModeOptionTile(
          icon: Icons.public,
          title: context.l10n.translationSettingsPrivacyStandard,
          subtitle: context.l10n.translationSettingsPrivacyStandardDesc,
          isSelected: settings.privacyMode == TranslationPrivacyMode.standard,
          onTap: () {
            HapticFeedback.selectionClick();
            ref
                .read(translationSettingsProvider.notifier)
                .setPrivacyMode(TranslationPrivacyMode.standard);
          },
        ),
        const SizedBox(height: AppTheme.spacing8),
        _ModeOptionTile(
          icon: Icons.shield,
          title: context.l10n.translationSettingsPrivacyPrivate,
          subtitle: context.l10n.translationSettingsPrivacyPrivateDesc,
          isSelected: settings.privacyMode == TranslationPrivacyMode.private_,
          onTap: () {
            HapticFeedback.selectionClick();
            ref
                .read(translationSettingsProvider.notifier)
                .setPrivacyMode(TranslationPrivacyMode.private_);
          },
        ),
        const SizedBox(height: AppTheme.spacing8),
        _ModeOptionTile(
          icon: Icons.lock,
          title: context.l10n.translationSettingsPrivacyStrict,
          subtitle: context.l10n.translationSettingsPrivacyStrictDesc,
          isSelected: settings.privacyMode == TranslationPrivacyMode.strict,
          onTap: () {
            HapticFeedback.selectionClick();
            ref
                .read(translationSettingsProvider.notifier)
                .setPrivacyMode(TranslationPrivacyMode.strict);
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BYO key management
  // ---------------------------------------------------------------------------

  Widget _buildByoKeySection(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vpn_key, color: context.textSecondary, size: 20),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text(
                  _isLoadingKey
                      ? '...' // lint-allow: hardcoded-string
                      : _maskedKey ?? l10n.translationSettingsByoKeyNone,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontFamily: _maskedKey != null
                        ? 'monospace' // lint-allow: hardcoded-string
                        : null,
                  ),
                ),
              ),
              if (_maskedKey != null)
                TextButton(
                  onPressed: _removeByoKey,
                  child: Text(
                    l10n.translationSettingsByoKeyRemove,
                    style: TextStyle(color: SemanticColors.error, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showByoKeyEntrySheet,
              icon: Icon(_maskedKey != null ? Icons.edit : Icons.add, size: 18),
              label: Text(
                _maskedKey != null
                    ? l10n.translationSettingsByoKeyStored
                    : l10n.translationSettingsByoKeyHint,
              ),
            ),
          ),
          if (_maskedKey != null) ...[
            const SizedBox(height: AppTheme.spacing8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isTestingKey ? null : _testByoKey,
                icon: _isTestingKey
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering, size: 18),
                label: Text(
                  _isTestingKey
                      ? l10n.translationSettingsByoTestTesting
                      : l10n.translationSettingsByoTestConnection,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showByoKeyEntrySheet() async {
    final l10n = context.l10n;
    final controller = TextEditingController();

    final result = await AppBottomSheet.show<String>(
      context: context,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing24,
      ),
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translationSettingsByoKeyLabel,
              style: TextStyle(
                color: Theme.of(sheetContext).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            TextField(
              controller: controller,
              maxLength: 256,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: l10n.translationSettingsByoKeyHint,
                counterText: '', // lint-allow: hardcoded-string
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) {
                    Navigator.of(sheetContext).pop(value);
                  }
                },
                child: Text(l10n.translationSettingsByoKeySaved),
              ),
            ),
          ],
        ),
      ),
    );

    controller.dispose();

    if (result != null && result.isNotEmpty && mounted) {
      await _saveByoKey(result);
    }
  }

  Future<void> _saveByoKey(String apiKey) async {
    final msg = context.l10n.translationSettingsByoKeySaved;
    final notifier = ref.read(translationByoKeyProvider.notifier);
    final repo = TranslationKeyRepository();
    await repo.storeKey(apiKey);
    notifier.refresh();
    final masked = await repo.maskedKey();
    if (!mounted) return;
    setState(() {
      _maskedKey = masked;
    });
    safeShowSnackBar(msg, type: SnackBarType.success);
  }

  Future<void> _removeByoKey() async {
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.translationSettingsByoKeyRemoveConfirmTitle,
      message: l10n.translationSettingsByoKeyRemoveConfirmMessage,
      confirmLabel: l10n.translationSettingsByoKeyRemove,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    final msg = l10n.translationSettingsByoKeyRemoved;
    final notifier = ref.read(translationByoKeyProvider.notifier);
    HapticFeedback.selectionClick();
    final repo = TranslationKeyRepository();
    await repo.deleteKey();
    notifier.refresh();
    if (!mounted) return;
    setState(() {
      _maskedKey = null;
    });
    safeShowSnackBar(msg, type: SnackBarType.info);
  }

  Future<void> _testByoKey() async {
    final l10n = context.l10n;
    setState(() => _isTestingKey = true);
    HapticFeedback.selectionClick();
    try {
      final repo = TranslationKeyRepository();
      final key = await repo.readKey();
      AppLogging.app(
        'TestByoKey: key read — '
        'null=${key == null} empty=${key?.isEmpty} '
        'len=${key?.length} '
        'prefix=${key != null && key.length > 6 ? key.substring(0, 6) : "?"}...',
      );
      if (key == null || key.isEmpty || !mounted) {
        setState(() => _isTestingKey = false);
        return;
      }
      // Check for whitespace/newline contamination
      final trimmed = key.trim();
      if (trimmed.length != key.length) {
        AppLogging.app(
          'TestByoKey: WARNING — key has leading/trailing whitespace! '
          'raw=${key.length} trimmed=${trimmed.length}',
        );
      }
      final adapter = OpenAiTranslationAdapter(apiKey: trimmed);
      try {
        AppLogging.app('TestByoKey: calling translate("hello" → es)...');
        final result = await adapter
            .translate(
              const TranslationRequest(text: 'hello', targetLanguage: 'es'),
            )
            .timeout(const Duration(seconds: 10));
        AppLogging.app('TestByoKey: success — "${result.translatedText}"');
        if (!mounted) return;
        safeShowSnackBar(
          l10n.translationSettingsByoTestSuccess,
          type: SnackBarType.success,
        );
      } on TranslationError catch (e) {
        AppLogging.app(
          'TestByoKey: TranslationError — type=${e.type} msg=${e.message}',
        );
        if (!mounted) return;
        safeShowSnackBar(e.message, type: SnackBarType.error);
      } on TimeoutException catch (_) {
        AppLogging.app('TestByoKey: timed out after 10s');
        if (!mounted) return;
        safeShowSnackBar(
          l10n.translationSettingsByoTestFailed,
          type: SnackBarType.error,
        );
      } catch (e, stack) {
        AppLogging.app('TestByoKey: unexpected error — $e\n$stack');
        if (!mounted) return;
        safeShowSnackBar(
          l10n.translationSettingsByoTestFailed,
          type: SnackBarType.error,
        );
      } finally {
        adapter.dispose();
      }
    } finally {
      if (mounted) setState(() => _isTestingKey = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Quota display
  // ---------------------------------------------------------------------------

  Widget _buildQuotaDisplay(BuildContext context, TranslationQuotaState quota) {
    final l10n = context.l10n;
    final progress = quota.charLimit > 0
        ? (quota.usedChars / quota.charLimit).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translationSettingsQuotaRemaining(
              quota.usedChars,
              quota.charLimit,
            ),
            style: TextStyle(color: context.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.translationSettingsQuotaResetsAt(_formatDate(quota.resetsAt)),
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spacing12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: context.border,
              valueColor: AlwaysStoppedAnimation(
                quota.isExhausted ? SemanticColors.error : context.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_monthName(date.month)} ${date.year}'; // lint-allow: hardcoded-string
  }

  static String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', // lint-allow: hardcoded-string
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', // lint-allow: hardcoded-string
    ];
    return months[month - 1];
  }

  // ---------------------------------------------------------------------------
  // Clear cache
  // ---------------------------------------------------------------------------

  Widget _buildClearCacheButton(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _clearCache,
        icon: const Icon(Icons.delete_sweep, size: 18),
        label: Text(l10n.translationSettingsClearCache),
      ),
    );
  }

  Future<void> _clearCache() async {
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.translationSettingsClearCache,
      message: l10n.translationSettingsClearCacheConfirm,
      confirmLabel: l10n.translationSettingsClearCacheConfirmAction,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    HapticFeedback.selectionClick();
    try {
      final cache = await ref.read(translationCacheProvider.future);
      await cache.clearAll();
      if (!mounted) return;
      safeShowSnackBar(
        l10n.translationSettingsCacheCleared,
        type: SnackBarType.success,
      );
    } catch (_) {
      // Fail silently — cache clear is best-effort
    }
  }
}

// =============================================================================
// Shared helper widgets
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: context.accentColor,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ModeOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accentColor.withValues(alpha: 0.1)
                : context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(
              color: isSelected ? context.accentColor : context.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? context.accentColor : context.textSecondary,
                size: 22,
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: context.accentColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
