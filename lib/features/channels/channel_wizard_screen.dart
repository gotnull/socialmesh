// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/channel_key_field.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../utils/encoding.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/channel.pb.dart' as channel_pb;
import '../../generated/meshtastic/channel.pbenum.dart' as channel_pbenum;

/// Step-specific help content for the channel wizard
class _WizardStepHelp {
  final String title;
  final String content;
  final IconData icon;
  final Color color;

  const _WizardStepHelp({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });

  static const List<_WizardStepHelp> steps = [
    _WizardStepHelp(
      title: 'Channel Name',
      icon: Icons.edit,
      color: AppTheme.primaryBlue,
      content:
          'Choose a memorable name for your channel.\n\n'
          '• Names are limited to 12 characters\n'
          '• Only letters and numbers allowed\n'
          '• The name is visible to anyone who joins\n'
          '• Pick something descriptive like "Family" or "Hiking"',
    ),
    _WizardStepHelp(
      title: 'Privacy Level',
      icon: Icons.security,
      color: AppTheme.primaryPurple,
      content:
          'Select how secure your channel should be.\n\n'
          '• OPEN: No encryption - anyone can read messages\n'
          '• SHARED: Uses the default Meshtastic key - not private\n'
          '• PRIVATE (Recommended): Unique AES-128 key - secure\n'
          '• MAXIMUM: AES-256 encryption - highest security\n\n'
          'Higher security requires sharing your channel key with others.',
    ),
    _WizardStepHelp(
      title: 'Advanced Options',
      icon: Icons.tune,
      color: AppTheme.primaryBlue,
      content:
          'Configure optional channel settings.\n\n'
          '• Position Sharing: Allow location sharing on this channel\n'
          '• MQTT Uplink: Send messages to the internet (requires MQTT setup)\n'
          '• MQTT Downlink: Receive messages from the internet\n'
          '• Encryption Key: Auto-generated, but you can paste a custom key\n\n'
          'Most users can skip these advanced options.',
    ),
    _WizardStepHelp(
      title: 'Review & Create',
      icon: Icons.check_circle,
      color: AppTheme.successGreen,
      content:
          'Review your channel settings before creating.\n\n'
          '• Verify the name and privacy level are correct\n'
          '• After creation, share the QR code with others\n'
          '• Others scan the QR code to join your channel\n'
          '• You can also copy the URL to share via text',
    ),
  ];
}

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
  bool _positionEnabled = false;

  // Key management
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

  void _showStepHelp() {
    final stepHelp = _WizardStepHelp.steps[_currentStep];
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: stepHelp.color.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(stepHelp.icon, color: stepHelp.color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      stepHelp.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                stepHelp.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveChannel() async {
    if (_isSaving) return;

    // Check connection state before saving
    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, 'Cannot save channel: Device not connected');
      return;
    }

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
        positionPrecision: _positionEnabled ? 32 : 0,
      );

      await protocol.setChannel(channel);

      // Update local state
      ref.read(channelsProvider.notifier).setChannel(channel);

      setState(() {
        _saveComplete = true;
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to create channel: $e');
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _generateChannelUrl() {
    final channelSettings = channel_pb.ChannelSettings()
      ..name = _nameController.text.trim();

    final key = _generatedKey;
    if (key.isNotEmpty) {
      channelSettings.psk = key;
    }

    final channel = channel_pb.Channel()
      ..index = widget.channelIndex
      ..settings = channelSettings
      ..role = channel_pbenum.Channel_Role.SECONDARY;

    final bytes = channel.writeToBuffer();
    final encoded = base64
        .encode(bytes)
        .replaceAll('+', '-')
        .replaceAll('/', '_');
    return 'socialmesh://channel/$encoded';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stepHelp = _WizardStepHelp.steps[_currentStep];

    return GlassScaffold.body(
      title: 'Create Channel',
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(stepHelp.icon, color: stepHelp.color),
          onPressed: _showStepHelp,
          tooltip: 'Help',
        ),
      ],
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
                        ? context.accentColor
                        : context.surface,
                    border: isActive && !isComplete
                        ? Border.all(color: context.accentColor, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: isComplete
                        ? Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : context.textSecondary,
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
                          : context.surface,
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
          Icon(Icons.edit, size: 48, color: context.accentColor),
          SizedBox(height: 24),
          Text('Name Your Channel', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Choose a name that helps you identify this channel. It will be visible to anyone who joins.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          SizedBox(height: 32),
          TextField(
            controller: _nameController,
            style: TextStyle(color: context.textPrimary),
            maxLength: 12,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            ],
            decoration: InputDecoration(
              labelText: 'Channel Name',
              labelStyle: TextStyle(color: context.textSecondary),
              hintText: 'e.g., Family, Friends, Hiking',
              hintStyle: TextStyle(color: context.textSecondary.withAlpha(128)),
              filled: true,
              fillColor: context.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.accentColor, width: 2),
              ),
              counterStyle: TextStyle(color: context.textSecondary),
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
          Icon(Icons.security, size: 48, color: AppTheme.primaryPurple),
          const SizedBox(height: 24),
          Text('Choose Privacy Level', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Select how secure you want this channel to be. Higher security uses stronger encryption.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Column(
            children: PrivacyLevel.values
                .map((level) => _buildPrivacyOption(level, theme))
                .toList(),
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
          color: isSelected ? level.color.withAlpha(26) : context.surface,
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
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: context.textPrimary,
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
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? level.color : context.textTertiary,
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
          Icon(Icons.tune, size: 48, color: AppTheme.primaryBlue),
          const SizedBox(height: 24),
          Text('Advanced Options', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Configure optional channel settings.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          // Encryption key section (only for private/maximum)
          if (_privacyLevel == PrivacyLevel.private ||
              _privacyLevel == PrivacyLevel.maximum) ...[
            const SizedBox(height: 12),
            ChannelKeyField(
              keyBase64: ChannelKeyUtils.keyToBase64(_generatedKey),
              onKeyChanged: (newKey) {
                final decoded = ChannelKeyUtils.base64ToKey(newKey);
                if (decoded != null) {
                  setState(() {
                    _generatedKey = decoded;
                  });
                }
              },
              expectedKeyBytes: _privacyLevel.keySize.bytes,
              accentColor: _privacyLevel.color,
            ),
            const SizedBox(height: 24),
          ],
          // Position setting (doesn't require MQTT)
          _buildToggleOption(
            theme: theme,
            title: 'Position Enabled',
            subtitle: 'Share your position on this channel.',
            value: _positionEnabled,
            onChanged: (value) {
              setState(() {
                _positionEnabled = value;
              });
            },
          ),
          SizedBox(height: 24),
          // MQTT section header
          Row(
            children: [
              Icon(Icons.cloud_outlined, size: 16, color: context.textTertiary),
              SizedBox(width: 8),
              Text(
                'MQTT Settings',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: context.textTertiary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          if (_uplinkEnabled || _downlinkEnabled) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningYellow.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warningYellow.withAlpha(77)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.warningYellow,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'MQTT must be configured on your device for uplink/downlink to work.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.warningYellow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        color: context.surface,
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
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          ThemedSwitch(value: value, onChanged: onChanged),
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
            LoadingIndicator(size: 64),
            SizedBox(height: 24),
            Text(
              'Creating channel...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
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
            Icon(Icons.check_circle, size: 64, color: AppTheme.successGreen),
            const SizedBox(height: 24),
            Text('Channel Created!', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Share this QR code with others to let them join.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
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
                color: context.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(theme, 'Name', _nameController.text),
                  Divider(color: context.border.withAlpha(128)),
                  _buildSummaryRow(theme, 'Privacy', _privacyLevel.title),
                  Divider(color: context.border.withAlpha(128)),
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
                      showSuccessSnackBar(
                        context,
                        'Channel URL copied to clipboard',
                      );
                    },
                    icon: Icon(Icons.copy),
                    label: Text('Copy URL'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.accentColor,
                      side: BorderSide(color: context.accentColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check),
                    label: Text('Done'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accentColor,
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
          Icon(Icons.preview, size: 48, color: AppTheme.successGreen),
          const SizedBox(height: 24),
          Text('Review & Create', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Review your channel settings before creating.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSummaryRow(theme, 'Name', _nameController.text),
                Divider(color: context.border.withAlpha(128)),
                _buildSummaryRow(theme, 'Privacy Level', _privacyLevel.title),
                Divider(color: context.border.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  'Encryption',
                  _privacyLevel.keySize.displayName,
                ),
                Divider(color: context.border.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  'Key Size',
                  _privacyLevel.keySize.bytes == 0
                      ? 'No key'
                      : _privacyLevel.keySize.bytes == 1
                      ? 'Default key'
                      : '${_privacyLevel.keySize.bytes * 8} bits',
                ),
                if (_privacyLevel.keySize.bytes > 1) ...[
                  Divider(color: context.border.withAlpha(128)),
                  _buildKeyRow(theme),
                ],
                Divider(color: context.border.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  'MQTT Uplink',
                  _uplinkEnabled ? 'Enabled' : 'Disabled',
                ),
                Divider(color: context.border.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  'MQTT Downlink',
                  _downlinkEnabled ? 'Enabled' : 'Disabled',
                ),
                Divider(color: context.border.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  'Position Sharing',
                  _positionEnabled ? 'Enabled' : 'Disabled',
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
              color: context.textSecondary,
            ),
          ),
          Text(
            value.isEmpty ? '-' : value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyRow(ThemeData theme) {
    final keyBase64 = ChannelKeyUtils.keyToBase64(_generatedKey);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            'Encryption Key',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              keyBase64.isNotEmpty
                  ? '${keyBase64.substring(0, keyBase64.length.clamp(0, 8))}...'
                  : '-',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
              ),
              overflow: TextOverflow.ellipsis,
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
        color: context.surface,
        border: Border(top: BorderSide(color: context.border.withAlpha(128))),
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
                    side: BorderSide(color: context.border),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 0) SizedBox(width: 16),
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
                  backgroundColor: context.accentColor,
                  disabledBackgroundColor: context.accentColor.withAlpha(77),
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
