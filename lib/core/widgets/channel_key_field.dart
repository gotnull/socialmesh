// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n_extension.dart';
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

  // Optional external controller. When provided, the parent owns the
  // lifecycle and can read the current text directly — required for the
  // create-channel wizard so a manually-typed key persists into the
  // wizard draft even if the user taps Continue without first tapping
  // the inline check button.
  final TextEditingController? controller;

  const ChannelKeyField({
    super.key,
    required this.keyBase64,
    required this.onKeyChanged,
    required this.expectedKeyBytes,
    this.editable = true,
    this.accentColor,
    this.showGenerateButton = true,
    this.controller,
  });

  @override
  State<ChannelKeyField> createState() => _ChannelKeyFieldState();
}

class _ChannelKeyFieldState extends State<ChannelKeyField> {
  TextEditingController? _ownedController;
  TextEditingController get _keyController =>
      widget.controller ?? _ownedController!;
  bool _showKey = false;
  bool _isEditingKey = false;
  String? _keyValidationError;
  int? _detectedKeyBytes;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.keyBase64);
    } else if (widget.controller!.text.isEmpty && widget.keyBase64.isNotEmpty) {
      widget.controller!.text = widget.keyBase64;
    }
    _validateAndDetectKey(_keyController.text);
    // External writes to a shared controller (e.g. the wizard
    // regenerating after a privacy-level change) must re-trigger
    // validation so the badge, status colour, and wrong-length error
    // reflect the new bytes instead of the previous edit's state.
    _keyController.addListener(_onControllerTextChanged);
  }

  void _onControllerTextChanged() {
    if (!mounted) return;
    final priorBytes = _detectedKeyBytes;
    final priorError = _keyValidationError;
    _validateAndDetectKey(_keyController.text);
    if (_detectedKeyBytes != priorBytes || _keyValidationError != priorError) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(ChannelKeyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync from keyBase64 when we own the controller — when the
    // parent owns it, the parent is the source of truth and must not be
    // overwritten on rebuild (this was the wizard regression).
    if (_ownedController != null &&
        oldWidget.keyBase64 != widget.keyBase64 &&
        !_isEditingKey) {
      _ownedController!.text = widget.keyBase64;
      _validateAndDetectKey(widget.keyBase64);
    }
  }

  @override
  void dispose() {
    _keyController.removeListener(_onControllerTextChanged);
    _ownedController?.dispose();
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
            'Invalid key size (${decoded.length} bytes). Use 1, 16, or 32 bytes.'; // lint-allow: hardcoded-string
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
    // Cross-check the detected size against the size the parent screen
    // actually expects (e.g. Private = 16, Maximum = 32). The internal
    // _keyValidationError only flags malformed base64 / non-standard
    // sizes: it accepts 1/16/32 indiscriminately, which is too loose
    // for the create-channel wizard where mis-sized keys silently
    // disable Continue.
    final detected = _detectedKeyBytes;
    final expected = widget.expectedKeyBytes;
    final sizeMismatch =
        _keyValidationError == null &&
        detected != null &&
        expected > 0 &&
        detected != expected;
    final effectiveError = sizeMismatch
        ? context.l10n.channelWizardKeyWrongLength(expected, detected)
        : _keyValidationError;
    final hasValidKey =
        effectiveError == null && _keyController.text.isNotEmpty;
    final detectedDisplay = _detectedKeyBytes != null
        ? ChannelKeyUtils.getKeySizeDetailedDisplay(_detectedKeyBytes!)
        : '';

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          // Outer card keeps its neutral border. The error state is
          // shown by the inner input box and the validation message
          // only — matching the inner radius avoids a double red ring
          // with mismatched corners.
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with label and actions
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 16, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasValidKey
                          ? _accentColor.withAlpha(38)
                          : effectiveError != null
                          ? AppTheme.errorRed.withAlpha(38)
                          : context.background,
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
                    ),
                    child: Icon(
                      Icons.key,
                      color: hasValidKey
                          ? _accentColor
                          : effectiveError != null
                          ? AppTheme.errorRed
                          : context.textTertiary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.channelKeyEncryptionKey,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          _isEditingKey
                              ? context.l10n.channelKeyEnterBase64
                              : hasValidKey && detectedDisplay.isNotEmpty
                              ? detectedDisplay
                              : context.l10n.channelKeyBase64Encoded,
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
                        borderRadius: BorderRadius.circular(AppTheme.radius6),
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
              margin: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, 16, 8),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(AppTheme.radius10),
                border: Border.all(
                  color: effectiveError != null
                      ? AppTheme.errorRed.withAlpha(128)
                      : context.border.withAlpha(128),
                ),
              ),
              child: _isEditingKey && widget.editable
                  ? TextField(
                      maxLength: 64,
                      controller: _keyController,
                      // AES-256 base64 is 44 chars and wraps on iPhone
                      // width — let the field grow to two lines so the
                      // entire key is visible while editing.
                      maxLines: 2,
                      minLines: 1,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textPrimary,
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(
                          AppTheme.spacing16,
                        ),
                        hintText: context.l10n.channelKeyHint,
                        hintStyle: TextStyle(
                          color: context.textTertiary.withAlpha(128),
                          fontFamily: AppTheme.fontFamily,
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
                        counterText: '',
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
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        child: _showKey
                            ? SelectableText(
                                _keyController.text.isEmpty
                                    ? context.l10n.channelKeyNoKeySet
                                    : _keyController.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _keyController.text.isEmpty
                                      ? context.textTertiary
                                      : _accentColor,
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                  height: 1.5,
                                ),
                              )
                            : Text(
                                _keyController.text.isEmpty
                                    ? context.l10n.channelKeyNoKeySet
                                    : '•' * min(32, _keyController.text.length),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textTertiary.withAlpha(128),
                                  fontFamily: AppTheme.fontFamily,
                                  letterSpacing: 2,
                                ),
                              ),
                      ),
                    ),
            ),

            // Validation error message
            if (effectiveError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  0,
                  16,
                  8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.errorRed,
                      size: 14,
                    ),
                    const SizedBox(width: AppTheme.spacing6),
                    Expanded(
                      child: Text(
                        effectiveError,
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
                padding: const EdgeInsets.fromLTRB(AppTheme.spacing8, 8, 8, 12),
                child: Row(
                  children: [
                    // Show/Hide toggle
                    _buildActionButton(
                      icon: _showKey ? Icons.visibility_off : Icons.visibility,
                      label: _showKey
                          ? context.l10n.channelKeyHide
                          : context.l10n.channelKeyShow,
                      onPressed: () => setState(() => _showKey = !_showKey),
                      isEnabled: true,
                    ),
                    const SizedBox(width: AppTheme.spacing4),
                    // Edit manually
                    _buildActionButton(
                      icon: Icons.edit,
                      label: context.l10n.channelKeyEdit,
                      onPressed: () {
                        setState(() {
                          _isEditingKey = true;
                          _showKey = true;
                        });
                      },
                      isEnabled: !_isEditingKey,
                    ),
                    if (widget.showGenerateButton) ...[
                      const SizedBox(width: AppTheme.spacing4),
                      // Regenerate — no snackbar; the field visibly
                      // updates with the new key, which is its own
                      // confirmation.
                      _buildActionButton(
                        icon: Icons.refresh,
                        label: context.l10n.channelKeyGenerate,
                        onPressed: !_isEditingKey ? _generateRandomKey : null,
                        isEnabled: !_isEditingKey,
                      ),
                    ],
                    const SizedBox(width: AppTheme.spacing4),
                    // Copy
                    _buildActionButton(
                      icon: Icons.copy,
                      label: context.l10n.channelKeyCopy,
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
                                context.l10n.channelKeyCopied,
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
          borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                const SizedBox(width: AppTheme.spacing6),
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
