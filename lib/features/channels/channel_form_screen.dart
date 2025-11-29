import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';

/// Channel role options matching Meshtastic
enum ChannelRole {
  disabled('Disabled'),
  primary('Primary'),
  secondary('Secondary');

  final String displayName;
  const ChannelRole(this.displayName);
}

/// Key size options
enum KeySize {
  none(0, 'None'),
  bit128(16, '128 bit'),
  bit256(32, '256 bit');

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

  late KeySize _selectedKeySize;
  late ChannelRole _selectedRole;
  bool _allowPositionRequests = false;
  bool _uplinkEnabled = false;
  bool _downlinkEnabled = false;
  bool _isSaving = false;

  bool get isEditing => widget.existingChannel != null;

  @override
  void initState() {
    super.initState();

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

      _selectedRole = channel.index == 0
          ? ChannelRole.primary
          : (channel.name.isEmpty
                ? ChannelRole.disabled
                : ChannelRole.secondary);
      _uplinkEnabled = channel.uplink;
      _downlinkEnabled = channel.downlink;
    } else {
      _selectedKeySize = KeySize.bit256;
      _selectedRole = ChannelRole.secondary;
      _downlinkEnabled = true;
      _generateRandomKey();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
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
        role: _selectedRole == ChannelRole.disabled ? 'DISABLED' : 'SECONDARY',
      );

      // Update provider
      ref.read(channelsProvider.notifier).setChannel(newChannel);

      // Store key securely if present
      if (psk.isNotEmpty) {
        final secureStorage = ref.read(secureStorageProvider);
        await secureStorage.storeChannelKey(
          newChannel.name.isEmpty ? 'Channel $index' : newChannel.name,
          psk,
        );
      }

      // Try to send to device
      try {
        final protocol = ref.read(protocolServiceProvider);
        await protocol.setChannel(newChannel);
      } catch (e) {
        // Device might not be connected, that's okay for local storage
        debugPrint('Could not sync channel to device: $e');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Channel updated' : 'Channel added'),
            backgroundColor: AppTheme.darkCard,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: Text(
          isEditing ? 'Edit Channel' : 'Add Channel',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveChannel,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Channel Details Section
            _buildSectionHeader('Channel Details'),
            _buildCard([
              _buildTextField(
                controller: _nameController,
                label: 'Name',
                hint: 'Channel Name',
              ),
              _buildDivider(),
              _buildDropdownField<KeySize>(
                label: 'Key Size',
                value: _selectedKeySize,
                items: KeySize.values,
                onChanged: (value) {
                  setState(() {
                    _selectedKeySize = value!;
                    if (value == KeySize.none) {
                      _keyController.text = '';
                    } else if (_keyController.text.isEmpty ||
                        _getKeyBytes(_keyController.text) != value.bytes) {
                      _generateRandomKey();
                    }
                  });
                },
                displayBuilder: (item) => item.displayName,
                trailing: IconButton(
                  icon: Icon(Icons.lock, color: AppTheme.graphBlue),
                  onPressed: () {},
                ),
              ),
              if (_selectedKeySize != KeySize.none) ...[
                _buildDivider(),
                _buildKeyField(),
              ],
              _buildDivider(),
              _buildSegmentedField(
                label: 'Channel Role',
                value: _selectedRole,
                options: widget.existingChannel?.index == 0
                    ? [ChannelRole.primary]
                    : [ChannelRole.disabled, ChannelRole.secondary],
                onChanged: (value) => setState(() => _selectedRole = value),
              ),
            ]),

            const SizedBox(height: 24),

            // Position Section
            _buildSectionHeader('Position'),
            _buildCard([
              _buildSwitchField(
                icon: Icons.location_off,
                label: 'Allow Position Requests',
                value: _allowPositionRequests,
                onChanged: (value) =>
                    setState(() => _allowPositionRequests = value),
              ),
            ]),

            const SizedBox(height: 24),

            // MQTT Section
            _buildSectionHeader('MQTT'),
            _buildCard([
              _buildSwitchField(
                icon: Icons.arrow_upward,
                iconColor: AppTheme.graphBlue,
                label: 'Uplink Enabled',
                value: _uplinkEnabled,
                onChanged: (value) => setState(() => _uplinkEnabled = value),
              ),
              _buildDivider(),
              _buildSwitchField(
                icon: Icons.arrow_downward,
                iconColor: AppTheme.graphBlue,
                label: 'Downlink Enabled',
                value: _downlinkEnabled,
                onChanged: (value) => setState(() => _downlinkEnabled = value),
              ),
            ]),

            const SizedBox(height: 32),
          ],
        ),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.darkBorder.withValues(alpha: 0.3),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                fontFamily: 'Inter',
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 80,
            child: Text(
              'Key',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _keyController,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              validator: (value) {
                if (_selectedKeySize == KeySize.none) return null;
                if (value == null || value.isEmpty) {
                  return 'Key is required';
                }
                try {
                  final bytes = base64Decode(value);
                  if (bytes.length != _selectedKeySize.bytes) {
                    return 'Key must be ${_selectedKeySize.bytes} bytes';
                  }
                } catch (e) {
                  return 'Invalid Base64';
                }
                return null;
              },
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: AppTheme.textTertiary,
              size: 20,
            ),
            onPressed: _generateRandomKey,
            tooltip: 'Generate random key',
          ),
          IconButton(
            icon: const Icon(
              Icons.copy,
              color: AppTheme.textTertiary,
              size: 20,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _keyController.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Key copied to clipboard')),
              );
            },
            tooltip: 'Copy key',
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    required String Function(T) displayBuilder,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                items: items.map((item) {
                  return DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      displayBuilder(item),
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
                dropdownColor: AppTheme.darkCard,
                icon: const Icon(
                  Icons.unfold_more,
                  color: AppTheme.textTertiary,
                  size: 20,
                ),
                isDense: true,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildSegmentedField<T>({
    required String label,
    required T value,
    required List<T> options,
    required void Function(T) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: options.map((option) {
                  final isSelected = option == value;
                  final displayName = option is ChannelRole
                      ? option.displayName
                      : option.toString();
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.darkCard
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          displayName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchField({
    required IconData icon,
    Color? iconColor,
    required String label,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? AppTheme.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AppTheme.primaryGreen,
            inactiveTrackColor: AppTheme.darkBorder,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
