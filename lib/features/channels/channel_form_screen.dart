import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/channel_key_field.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/encoding.dart';
import '../../utils/snackbar.dart';
import '../../utils/validation.dart';

/// Key size options
enum KeySize {
  none(0, 'No Encryption'),
  default1(1, 'Default (Simple)'),
  bit128(16, 'AES-128'),
  bit256(32, 'AES-256');

  final int bytes;
  final String displayName;
  const KeySize(this.bytes, this.displayName);

  static KeySize fromBytes(int bytes) {
    switch (bytes) {
      case 0:
        return KeySize.none;
      case 1:
        return KeySize.default1;
      case 16:
        return KeySize.bit128;
      case 32:
        return KeySize.bit256;
      default:
        // For non-standard sizes, pick closest match
        if (bytes <= 1) return KeySize.default1;
        if (bytes <= 16) return KeySize.bit128;
        return KeySize.bit256;
    }
  }
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
  bool _positionEnabled = false;
  double _positionPrecision = 14; // Default: ~1.5km - slider range is 12-15
  bool _preciseLocation = false; // Uses precision 32 instead of slider
  bool _isSaving = false;
  String? _keyValidationError;
  KeySize? _detectedKeySize;

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
      } else if (channel.psk.length == 1) {
        _selectedKeySize = KeySize.default1;
      } else if (channel.psk.length == 16) {
        _selectedKeySize = KeySize.bit128;
      } else {
        _selectedKeySize = KeySize.bit256;
      }

      if (channel.psk.isNotEmpty) {
        _keyController.text = base64Encode(channel.psk);
        _validateAndDetectKey(_keyController.text);
      }

      _uplinkEnabled = channel.uplink;
      _downlinkEnabled = channel.downlink;
      // Initialize position settings from device
      // positionPrecision: 0 = disabled, 12-15 = approximate, 32 = precise
      final precision = channel.positionPrecision;
      debugPrint(
        '📡 ChannelFormScreen: channel ${channel.index} positionPrecision=$precision',
      );
      _positionEnabled = precision > 0;
      debugPrint('📡 ChannelFormScreen: _positionEnabled=$_positionEnabled');
      if (precision == 32) {
        _preciseLocation = true;
        _positionPrecision = 14; // Default slider position
      } else if (precision >= 12 && precision <= 15) {
        _preciseLocation = false;
        _positionPrecision = precision.toDouble();
      } else if (precision > 0) {
        // Other valid precision values - treat as approximate
        _preciseLocation = false;
        _positionPrecision = precision.clamp(12, 15).toDouble();
      } else {
        _preciseLocation = false;
        _positionPrecision = 14; // Default slider position
      }
      debugPrint(
        '📡 ChannelFormScreen: _preciseLocation=$_preciseLocation, _positionPrecision=$_positionPrecision',
      );
    } else {
      _selectedKeySize = KeySize.bit256;
      // All options disabled by default
      _uplinkEnabled = false;
      _downlinkEnabled = false;
      _positionEnabled = false;
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

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _generateRandomKey() {
    if (_selectedKeySize == KeySize.none) {
      _keyController.text = '';
      _keyValidationError = null;
      _detectedKeySize = null;
      return;
    }

    // For Default (Simple), always use the standard Meshtastic default key AQ==
    // This is base64 for [1] - the single byte with value 1
    // Standard behavior for key generation
    if (_selectedKeySize == KeySize.default1) {
      _keyController.text = 'AQ==';
      _validateAndDetectKey(_keyController.text);
      setState(() {});
      return;
    }

    final random = Random.secure();
    final keyBytes = List<int>.generate(
      _selectedKeySize.bytes,
      (_) => random.nextInt(256),
    );
    _keyController.text = base64Encode(keyBytes);
    _validateAndDetectKey(_keyController.text);
    setState(() {});
  }

  /// Validates a base64 key and detects its size
  void _validateAndDetectKey(String keyText) {
    if (keyText.isEmpty) {
      _keyValidationError = null;
      _detectedKeySize = null;
      return;
    }

    final validatedSize = ChannelKeyUtils.validateKeySize(keyText);
    if (validatedSize == null) {
      // Check if it's a decoding error vs size error
      final decoded = ChannelKeyUtils.base64ToKey(keyText);
      if (decoded == null) {
        _keyValidationError = 'Invalid base64 encoding';
      } else {
        _keyValidationError =
            'Invalid key size (${decoded.length} bytes). Use 1, 16, or 32 bytes.';
      }
      _detectedKeySize = null;
    } else if (validatedSize == 0) {
      _keyValidationError = 'Key cannot be empty';
      _detectedKeySize = null;
    } else {
      _keyValidationError = null;
      _detectedKeySize = KeySize.fromBytes(validatedSize);
    }
  }

  Future<void> _saveChannel() async {
    if (!_formKey.currentState!.validate()) return;

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

    // Validate key if encryption is enabled
    if (_selectedKeySize != KeySize.none) {
      _validateAndDetectKey(_keyController.text);
      if (_keyValidationError != null) {
        showErrorSnackBar(context, 'Invalid key: $_keyValidationError');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      List<int> psk = [];
      if (_selectedKeySize != KeySize.none && _keyController.text.isNotEmpty) {
        psk = base64Decode(_keyController.text.trim());
      }

      final channels = ref.read(channelsProvider);

      // Calculate proper index for new channels
      int index;
      if (widget.channelIndex != null) {
        // Explicitly provided index
        index = widget.channelIndex!;
      } else if (widget.existingChannel != null) {
        // Editing existing channel - keep its index
        index = widget.existingChannel!.index;
      } else {
        // New channel - find first available slot (1-7, slot 0 is primary)
        final usedIndices = channels.map((c) => c.index).toSet();
        index = 1; // Start from 1 (0 is always primary)
        while (usedIndices.contains(index) && index < 8) {
          index++;
        }
        if (index >= 8) {
          throw Exception('Maximum 8 channels allowed');
        }
      }

      // Determine channel role
      String role;
      if (index == 0) {
        role = 'PRIMARY';
      } else if (_selectedKeySize == KeySize.none) {
        role = 'DISABLED';
      } else {
        role = 'SECONDARY';
      }

      // Calculate position precision value
      // 0 = disabled, 12-15 = approximate, 32 = precise
      int positionPrecision = 0;
      if (_positionEnabled) {
        if (_preciseLocation) {
          positionPrecision = 32;
        } else {
          positionPrecision = _positionPrecision.round();
        }
      }

      final newChannel = ChannelConfig(
        index: index,
        name: _nameController.text.trim(),
        psk: psk,
        uplink: _uplinkEnabled,
        downlink: _downlinkEnabled,
        positionPrecision: positionPrecision,
        role: role,
      );

      // Send to device first - this is the source of truth
      final protocol = ref.read(protocolServiceProvider);

      // Verify we have node info (indicates device is ready)
      if (protocol.myNodeNum == null) {
        throw Exception('Device not ready - please wait for connection');
      }

      await protocol.setChannel(newChannel);

      // Small delay to allow device to process
      await Future.delayed(const Duration(milliseconds: 300));

      // Request updated channel info from device to confirm
      await protocol.getChannel(index);

      // Update local state only after successful device sync
      ref.read(channelsProvider.notifier).setChannel(newChannel);

      if (psk.isNotEmpty) {
        final secureStorage = ref.read(secureStorageProvider);
        await secureStorage.storeChannelKey(
          newChannel.name.isEmpty ? 'Channel $index' : newChannel.name,
          psk,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(
          context,
          isEditing ? 'Channel updated' : 'Channel created',
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          leading: IconButton(
            icon: Icon(Icons.close, color: context.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isEditing ? 'Edit Channel' : 'New Channel',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isSaving ? null : _saveChannel,
                child: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: MeshLoadingIndicator(
                          size: 20,
                          colors: [
                            context.accentColor,
                            context.accentColor.withValues(alpha: 0.6),
                            context.accentColor.withValues(alpha: 0.3),
                          ],
                        ),
                      )
                    : Text(
                        'Save',
                        style: TextStyle(
                          color: context.accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
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
              _buildNameField(),

              const SizedBox(height: 28),

              // Encryption Section
              _buildFieldLabel('Encryption'),
              const SizedBox(height: 8),
              _buildEncryptionSelector(),

              if (_selectedKeySize != KeySize.none) ...[
                const SizedBox(height: 20),
                ChannelKeyField(
                  keyBase64: _keyController.text,
                  onKeyChanged: (newKey) {
                    _keyController.text = newKey;
                    _validateAndDetectKey(newKey);
                    if (_detectedKeySize != null) {
                      setState(() {
                        _selectedKeySize = _detectedKeySize!;
                      });
                    }
                  },
                  expectedKeyBytes: _selectedKeySize.bytes,
                ),
              ],

              const SizedBox(height: 28),

              // Position Settings
              _buildFieldLabel('Position'),
              const SizedBox(height: 8),
              _buildPositionOptions(),

              const SizedBox(height: 28),

              // MQTT Settings
              _buildFieldLabel('MQTT'),
              const SizedBox(height: 8),
              _buildMqttOptions(),

              if (isPrimaryChannel) ...[
                const SizedBox(height: 20),
                _buildPrimaryChannelNote(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.textSecondary,

        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildNameField() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with label
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.tag, color: context.accentColor, size: 20),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Channel Name',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Max 11 characters',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _nameController.text.length > 9
                        ? AppTheme.warningYellow.withValues(alpha: 0.15)
                        : context.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_nameController.text.length}/11',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _nameController.text.length > 9
                          ? AppTheme.warningYellow
                          : context.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Input field area
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.border.withValues(alpha: 0.5)),
            ),
            child: TextFormField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              style: TextStyle(
                fontSize: 15,
                color: context.textPrimary,

                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.all(16),
                hintText: 'Enter channel name (no spaces)',
                hintStyle: TextStyle(
                  color: context.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                LengthLimitingTextInputFormatter(maxChannelNameLength),
              ],
              validator: (value) => validateChannelName(value ?? ''),
              textInputAction: TextInputAction.done,
              maxLength: maxChannelNameLength,
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
        ],
      ),
    );
  }

  Widget _buildEncryptionSelector() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
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
                                ? context.accentColor.withValues(alpha: 0.15)
                                : context.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            keySize == KeySize.none ||
                                    keySize == KeySize.default1
                                ? Icons.lock_open
                                : Icons.lock,
                            color: isSelected
                                ? context.accentColor
                                : context.textTertiary,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 14),
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
                                      ? context.textPrimary
                                      : context.textSecondary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                keySize == KeySize.none
                                    ? 'Messages sent in plaintext'
                                    : keySize == KeySize.default1
                                    ? '1-byte simple key (AQ==)'
                                    : '${keySize.bytes * 8}-bit encryption key',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textTertiary,
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
                                  ? context.accentColor
                                  : context.border,
                              width: 2,
                            ),
                            color: isSelected
                                ? context.accentColor
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? Icon(Icons.check, color: Colors.white, size: 14)
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
                  color: context.border.withValues(alpha: 0.5),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPositionOptions() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          _buildToggleRow(
            icon: Icons.location_on_outlined,
            iconColor: context.accentColor,
            title: 'Positions Enabled',
            subtitle: 'Share position on this channel',
            value: _positionEnabled,
            onChanged: (v) {
              setState(() {
                _positionEnabled = v;
                if (v && _positionPrecision == 0) {
                  _positionPrecision =
                      15; // Default to most precise approximate
                }
              });
            },
          ),
          // Position precision controls - shown when position is enabled
          if (_positionEnabled) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: context.border.withValues(alpha: 0.5),
            ),
            _buildPositionPrecisionSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildMqttOptions() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          _buildToggleRow(
            icon: Icons.cloud_upload_outlined,
            iconColor: context.accentColor,
            title: 'Uplink Enabled',
            subtitle: 'Forward messages to MQTT server',
            value: _uplinkEnabled,
            onChanged: (v) => setState(() => _uplinkEnabled = v),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: context.border.withValues(alpha: 0.5),
          ),
          _buildToggleRow(
            icon: Icons.cloud_download_outlined,
            iconColor: context.accentColor,
            title: 'Downlink Enabled',
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
          SizedBox(width: 14),
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
              ],
            ),
          ),
          ThemedSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// Returns the distance description for a position precision value
  String _getPositionPrecisionLabel(int precision) {
    // Based on geohash precision - matches iOS MKDistanceFormatter rounding
    // iOS values: 12 ≈ 5.8km, 13 ≈ 2.9km, 14 ≈ 1.5km, 15 ≈ 700m
    switch (precision) {
      case 12:
        return 'Within 5.8 km';
      case 13:
        return 'Within 2.9 km';
      case 14:
        return 'Within 1.5 km';
      case 15:
        return 'Within 700 m';
      case 32:
        return 'Precise location';
      default:
        return 'Unknown';
    }
  }

  Widget _buildPositionPrecisionSection() {
    final accentColor = context.accentColor;
    final hasSecureKey =
        _selectedKeySize != KeySize.none &&
        _selectedKeySize != KeySize.default1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Precise location toggle - only available with secure key
          if (hasSecureKey) ...[
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _preciseLocation
                        ? accentColor.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.my_location,
                    color: _preciseLocation ? accentColor : Colors.grey,
                    size: 20,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precise Location',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Share exact GPS coordinates',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                ThemedSwitch(
                  value: _preciseLocation,
                  onChanged: (v) {
                    setState(() {
                      _preciseLocation = v;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // Approximate location slider - shown when NOT using precise location
          if (!_preciseLocation) ...[
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.location_searching,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Approximate Location',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: accentColor,
                inactiveTrackColor: accentColor.withValues(alpha: 0.2),
                thumbColor: accentColor,
                overlayColor: accentColor.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: _positionPrecision,
                min: 12,
                max: 15,
                divisions: 3,
                onChanged: (value) {
                  setState(() {
                    _positionPrecision = value;
                  });
                },
              ),
            ),
            Center(
              child: Text(
                _getPositionPrecisionLabel(_positionPrecision.round()),
                style: TextStyle(
                  fontSize: 13,
                  color: accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
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
            child: Icon(
              Icons.info_outline,
              color: AppTheme.warningYellow,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Primary Channel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningYellow,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'This is the main channel for device communication. Changes may affect connectivity.',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
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
