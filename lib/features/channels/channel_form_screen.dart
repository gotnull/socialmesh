// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — GestureDetector is for keyboard dismissal, not user interaction
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/channel_key_field.dart';
import '../../core/widgets/status_banner.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/encoding.dart';
import '../../utils/snackbar.dart';
import '../../utils/validation.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/loading_indicator.dart';

/// Key size options
enum KeySize {
  none(0),
  default1(1),
  bit128(16),
  bit256(32);

  final int bytes;
  const KeySize(this.bytes);

  String displayName(AppLocalizations l10n) {
    switch (this) {
      case KeySize.none:
        return l10n.channelFormKeySizeNone;
      case KeySize.default1:
        return l10n.channelFormKeySizeDefault;
      case KeySize.bit128:
        return l10n.channelFormKeySizeAes128;
      case KeySize.bit256:
        return l10n.channelFormKeySizeAes256;
    }
  }

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

class _ChannelFormScreenState extends ConsumerState<ChannelFormScreen>
    with LifecycleSafeMixin {
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
      AppLogging.channels(
        '📡 ChannelFormScreen: channel ${channel.index} positionPrecision=$precision',
      );
      _positionEnabled = precision > 0;
      AppLogging.channels(
        '📡 ChannelFormScreen: _positionEnabled=$_positionEnabled',
      );
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
      AppLogging.channels(
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

  String _localizeKeyError(BuildContext context, String errorCode) {
    if (errorCode == 'invalid_base64') {
      return context.l10n.channelFormInvalidBase64;
    } else if (errorCode.startsWith('invalid_key_size:')) {
      final bytes = int.tryParse(errorCode.split(':').last) ?? 0;
      return context.l10n.channelFormInvalidKeySize(bytes);
    } else if (errorCode == 'key_empty') {
      return context.l10n.channelFormKeyEmpty;
    }
    return errorCode;
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
        _keyValidationError = 'invalid_base64';
      } else {
        _keyValidationError = 'invalid_key_size:${decoded.length}';
      }
      _detectedKeySize = null;
    } else if (validatedSize == 0) {
      _keyValidationError = 'key_empty';
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
      showErrorSnackBar(context, context.l10n.channelFormDeviceNotConnected);
      return;
    }

    // Validate key if encryption is enabled
    if (_selectedKeySize != KeySize.none) {
      _validateAndDetectKey(_keyController.text);
      if (_keyValidationError != null) {
        final errorMsg = _localizeKeyError(context, _keyValidationError!);
        showErrorSnackBar(context, errorMsg);
        return;
      }
    }

    // Capture providers before async gap
    final channels = ref.read(channelsProvider);
    final protocol = ref.read(protocolServiceProvider);
    final channelsNotifier = ref.read(channelsProvider.notifier);
    final secureStorage = ref.read(secureStorageProvider);
    final messages = ref.read(messagesProvider);
    final messagesNotifier = ref.read(messagesProvider.notifier);

    safeSetState(() => _isSaving = true);

    // Audit-trail session ID so a single save round-trip can be
    // correlated across the form, protocol service, transport, and
    // channel-response handler in the logs. Stable string, no timing
    // info embedded.
    final saveSessionId = DateTime.now().microsecondsSinceEpoch.toRadixString(
      36,
    );
    final saveStartedAt = DateTime.now();

    try {
      List<int> psk = [];
      if (_selectedKeySize != KeySize.none && _keyController.text.isNotEmpty) {
        psk = base64Decode(_keyController.text.trim());
      }

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
          throw Exception('max_channels');
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

      AppLogging.channels(
        'CHANNEL_SAVE_START sessionId=$saveSessionId '
        'channelIndex=$index name="${newChannel.name}" '
        'role=$role pskLen=${psk.length} '
        'pskFp=${AppLogging.pskFingerprint(psk)} '
        'positionPrecision=$positionPrecision '
        'uplink=$_uplinkEnabled downlink=$_downlinkEnabled',
      );

      // Verify we have node info (indicates device is ready)
      if (protocol.myNodeNum == null) {
        throw Exception('device_not_ready');
      }

      await protocol.setChannel(newChannel);
      if (!mounted) return;
      AppLogging.channels(
        'CHANNEL_SAVE_PROTOCOL_RETURNED sessionId=$saveSessionId',
      );

      // Small delay to allow device to process
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      // Request updated channel info from device to confirm
      await protocol.getChannel(index);
      if (!mounted) return;
      AppLogging.channels(
        'CHANNEL_SAVE_VERIFY_REQUESTED sessionId=$saveSessionId '
        'channelIndex=$index',
      );

      // Update local state only after successful device sync
      channelsNotifier.setChannel(newChannel);
      AppLogging.channels(
        'CHANNEL_SAVE_LOCAL_APPLIED sessionId=$saveSessionId '
        'appliedPskFp=${AppLogging.pskFingerprint(psk)}',
      );

      if (psk.isNotEmpty) {
        await secureStorage.storeChannelKey(
          newChannel.name.isEmpty
              ? context.l10n.channelFormDefaultName(index)
              : newChannel.name,
          psk,
        );
        if (!mounted) return;
      }

      AppLogging.channels(
        'CHANNEL_SAVE_COMPLETE sessionId=$saveSessionId '
        'elapsedMs=${DateTime.now().difference(saveStartedAt).inMilliseconds}',
      );

      // A changed name or key makes this a different logical channel, but
      // messages are keyed by slot index only, so rows received under the
      // previous configuration would keep rendering in the new channel's
      // view as if they belonged to it. Offer to clear them (local-only,
      // never silent - the user decides).
      var clearedOldMessages = false;
      if (isEditing && mounted) {
        final old = widget.existingChannel!;
        final identityChanged =
            old.name != newChannel.name || !listEquals(old.psk, newChannel.psk);
        final hasOldMessages = messages.any(
          (m) => m.channel == index && m.isBroadcast,
        );
        if (identityChanged && hasOldMessages) {
          final l10n = context.l10n;
          final confirmed = await AppBottomSheet.showConfirm(
            context: context,
            title: l10n.channelFormClearOldMessagesTitle,
            message: l10n.channelFormClearOldMessagesBody,
            confirmLabel: l10n.channelFormClearOldMessagesConfirm,
            cancelLabel: l10n.channelFormClearOldMessagesKeep,
            isDestructive: true,
          );
          if (confirmed == true) {
            final removed = await messagesNotifier.deleteChannelMessages(index);
            clearedOldMessages = true;
            AppLogging.channels(
              'CHANNEL_SAVE_OLD_MESSAGES_CLEARED sessionId=$saveSessionId '
              'channelIndex=$index removed=$removed',
            );
          }
          if (!mounted) return;
        }
      }

      safeNavigatorPop();
      safeShowSnackBar(
        clearedOldMessages
            ? context.l10n.channelFormClearOldMessagesSuccess
            : isEditing
            ? context.l10n.channelFormUpdatedSnackbar
            : context.l10n.channelFormCreatedSnackbar,
      );
    } catch (e) {
      AppLogging.channels(
        'CHANNEL_SAVE_FAILED sessionId=$saveSessionId error=$e',
      );
      if (mounted) {
        final errorStr = e.toString();
        if (errorStr.contains('max_channels')) {
          showErrorSnackBar(
            context,
            context.l10n.channelFormMaxChannelsReached,
          );
        } else if (errorStr.contains('device_not_ready')) {
          showErrorSnackBar(context, context.l10n.channelFormDeviceNotReady);
        } else {
          showErrorSnackBar(
            context,
            context.l10n.channelFormError(e.toString()),
          );
        }
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold.body(
        hasScrollBody: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: isEditing
            ? context.l10n.channelFormEditTitle
            : context.l10n.channelFormNewTitle,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _saveChannel,
              child: _isSaving
                  ? LoadingIndicator(size: 20)
                  : Text(
                      context.l10n.channelFormSaveButton,
                      style: TextStyle(
                        color: context.accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.spacing20),
            children: [
              // Channel Name Field
              _buildNameField(),

              const SizedBox(height: AppTheme.spacing28),

              // Encryption Section
              _buildFieldLabel(context.l10n.channelFormEncryptionLabel),
              const SizedBox(height: AppTheme.spacing8),
              _buildEncryptionSelector(),

              if (_selectedKeySize != KeySize.none) ...[
                const SizedBox(height: AppTheme.spacing20),
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

              const SizedBox(height: AppTheme.spacing28),

              // Position Settings
              _buildFieldLabel(context.l10n.channelFormPositionLabel),
              const SizedBox(height: AppTheme.spacing8),
              _buildPositionOptions(),

              const SizedBox(height: AppTheme.spacing28),

              // MQTT Settings
              _buildFieldLabel(context.l10n.channelFormMqttLabel),
              const SizedBox(height: AppTheme.spacing8),
              _buildMqttOptions(),

              if (isPrimaryChannel) ...[
                const SizedBox(height: AppTheme.spacing20),
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with label
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
                  ),
                  child: Icon(Icons.tag, color: context.accentColor, size: 20),
                ),
                SizedBox(width: AppTheme.spacing14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.channelFormNameTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacing2),
                      Text(
                        context.l10n.channelFormNameMaxHint,
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
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
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
            margin: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, 16, 16),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(AppTheme.radius10),
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
                contentPadding: EdgeInsets.all(AppTheme.spacing16),
                hintText: context.l10n.channelFormNameHint,
                hintStyle: TextStyle(
                  color: context.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
                counterText: '',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_\-]')),
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius10,
                            ),
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
                        SizedBox(width: AppTheme.spacing14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                keySize.displayName(context.l10n),
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
                              SizedBox(height: AppTheme.spacing2),
                              Text(
                                keySize == KeySize.none
                                    ? context.l10n.channelFormKeySizeNoneDesc
                                    : keySize == KeySize.default1
                                    ? context.l10n.channelFormKeySizeDefaultDesc
                                    : context.l10n.channelFormKeySizeBitDesc(
                                        keySize.bytes * 8,
                                      ),
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          _buildToggleRow(
            icon: Icons.location_on_outlined,
            iconColor: context.accentColor,
            title: context.l10n.channelFormPositionEnabledTitle,
            subtitle: context.l10n.channelFormPositionEnabledSubtitle,
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
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          _buildToggleRow(
            icon: Icons.cloud_upload_outlined,
            iconColor: context.accentColor,
            title: context.l10n.channelFormUplinkTitle,
            subtitle: context.l10n.channelFormUplinkSubtitle,
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
            title: context.l10n.channelFormDownlinkTitle,
            subtitle: context.l10n.channelFormDownlinkSubtitle,
            value: _downlinkEnabled,
            onChanged: (v) => setState(() => _downlinkEnabled = v),
          ),
          if (_uplinkEnabled || _downlinkEnabled) ...[
            const SizedBox(height: AppTheme.spacing12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: StatusBanner.info(
                title: context.l10n.channelFormMqttWarning,
                margin: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
          ],
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
              borderRadius: BorderRadius.circular(AppTheme.radius10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: AppTheme.spacing14),
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
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
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
        return context.l10n.channelFormPrecision12;
      case 13:
        return context.l10n.channelFormPrecision13;
      case 14:
        return context.l10n.channelFormPrecision14;
      case 15:
        return context.l10n.channelFormPrecision15;
      case 32:
        return context.l10n.channelFormPrecision32;
      default:
        return context.l10n.channelFormPrecisionUnknown;
    }
  }

  Widget _buildPositionPrecisionSection() {
    final accentColor = context.accentColor;
    final hasSecureKey =
        _selectedKeySize != KeySize.none &&
        _selectedKeySize != KeySize.default1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 16),
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
                        : SemanticColors.disabled.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
                  ),
                  child: Icon(
                    Icons.my_location,
                    color: _preciseLocation
                        ? accentColor
                        : SemanticColors.disabled,
                    size: 20,
                  ),
                ),
                SizedBox(width: AppTheme.spacing14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.channelFormPreciseLocationTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        context.l10n.channelFormPreciseLocationSubtitle,
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
            const SizedBox(height: AppTheme.spacing16),
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
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
                  ),
                  child: Icon(
                    Icons.location_searching,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing14),
                Expanded(
                  child: Text(
                    context.l10n.channelFormApproxLocationTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
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
    return StatusBanner.warning(
      title: context.l10n.channelFormPrimaryChannelTitle,
      subtitle: context.l10n.channelFormPrimaryChannelNote,
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
