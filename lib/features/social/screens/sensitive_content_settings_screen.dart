import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/utils/snackbar.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../providers/social_providers.dart';
import '../../../services/content_moderation_service.dart';

/// Settings screen for sensitive content controls.
/// Allows users to control how sensitive content is displayed.
class SensitiveContentSettingsScreen extends ConsumerStatefulWidget {
  const SensitiveContentSettingsScreen({super.key});

  @override
  ConsumerState<SensitiveContentSettingsScreen> createState() =>
      _SensitiveContentSettingsScreenState();
}

class _SensitiveContentSettingsScreenState
    extends ConsumerState<SensitiveContentSettingsScreen> {
  SensitiveContentSettings? _settings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final service = ref.read(contentModerationServiceProvider);
    final settings = await service.getSensitiveContentSettings();
    if (mounted) {
      setState(() => _settings = settings);
    }
  }

  Future<void> _saveSettings(SensitiveContentSettings settings) async {
    setState(() => _isSaving = true);
    try {
      await updateSensitiveContentSettings(ref, settings);
      setState(() => _settings = settings);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Sensitive Content')),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // Header explanation
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Control how much sensitive content you see in Explore and recommendations. '
                    'This doesn\'t affect content from accounts you follow.',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondary,
                    ),
                  ),
                ),

                // Filter level selection
                _buildSection(
                  title: 'Sensitive Content Control',
                  children: [
                    _FilterLevelTile(
                      title: 'Less',
                      subtitle: 'See more sensitive content in Explore',
                      value: SensitiveContentFilterLevel.less,
                      groupValue: settings.filterLevel,
                      onChanged: _isSaving
                          ? null
                          : (level) => _saveSettings(
                              settings.copyWith(filterLevel: level),
                            ),
                    ),
                    _FilterLevelTile(
                      title: 'Standard',
                      subtitle: 'Default setting for sensitive content',
                      value: SensitiveContentFilterLevel.standard,
                      groupValue: settings.filterLevel,
                      onChanged: _isSaving
                          ? null
                          : (level) => _saveSettings(
                              settings.copyWith(filterLevel: level),
                            ),
                      isDefault: true,
                    ),
                    _FilterLevelTile(
                      title: 'Less',
                      subtitle: 'See less sensitive content in Explore',
                      value: SensitiveContentFilterLevel.strict,
                      groupValue: settings.filterLevel,
                      onChanged: _isSaving
                          ? null
                          : (level) => _saveSettings(
                              settings.copyWith(filterLevel: level),
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Additional settings
                _buildSection(
                  title: 'Display Options',
                  children: [
                    SwitchListTile(
                      title: const Text('Blur Sensitive Media'),
                      subtitle: const Text(
                        'Blur potentially sensitive images and videos until tapped',
                      ),
                      value: settings.blurSensitiveMedia,
                      onChanged: _isSaving
                          ? null
                          : (value) => _saveSettings(
                              settings.copyWith(blurSensitiveMedia: value),
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Info section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: context.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'About Sensitive Content',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sensitive content may include posts that depict violence, '
                          'nudity, or other content that some people may find offensive. '
                          'This doesn\'t include content that violates our Community Guidelines, '
                          'which is always removed.',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _FilterLevelTile extends StatelessWidget {
  const _FilterLevelTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.isDefault = false,
  });

  final String title;
  final String subtitle;
  final SensitiveContentFilterLevel value;
  final SensitiveContentFilterLevel groupValue;
  final ValueChanged<SensitiveContentFilterLevel>? onChanged;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return InkWell(
      onTap: onChanged != null ? () => onChanged!(value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: context.textPrimary,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: context.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 22,
              color: isSelected ? context.primary : context.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog shown when user has unacknowledged strikes/warnings.
class StrikeWarningDialog extends ConsumerStatefulWidget {
  const StrikeWarningDialog({super.key, required this.strikes});

  final List<UserStrike> strikes;

  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    final strikes = await ref.read(unacknowledgedStrikesProvider.future);
    if (strikes.isEmpty || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StrikeWarningDialog(strikes: strikes),
    );
  }

  @override
  ConsumerState<StrikeWarningDialog> createState() =>
      _StrikeWarningDialogState();
}

class _StrikeWarningDialogState extends ConsumerState<StrikeWarningDialog> {
  bool _isAcknowledging = false;
  int _currentIndex = 0;

  UserStrike get _currentStrike => widget.strikes[_currentIndex];

  Future<void> _acknowledgeAndNext() async {
    setState(() => _isAcknowledging = true);
    try {
      await acknowledgeStrike(ref, _currentStrike.id);

      if (_currentIndex < widget.strikes.length - 1) {
        setState(() {
          _currentIndex++;
          _isAcknowledging = false;
        });
      } else {
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAcknowledging = false);
        showErrorSnackBar(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strike = _currentStrike;
    final isWarning = strike.type == 'warning';
    final isSuspension = strike.type == 'suspension';

    return AlertDialog(
      icon: Icon(
        isSuspension
            ? Icons.block
            : isWarning
            ? Icons.warning_amber_rounded
            : Icons.error_outline,
        size: 48,
        color: isSuspension
            ? Colors.red
            : isWarning
            ? Colors.orange
            : Colors.red.shade700,
      ),
      title: Text(
        isSuspension
            ? 'Account Suspended'
            : isWarning
            ? 'Community Guidelines Warning'
            : 'Strike Against Your Account',
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strike.reason,
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            if (strike.expiresAt != null) ...[
              _InfoRow(label: 'Expires', value: _formatDate(strike.expiresAt!)),
            ],
            _InfoRow(label: 'Date', value: _formatDate(strike.createdAt)),
            if (strike.contentType != null) ...[
              _InfoRow(label: 'Content Type', value: strike.contentType!),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isSuspension
                    ? 'Your account is temporarily suspended. You cannot post, '
                          'comment, or create stories during this time.'
                    : 'Repeated violations may result in account suspension or '
                          'permanent ban. Please review our Community Guidelines.',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
            ),
            if (widget.strikes.length > 1) ...[
              const SizedBox(height: 12),
              Text(
                '${_currentIndex + 1} of ${widget.strikes.length} notices',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _isAcknowledging ? null : _acknowledgeAndNext,
          child: _isAcknowledging
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _currentIndex < widget.strikes.length - 1
                      ? 'Next'
                      : 'I Understand',
                ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: context.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for content that has been blocked/removed
class ContentBlockedSheet extends StatelessWidget {
  const ContentBlockedSheet({
    super.key,
    required this.reason,
    this.appealable = false,
    this.onAppeal,
  });

  final String reason;
  final bool appealable;
  final VoidCallback? onAppeal;

  static Future<void> show(
    BuildContext context, {
    required String reason,
    bool appealable = false,
    VoidCallback? onAppeal,
  }) {
    return AppBottomSheet.show(
      context: context,
      child: ContentBlockedSheet(
        reason: reason,
        appealable: appealable,
        onAppeal: onAppeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.block, size: 40, color: Colors.red),
          ),
          const SizedBox(height: 16),
          Text(
            'Content Removed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          const SizedBox(height: 24),
          if (appealable && onAppeal != null) ...[
            OutlinedButton(
              onPressed: onAppeal,
              child: const Text('Appeal Decision'),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner widget to show at top of screen when user has active strikes
class ModerationStatusBanner extends ConsumerWidget {
  const ModerationStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(moderationStatusProvider);

    return statusAsync.maybeWhen(
      data: (status) {
        if (status == null || status.isInGoodStanding) {
          return const SizedBox.shrink();
        }

        Color bannerColor;
        IconData icon;

        if (status.isPermanentlyBanned) {
          bannerColor = Colors.red;
          icon = Icons.block;
        } else if (status.isSuspended) {
          bannerColor = Colors.red.shade700;
          icon = Icons.pause_circle_outline;
        } else if (status.activeStrikes > 0) {
          bannerColor = Colors.orange.shade700;
          icon = Icons.warning_amber_rounded;
        } else {
          bannerColor = Colors.amber.shade700;
          icon = Icons.info_outline;
        }

        return Material(
          color: bannerColor,
          child: SafeArea(
            bottom: false,
            child: InkWell(
              onTap: () => _showStatusDetails(context, ref, status),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        status.statusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _showStatusDetails(
    BuildContext context,
    WidgetRef ref,
    ModerationStatus status,
  ) {
    AppBottomSheet.show(
      context: context,
      child: _ModerationStatusDetails(status: status),
    );
  }
}

class _ModerationStatusDetails extends StatelessWidget {
  const _ModerationStatusDetails({required this.status});

  final ModerationStatus status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Status',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _StatusRow(
            label: 'Active Strikes',
            value: '${status.activeStrikes}',
            isWarning: status.activeStrikes > 0,
          ),
          _StatusRow(
            label: 'Active Warnings',
            value: '${status.activeWarnings}',
            isWarning: status.activeWarnings > 0,
          ),
          _StatusRow(
            label: 'Account Status',
            value: status.isPermanentlyBanned
                ? 'Permanently Banned'
                : status.isSuspended
                ? 'Suspended'
                : 'Active',
            isWarning: status.isSuspended || status.isPermanentlyBanned,
          ),
          if (status.isSuspended && status.suspendedUntil != null) ...[
            _StatusRow(
              label: 'Suspension Ends',
              value:
                  '${status.suspendedUntil!.day}/${status.suspendedUntil!.month}/${status.suspendedUntil!.year}',
            ),
          ],
          const SizedBox(height: 16),
          if (!status.isPermanentlyBanned) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: context.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Strikes expire after 90 days of no violations.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isWarning ? Colors.red : context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
