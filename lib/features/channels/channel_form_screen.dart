import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';

/// Key size options
enum KeySize {
  none(0, 'No Encryption'),
  bit128(16, 'AES-128'),
  bit256(32, 'AES-256');

  final int bytes;
  final String displayName;
  const KeySize(this.bytes, this.displayName);
}

class ChannelFormScreen extends ConsumerStatefulWidget {
  final ChannelConfig? existingChannel;
  final int? channelIndex;

  const ChannelFormScreen({super.key, this.existingChannel, this.channelIndex});

  @override
  ConsumerState<ChannelFormScreen> createState() => _ChannelFormScreenState();
}

class _ChannelFormScreenState extends ConsumerState<ChannelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  final _nameFocusNode = FocusNode();

  late KeySize _selectedKeySize;
  bool _uplinkEnabled = false;
  bool _downlinkEnabled = false;
  bool _isSaving = false;
  bool _showKey = false;

  bool get isEditing => widget.existingChannel != null;
  bool get isPrimaryChannel => widget.existingChannel?.index == 0;

  @override
  void initState() {
    super.initState();

    // Listen for name changes to update counter
    _nameController.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.existingChannel != null) {
      final channel = widget.existingChannel!;
      _nameController.text = channel.name;

      if (channel.psk.isEmpty) {
        _selectedKeySize = KeySize.none;
      } else if (channel.psk.length == 16) {
        _selectedKeySize = KeySize.bit128;
      } else {
        _selectedKeySize = KeySize.bit256;
      }

      if (channel.psk.isNotEmpty) {
        _keyController.text = base64Encode(channel.psk);
      }

      _uplinkEnabled = channel.uplink;
      _downlinkEnabled = channel.downlink;
    } else {
      _selectedKeySize = KeySize.bit256;
      _downlinkEnabled = true;
      _generateRandomKey();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _generateRandomKey() {
    if (_selectedKeySize == KeySize.none) {
      _keyController.text = '';
      return;
    }

    final random = Random.secure();
    final keyBytes = List<int>.generate(
      _selectedKeySize.bytes,
      (_) => random.nextInt(256),
    );
    _keyController.text = base64Encode(keyBytes);
    setState(() {});
  }

  Future<void> _saveChannel() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      List<int> psk = [];
      if (_selectedKeySize != KeySize.none && _keyController.text.isNotEmpty) {
        psk = base64Decode(_keyController.text.trim());
      }

      final channels = ref.read(channelsProvider);
      final index =
          widget.channelIndex ??
          widget.existingChannel?.index ??
          channels.length;

      final newChannel = ChannelConfig(
        index: index,
        name: _nameController.text.trim(),
        psk: psk,
        uplink: _uplinkEnabled,
        downlink: _downlinkEnabled,
        role: _selectedKeySize == KeySize.none ? 'DISABLED' : 'SECONDARY',
      );

      ref.read(channelsProvider.notifier).setChannel(newChannel);

      if (psk.isNotEmpty) {
        final secureStorage = ref.read(secureStorageProvider);
        await secureStorage.storeChannelKey(
          newChannel.name.isEmpty ? 'Channel \$index' : newChannel.name,
          psk,
        );
      }

      try {
        final protocol = ref.read(protocolServiceProvider);
        await protocol.setChannel(newChannel);
      } catch (e) {
        debugPrint('Could not sync channel to device: \$e');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Channel updated' : 'Channel created'),
            backgroundColor: AppTheme.darkCard,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: \$e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Channel' : 'New Channel',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _saveChannel,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        fontFamily: 'Inter',
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Channel Name Field
            _buildFieldLabel('Channel Name'),
            const SizedBox(height: 8),
            _buildNameField(),

            const SizedBox(height: 28),

            // Encryption Section
            _buildFieldLabel('Encryption'),
            const SizedBox(height: 8),
            _buildEncryptionSelector(),

            if (_selectedKeySize != KeySize.none) ...[
              const SizedBox(height: 20),
              _buildKeyField(),
            ],

            const SizedBox(height: 28),

            // MQTT Options
            _buildFieldLabel('MQTT Settings'),
            const SizedBox(height: 8),
            _buildMqttOptions(),

            if (isPrimaryChannel) ...[
              const SizedBox(height: 20),
              _buildPrimaryChannelNote(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        fontFamily: 'Inter',
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildNameField() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.tag,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name required';
                }
                if (value.length > 11) {
                  return 'Max 11 characters';
                }
                return null;
              },
              textInputAction: TextInputAction.done,
              maxLength: 11,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) {
                    return null; // Hide default counter
                  },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _nameController.text.length > 9
                  ? AppTheme.warningYellow.withValues(alpha: 0.15)
                  : AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_nameController.text.length}/11',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _nameController.text.length > 9
                    ? AppTheme.warningYellow
                    : AppTheme.textTertiary,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncryptionSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: KeySize.values.asMap().entries.map((entry) {
          final index = entry.key;
          final keySize = entry.value;
          final isSelected = _selectedKeySize == keySize;
          final isLast = index == KeySize.values.length - 1;

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedKeySize = keySize;
                      if (keySize == KeySize.none) {
                        _keyController.text = '';
                      } else if (_keyController.text.isEmpty ||
                          _getKeyBytes(_keyController.text) != keySize.bytes) {
                        _generateRandomKey();
                      }
                    });
                  },
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(12) : Radius.zero,
                    bottom: isLast ? const Radius.circular(12) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                                : AppTheme.darkBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            keySize == KeySize.none
                                ? Icons.lock_open
                                : Icons.lock,
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : AppTheme.textTertiary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                keySize.displayName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                keySize == KeySize.none
                                    ? 'Messages sent in plaintext'
                                    : '${keySize.bytes * 8}-bit encryption key',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.darkBorder,
                              width: 2,
                            ),
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: AppTheme.darkBorder.withValues(alpha: 0.5),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKeyField() {
    final keyLength = _selectedKeySize.bytes;
    final keyBits = keyLength * 8;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with label and actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.key,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Encryption Key',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$keyBits-bit · Base64 encoded',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Key display area
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.darkBorder.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key value
                _showKey
                    ? SelectableText(
                        _keyController.text,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.primaryGreen,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          height: 1.5,
                        ),
                      )
                    : Text(
                        '•' * 32,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textTertiary.withValues(alpha: 0.5),
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                      ),
              ],
            ),
          ),

          // Action buttons row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Row(
              children: [
                // Show/Hide toggle
                _buildKeyActionButton(
                  icon: _showKey ? Icons.visibility_off : Icons.visibility,
                  label: _showKey ? 'Hide' : 'Show',
                  onPressed: () => setState(() => _showKey = !_showKey),
                  isEnabled: true,
                ),
                const SizedBox(width: 4),
                // Regenerate - only when visible
                _buildKeyActionButton(
                  icon: Icons.refresh,
                  label: 'Regenerate',
                  onPressed: _showKey
                      ? () {
                          _generateRandomKey();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('New key generated'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppTheme.darkCard,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      : null,
                  isEnabled: _showKey,
                ),
                const SizedBox(width: 4),
                // Copy - only when visible
                _buildKeyActionButton(
                  icon: Icons.copy,
                  label: 'Copy',
                  onPressed: _showKey
                      ? () {
                          Clipboard.setData(
                            ClipboardData(text: _keyController.text),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Key copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppTheme.darkCard,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      : null,
                  isEnabled: _showKey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isEnabled,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isEnabled
                      ? AppTheme.textSecondary
                      : AppTheme.textTertiary.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isEnabled
                        ? AppTheme.textSecondary
                        : AppTheme.textTertiary.withValues(alpha: 0.4),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMqttOptions() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          _buildToggleRow(
            icon: Icons.cloud_upload_outlined,
            iconColor: AppTheme.graphBlue,
            title: 'Uplink',
            subtitle: 'Forward messages to MQTT server',
            value: _uplinkEnabled,
            onChanged: (v) => setState(() => _uplinkEnabled = v),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: AppTheme.darkBorder.withValues(alpha: 0.5),
          ),
          _buildToggleRow(
            icon: Icons.cloud_download_outlined,
            iconColor: AppTheme.graphBlue,
            title: 'Downlink',
            subtitle: 'Receive messages from MQTT server',
            value: _downlinkEnabled,
            onChanged: (v) => setState(() => _downlinkEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryGreen,
            activeTrackColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
            inactiveThumbColor: AppTheme.textTertiary,
            inactiveTrackColor: AppTheme.darkBackground,
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryChannelNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningYellow.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.warningYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline,
              color: AppTheme.warningYellow,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Primary Channel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningYellow,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'This is the main channel for device communication. Changes may affect connectivity.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getKeyBytes(String base64Key) {
    try {
      return base64Decode(base64Key).length;
    } catch (e) {
      return 0;
    }
  }
}
