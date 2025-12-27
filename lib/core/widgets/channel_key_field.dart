import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../../utils/encoding.dart';
import '../../utils/snackbar.dart';

/// A reusable widget for displaying and editing channel encryption keys.
/// Used in both channel creation wizard and channel edit form.
class ChannelKeyField extends StatefulWidget {
  /// The current key value in base64 format
  final String keyBase64;

  /// Called when the key changes (user edits or generates new)
  final ValueChanged<String> onKeyChanged;

  /// Expected key size in bytes (0, 1, 16, or 32)
  final int expectedKeyBytes;

  /// Whether the key can be edited (for read-only display, set to false)
  final bool editable;

  /// Optional accent color override
  final Color? accentColor;

  /// Whether to show the generate button
  final bool showGenerateButton;

  const ChannelKeyField({
    super.key,
    required this.keyBase64,
    required this.onKeyChanged,
    required this.expectedKeyBytes,
    this.editable = true,
    this.accentColor,
    this.showGenerateButton = true,
  });

  @override
  State<ChannelKeyField> createState() => _ChannelKeyFieldState();
}

class _ChannelKeyFieldState extends State<ChannelKeyField> {
  late TextEditingController _keyController;
  bool _showKey = false;
  bool _isEditingKey = false;
  String? _keyValidationError;
  int? _detectedKeyBytes;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.keyBase64);
    _validateAndDetectKey(widget.keyBase64);
  }

  @override
  void didUpdateWidget(ChannelKeyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyBase64 != widget.keyBase64 && !_isEditingKey) {
      _keyController.text = widget.keyBase64;
      _validateAndDetectKey(widget.keyBase64);
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _validateAndDetectKey(String keyText) {
    if (keyText.isEmpty) {
      _keyValidationError = null;
      _detectedKeyBytes = null;
      return;
    }

    final validatedSize = ChannelKeyUtils.validateKeySize(keyText);
    if (validatedSize == null) {
      final decoded = ChannelKeyUtils.base64ToKey(keyText);
      if (decoded == null) {
        _keyValidationError = 'Invalid base64 encoding';
      } else {
        _keyValidationError =
            'Invalid key size (${decoded.length} bytes). Use 1, 16, or 32 bytes.';
      }
      _detectedKeyBytes = null;
    } else if (validatedSize == 0) {
      _keyValidationError = 'Key cannot be empty';
      _detectedKeyBytes = null;
    } else {
      _keyValidationError = null;
      _detectedKeyBytes = validatedSize;
    }
  }

  void _generateRandomKey() {
    if (widget.expectedKeyBytes == 0) {
      _keyController.text = '';
      _keyValidationError = null;
      _detectedKeyBytes = null;
      widget.onKeyChanged('');
      return;
    }

    if (widget.expectedKeyBytes == 1) {
      _keyController.text = 'AQ==';
      _validateAndDetectKey(_keyController.text);
      widget.onKeyChanged(_keyController.text);
      setState(() {});
      return;
    }

    final random = Random.secure();
    final keyBytes = List<int>.generate(
      widget.expectedKeyBytes,
      (_) => random.nextInt(256),
    );
    _keyController.text = ChannelKeyUtils.keyToBase64(keyBytes);
    _validateAndDetectKey(_keyController.text);
    widget.onKeyChanged(_keyController.text);
    setState(() {});
  }

  Color get _accentColor => widget.accentColor ?? context.accentColor;

  @override
  Widget build(BuildContext context) {
    final hasValidKey =
        _keyValidationError == null && _keyController.text.isNotEmpty;
    final detectedDisplay = _detectedKeyBytes != null
        ? ChannelKeyUtils.getKeySizeDetailedDisplay(_detectedKeyBytes!)
        : '';

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _keyValidationError != null
                ? AppTheme.errorRed.withAlpha(128)
                : context.border,
          ),
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
                      color: hasValidKey
                          ? _accentColor.withAlpha(38)
                          : _keyValidationError != null
                          ? AppTheme.errorRed.withAlpha(38)
                          : context.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.key,
                      color: hasValidKey
                          ? _accentColor
                          : _keyValidationError != null
                          ? AppTheme.errorRed
                          : context.textTertiary,
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
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isEditingKey
                              ? 'Enter base64-encoded key'
                              : hasValidKey && detectedDisplay.isNotEmpty
                              ? detectedDisplay
                              : 'Base64 encoded',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasValidKey
                                ? _accentColor
                                : context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Auto-detect badge when valid
                  if (hasValidKey &&
                      _detectedKeyBytes != null &&
                      !_isEditingKey)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _accentColor.withAlpha(38),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ChannelKeyUtils.getKeySizeDisplayName(
                          _detectedKeyBytes!,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _accentColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Key input/display area
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _keyValidationError != null
                      ? AppTheme.errorRed.withAlpha(128)
                      : context.border.withAlpha(128),
                ),
              ),
              child: _isEditingKey && widget.editable
                  ? TextField(
                      controller: _keyController,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        hintText: 'e.g., AQ== or AAAAAAAAAAAAAAAAAAAAAA==',
                        hintStyle: TextStyle(
                          color: context.textTertiary.withAlpha(128),
                          fontFamily: 'monospace',
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.check, color: _accentColor),
                          onPressed: () {
                            _validateAndDetectKey(_keyController.text);
                            widget.onKeyChanged(_keyController.text);
                            setState(() {
                              _isEditingKey = false;
                            });
                          },
                        ),
                      ),
                      onChanged: (value) {
                        _validateAndDetectKey(value);
                        setState(() {});
                      },
                      onSubmitted: (_) {
                        _validateAndDetectKey(_keyController.text);
                        widget.onKeyChanged(_keyController.text);
                        setState(() {
                          _isEditingKey = false;
                        });
                      },
                      autofocus: true,
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _showKey
                            ? SelectableText(
                                _keyController.text.isEmpty
                                    ? '(no key set)'
                                    : _keyController.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _keyController.text.isEmpty
                                      ? context.textTertiary
                                      : _accentColor,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                  height: 1.5,
                                ),
                              )
                            : Text(
                                _keyController.text.isEmpty
                                    ? '(no key set)'
                                    : '•' * min(32, _keyController.text.length),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textTertiary.withAlpha(128),
                                  fontFamily: 'monospace',
                                  letterSpacing: 2,
                                ),
                              ),
                      ),
                    ),
            ),

            // Validation error message
            if (_keyValidationError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.errorRed,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _keyValidationError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Action buttons row
            if (widget.editable)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Row(
                  children: [
                    // Show/Hide toggle
                    _buildActionButton(
                      icon: _showKey ? Icons.visibility_off : Icons.visibility,
                      label: _showKey ? 'Hide' : 'Show',
                      onPressed: () => setState(() => _showKey = !_showKey),
                      isEnabled: true,
                    ),
                    const SizedBox(width: 4),
                    // Edit manually
                    _buildActionButton(
                      icon: Icons.edit,
                      label: 'Edit',
                      onPressed: () {
                        setState(() {
                          _isEditingKey = true;
                          _showKey = true;
                        });
                      },
                      isEnabled: !_isEditingKey,
                    ),
                    if (widget.showGenerateButton) ...[
                      const SizedBox(width: 4),
                      // Regenerate
                      _buildActionButton(
                        icon: Icons.refresh,
                        label: 'Generate',
                        onPressed: !_isEditingKey
                            ? () {
                                _generateRandomKey();
                                showSuccessSnackBar(
                                  context,
                                  'New key generated',
                                  duration: const Duration(seconds: 1),
                                );
                              }
                            : null,
                        isEnabled: !_isEditingKey,
                      ),
                    ],
                    const SizedBox(width: 4),
                    // Copy
                    _buildActionButton(
                      icon: Icons.copy,
                      label: 'Copy',
                      onPressed:
                          _showKey &&
                              !_isEditingKey &&
                              _keyController.text.isNotEmpty
                          ? () {
                              Clipboard.setData(
                                ClipboardData(text: _keyController.text),
                              );
                              showSuccessSnackBar(
                                context,
                                'Key copied to clipboard',
                                duration: const Duration(seconds: 1),
                              );
                            }
                          : null,
                      isEnabled:
                          _showKey &&
                          !_isEditingKey &&
                          _keyController.text.isNotEmpty,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
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
                      ? context.textSecondary
                      : context.textTertiary.withAlpha(102),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isEnabled
                        ? context.textSecondary
                        : context.textTertiary.withAlpha(102),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
