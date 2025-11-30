import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../../generated/meshtastic/mesh.pbenum.dart' as pbenum;

/// Key size options with security explanations
enum WizardKeySize {
  none(0, 'None', 'No encryption - messages are sent in plain text'),
  default1(1, 'Default', 'Simple shared key - compatible but not secure'),
  bit128(16, 'AES-128', 'Strong encryption - recommended for most uses'),
  bit256(32, 'AES-256', 'Maximum encryption - highest security');

  final int bytes;
  final String displayName;
  final String description;

  const WizardKeySize(this.bytes, this.displayName, this.description);
}

/// Privacy level with detailed explanations
enum PrivacyLevel { open, shared, private, maximum }

extension PrivacyLevelExt on PrivacyLevel {
  String get title {
    switch (this) {
      case PrivacyLevel.open:
        return 'Open Channel';
      case PrivacyLevel.shared:
        return 'Shared Channel';
      case PrivacyLevel.private:
        return 'Private Channel';
      case PrivacyLevel.maximum:
        return 'Maximum Security';
    }
  }

  String get description {
    switch (this) {
      case PrivacyLevel.open:
        return 'No encryption. Anyone with a compatible radio can read your messages. Use only for public broadcasts.';
      case PrivacyLevel.shared:
        return 'Uses the well-known default key. Other Meshtastic users may be able to read messages. Good for community channels.';
      case PrivacyLevel.private:
        return 'AES-128 encryption with a random key. Only people you share the QR code with can join. Recommended for most uses.';
      case PrivacyLevel.maximum:
        return 'AES-256 encryption for maximum security. Ideal for sensitive communications. Slightly higher battery usage.';
    }
  }

  IconData get icon {
    switch (this) {
      case PrivacyLevel.open:
        return Icons.public;
      case PrivacyLevel.shared:
        return Icons.people;
      case PrivacyLevel.private:
        return Icons.lock;
      case PrivacyLevel.maximum:
        return Icons.shield;
    }
  }

  Color get color {
    switch (this) {
      case PrivacyLevel.open:
        return AppTheme.warningYellow;
      case PrivacyLevel.shared:
        return AppTheme.primaryBlue;
      case PrivacyLevel.private:
        return AppTheme.successGreen;
      case PrivacyLevel.maximum:
        return AppTheme.primaryPurple;
    }
  }

  WizardKeySize get keySize {
    switch (this) {
      case PrivacyLevel.open:
        return WizardKeySize.none;
      case PrivacyLevel.shared:
        return WizardKeySize.default1;
      case PrivacyLevel.private:
        return WizardKeySize.bit128;
      case PrivacyLevel.maximum:
        return WizardKeySize.bit256;
    }
  }
}

class ChannelWizardScreen extends ConsumerStatefulWidget {
  final int channelIndex;

  const ChannelWizardScreen({super.key, required this.channelIndex});

  @override
  ConsumerState<ChannelWizardScreen> createState() =>
      _ChannelWizardScreenState();
}

class _ChannelWizardScreenState extends ConsumerState<ChannelWizardScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Step 1: Name
  final _nameController = TextEditingController();

  // Step 2: Privacy level
  PrivacyLevel _privacyLevel = PrivacyLevel.private;

  // Step 3: Advanced options (optional)
  bool _uplinkEnabled = false;
  bool _downlinkEnabled = false;

  // Generated key
  List<int> _generatedKey = [];

  // Saving state
  bool _isSaving = false;
  bool _saveComplete = false;

  @override
  void initState() {
    super.initState();
    _generateKey();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _generateKey() {
    final keySize = _privacyLevel.keySize;
    if (keySize.bytes == 0) {
      _generatedKey = [];
    } else if (keySize.bytes == 1) {
      _generatedKey = [1]; // Default key marker
    } else {
      final random = Random.secure();
      _generatedKey = List.generate(keySize.bytes, (_) => random.nextInt(256));
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      // Regenerate key when privacy level changes
      if (_currentStep == 1) {
        _generateKey();
      }
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveChannel() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final protocol = ref.read(protocolServiceProvider);

      final channel = ChannelConfig(
        index: widget.channelIndex,
        name: _nameController.text.trim(),
        psk: _generatedKey,
        role: 'SECONDARY',
        uplink: _uplinkEnabled,
        downlink: _downlinkEnabled,
      );

      await protocol.setChannel(channel);

      // Update local state
      ref.read(channelsProvider.notifier).setChannel(channel);

      setState(() {
        _saveComplete = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create channel: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _generateChannelUrl() {
    final channelSettings = pb.ChannelSettings()
      ..name = _nameController.text.trim();

    if (_generatedKey.isNotEmpty) {
      channelSettings.psk = _generatedKey;
    }

    final channel = pb.Channel()
      ..index = widget.channelIndex
      ..settings = channelSettings
      ..role = pbenum.Channel_Role.SECONDARY;

    final bytes = channel.writeToBuffer();
    final encoded = base64
        .encode(bytes)
        .replaceAll('+', '-')
        .replaceAll('/', '_');
    return 'https://meshtastic.org/e/#$encoded';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Create Channel'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildNameStep(theme),
                  _buildPrivacyStep(theme),
                  _buildOptionsStep(theme),
                  _buildCompleteStep(theme),
                ],
              ),
            ),
            // Navigation buttons
            if (!_saveComplete) _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          final isComplete = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isComplete
                        ? AppTheme.successGreen
                        : isActive
                        ? AppTheme.primaryMagenta
                        : AppTheme.darkSurface,
                    border: isActive && !isComplete
                        ? Border.all(color: AppTheme.primaryMagenta, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: isComplete
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                if (index < _totalSteps - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isComplete
                          ? AppTheme.successGreen
                          : AppTheme.darkSurface,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNameStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit, size: 48, color: AppTheme.primaryMagenta),
          const SizedBox(height: 24),
          Text('Name Your Channel', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Choose a name that helps you identify this channel. It will be visible to anyone who joins.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            maxLength: 12,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            ],
            decoration: InputDecoration(
              labelText: 'Channel Name',
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: 'e.g., Family, Hiking',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withAlpha(128),
              ),
              filled: true,
              fillColor: AppTheme.darkSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primaryMagenta,
                  width: 2,
                ),
              ),
              counterStyle: const TextStyle(color: AppTheme.textSecondary),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryBlue.withAlpha(77)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Channel names are limited to 12 alphanumeric characters.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.security, size: 48, color: AppTheme.primaryPurple),
          const SizedBox(height: 24),
          Text('Choose Privacy Level', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Select how secure you want this channel to be. Higher security uses stronger encryption.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ...PrivacyLevel.values.map(
            (level) => _buildPrivacyOption(level, theme),
          ),
          const SizedBox(height: 24),
          _buildCompatibilityInfo(theme),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption(PrivacyLevel level, ThemeData theme) {
    final isSelected = _privacyLevel == level;
    return GestureDetector(
      onTap: () {
        setState(() {
          _privacyLevel = level;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? level.color.withAlpha(26) : AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? level.color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: level.color.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(level.icon, color: level.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: level.color.withAlpha(51),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          level.keySize.displayName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: level.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? level.color : AppTheme.textTertiary,
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 12 : 0,
                  height: isSelected ? 12 : 0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? level.color : Colors.transparent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompatibilityInfo(ThemeData theme) {
    String compatibilityText;
    IconData compatibilityIcon;
    Color compatibilityColor;

    switch (_privacyLevel) {
      case PrivacyLevel.open:
        compatibilityText =
            'Compatible with all devices. No key exchange needed.';
        compatibilityIcon = Icons.check_circle;
        compatibilityColor = AppTheme.successGreen;
        break;
      case PrivacyLevel.shared:
        compatibilityText =
            'Uses the default Meshtastic key. Other users with default settings may intercept messages.';
        compatibilityIcon = Icons.warning;
        compatibilityColor = AppTheme.warningYellow;
        break;
      case PrivacyLevel.private:
        compatibilityText =
            'Recommended. Share the QR code securely with people you want to communicate with.';
        compatibilityIcon = Icons.recommend;
        compatibilityColor = AppTheme.successGreen;
        break;
      case PrivacyLevel.maximum:
        compatibilityText =
            'Highest security. Ensure all participants support AES-256 encryption.';
        compatibilityIcon = Icons.verified_user;
        compatibilityColor = AppTheme.primaryPurple;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: compatibilityColor.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: compatibilityColor.withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(compatibilityIcon, color: compatibilityColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              compatibilityText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: compatibilityColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tune, size: 48, color: AppTheme.primaryBlue),
          const SizedBox(height: 24),
          Text('Advanced Options', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Configure optional MQTT settings for internet connectivity.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          _buildToggleOption(
            theme: theme,
            title: 'Uplink Enabled',
            subtitle:
                'Send messages from this channel to MQTT when connected to the internet.',
            value: _uplinkEnabled,
            onChanged: (value) {
              setState(() {
                _uplinkEnabled = value;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildToggleOption(
            theme: theme,
            title: 'Downlink Enabled',
            subtitle:
                'Receive messages from MQTT and broadcast them on this channel.',
            value: _downlinkEnabled,
            onChanged: (value) {
              setState(() {
                _downlinkEnabled = value;
              });
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These settings require MQTT to be configured on your device.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.primaryMagenta,
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteStep(ThemeData theme) {
    if (_isSaving && !_saveComplete) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primaryMagenta,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Creating channel...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_saveComplete) {
      final channelUrl = _generateChannelUrl();

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 64,
              color: AppTheme.successGreen,
            ),
            const SizedBox(height: 24),
            Text('Channel Created!', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Share this QR code with others to let them join.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: channelUrl,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(theme, 'Name', _nameController.text),
                  Divider(color: AppTheme.darkBorder.withAlpha(128)),
                  _buildSummaryRow(theme, 'Privacy', _privacyLevel.title),
                  Divider(color: AppTheme.darkBorder.withAlpha(128)),
                  _buildSummaryRow(
                    theme,
                    'Encryption',
                    _privacyLevel.keySize.displayName,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: channelUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Channel URL copied to clipboard'),
                          backgroundColor: AppTheme.successGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy URL'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryMagenta,
                      side: const BorderSide(color: AppTheme.primaryMagenta),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryMagenta,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Preview step before saving
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.preview, size: 48, color: AppTheme.successGreen),
          const SizedBox(height: 24),
          Text('Review & Create', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Review your channel settings before creating.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSummaryRow(theme, 'Name', _nameController.text),
                Divider(color: AppTheme.darkBorder.withAlpha(128)),
                _buildSummaryRow(theme, 'Privacy Level', _privacyLevel.title),
                Divider(color: AppTheme.darkBorder.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  'Encryption',
                  _privacyLevel.keySize.displayName,
                ),
                Divider(color: AppTheme.darkBorder.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  'Key Size',
                  _privacyLevel.keySize.bytes == 0
                      ? 'No key'
                      : _privacyLevel.keySize.bytes == 1
                      ? 'Default key'
                      : '${_privacyLevel.keySize.bytes * 8} bits',
                ),
                Divider(color: AppTheme.darkBorder.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  'MQTT Uplink',
                  _uplinkEnabled ? 'Enabled' : 'Disabled',
                ),
                Divider(color: AppTheme.darkBorder.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  'MQTT Downlink',
                  _downlinkEnabled ? 'Enabled' : 'Disabled',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _privacyLevel.color.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _privacyLevel.color.withAlpha(77)),
            ),
            child: Row(
              children: [
                Icon(_privacyLevel.icon, color: _privacyLevel.color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _privacyLevel.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _privacyLevel.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value.isEmpty ? '-' : value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final canProceed = _currentStep == 0
        ? _nameController.text.trim().isNotEmpty
        : true;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
          top: BorderSide(color: AppTheme.darkBorder.withAlpha(128)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.darkBorder),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: canProceed
                    ? () {
                        FocusScope.of(context).unfocus();
                        if (_currentStep == _totalSteps - 1) {
                          _saveChannel();
                        } else {
                          _nextStep();
                        }
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryMagenta,
                  disabledBackgroundColor: AppTheme.primaryMagenta.withAlpha(
                    77,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _currentStep == _totalSteps - 1
                      ? 'Create Channel'
                      : 'Continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
