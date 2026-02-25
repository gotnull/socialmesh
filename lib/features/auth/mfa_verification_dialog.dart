// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/app_bottom_sheet.dart';

import '../../core/theme.dart';
import 'mfa_error_messages.dart';

/// Dialog that handles MFA SMS verification during sign-in.
///
/// When a user with MFA enabled signs in, Firebase throws a
/// [FirebaseAuthMultiFactorException]. This dialog:
/// 1. Sends an SMS code to the user's enrolled phone
/// 2. Prompts the user to enter the code
/// 3. Resolves the sign-in with the MFA assertion
///
/// Returns the [UserCredential] on success, or null if cancelled.
class MFAVerificationDialog extends ConsumerStatefulWidget {
  final MultiFactorResolver resolver;

  const MFAVerificationDialog({super.key, required this.resolver});

  /// Show the MFA dialog and return the result.
  /// Returns [UserCredential] on success, null if cancelled or failed.
  static Future<UserCredential?> show(
    BuildContext context,
    MultiFactorResolver resolver,
  ) {
    return AppBottomSheet.show<UserCredential>(
      context: context,
      isDismissible: false,
      child: MFAVerificationDialog(resolver: resolver),
    );
  }

  @override
  ConsumerState<MFAVerificationDialog> createState() =>
      _MFAVerificationDialogState();
}

class _MFAVerificationDialogState extends ConsumerState<MFAVerificationDialog>
    with LifecycleSafeMixin {
  final _codeController = TextEditingController();
  String? _verificationId;
  String? _errorMessage;
  bool _isSendingCode = true;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _sendVerificationCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    safeSetState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    // Find the phone hint from enrolled factors
    final phoneHint = widget.resolver.hints
        .whereType<PhoneMultiFactorInfo>()
        .firstOrNull;

    if (phoneHint == null) {
      safeSetState(() {
        _isSendingCode = false;
        _errorMessage = 'No phone factor found';
      });
      return;
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        multiFactorSession: widget.resolver.session,
        multiFactorInfo: phoneHint,
        verificationCompleted: (credential) async {
          // Auto-verification (Android only)
          await _resolveWithCredential(credential);
        },
        verificationFailed: (e) {
          safeSetState(() {
            _isSendingCode = false;
            _errorMessage = friendlyMFAError(e);
          });
        },
        codeSent: (verificationId, resendToken) {
          safeSetState(() {
            _verificationId = verificationId;
            _isSendingCode = false;
          });
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      safeSetState(() {
        _isSendingCode = false;
        _errorMessage = friendlyMFAError(e);
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      safeSetState(() => _errorMessage = 'Please enter the 6-digit code');
      return;
    }

    if (_verificationId == null) {
      safeSetState(() => _errorMessage = 'No verification ID. Try resending.');
      return;
    }

    safeSetState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );

    await _resolveWithCredential(credential);
  }

  Future<void> _resolveWithCredential(PhoneAuthCredential credential) async {
    try {
      final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
      final userCredential = await widget.resolver.resolveSignIn(assertion);

      if (!mounted) return;
      Navigator.of(context).pop(userCredential);
    } on FirebaseAuthException catch (e) {
      safeSetState(() {
        _isVerifying = false;
        _errorMessage = friendlyMFAError(e);
      });
    } catch (e) {
      safeSetState(() {
        _isVerifying = false;
        _errorMessage = friendlyMFAError(e);
      });
    }
  }

  String _getMaskedPhone() {
    final phoneHint = widget.resolver.hints
        .whereType<PhoneMultiFactorInfo>()
        .firstOrNull;
    return phoneHint?.phoneNumber ?? 'your phone';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.security, color: context.accentColor),
            const SizedBox(width: AppTheme.spacing12),
            Text(
              'Verify Identity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        if (_isSendingCode) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          ),
          Text(
            'Sending verification code...',
            style: TextStyle(color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          Text(
            'Enter the code sent to ${_getMaskedPhone()}',
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            enabled: !_isVerifying,
            autofocus: true,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 24,
              letterSpacing: 8,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide(color: context.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide(color: context.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide(color: context.accentColor, width: 2),
              ),
            ),
            onSubmitted: (_) => _verifyCode(),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: AppTheme.spacing12),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppTheme.spacing24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isVerifying ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            if (!_isSendingCode) ...[
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  onPressed: _isVerifying ? null : _verifyCode,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
