// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
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
    final hintKinds = resolver.hints
        .map((h) => h.runtimeType.toString())
        .join(',');
    AppLogging.mfa('show() — ${resolver.hints.length} factor(s): [$hintKinds]');
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
    AppLogging.mfa('_sendVerificationCode — START');
    safeSetState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    // Find the phone hint from enrolled factors
    final phoneHint = widget.resolver.hints
        .whereType<PhoneMultiFactorInfo>()
        .firstOrNull;

    if (phoneHint == null) {
      AppLogging.mfa('_sendVerificationCode — ❌ no PhoneMultiFactorInfo hint');
      safeSetState(() {
        _isSendingCode = false;
        _errorMessage = context.l10n.authMfaNoPhoneFactorFound;
      });
      return;
    }
    AppLogging.mfa(
      '_sendVerificationCode — phone hint: '
      '${_maskPhoneNumber(phoneHint.phoneNumber)} — calling verifyPhoneNumber',
    );

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        multiFactorSession: widget.resolver.session,
        multiFactorInfo: phoneHint,
        verificationCompleted: (credential) async {
          AppLogging.mfa(
            'verifyPhoneNumber → verificationCompleted '
            '(silent/auto — providerId=${credential.providerId}, '
            'hasSmsCode=${credential.smsCode != null})',
          );
          await _resolveWithCredential(credential);
        },
        verificationFailed: (e) {
          AppLogging.mfa(
            'verifyPhoneNumber → ❌ verificationFailed '
            'code=${e.code} message=${e.message}',
          );
          safeSetState(() {
            _isSendingCode = false;
            _errorMessage = friendlyMFAError(e, context.l10n);
          });
        },
        codeSent: (verificationId, resendToken) {
          AppLogging.mfa(
            'verifyPhoneNumber → codeSent (verificationId received, '
            'len=${verificationId.length}, hasResendToken=${resendToken != null})',
          );
          safeSetState(() {
            _verificationId = verificationId;
            _isSendingCode = false;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          AppLogging.mfa(
            'verifyPhoneNumber → codeAutoRetrievalTimeout '
            '(verificationId len=${verificationId.length}, '
            '_verificationId previously set=${_verificationId != null}, '
            '_isSendingCode=$_isSendingCode)',
          );
        },
      );
      AppLogging.mfa('verifyPhoneNumber — returned (callbacks dispatched)');
    } catch (e) {
      AppLogging.mfa('verifyPhoneNumber — ❌ threw sync: $e');
      safeSetState(() {
        _isSendingCode = false;
        _errorMessage = friendlyMFAError(e, context.l10n);
      });
    }
  }

  /// Mask a phone number to ±4 trailing digits, keep country code.
  String _maskPhoneNumber(String? phone) {
    if (phone == null || phone.length < 5) return '<empty>';
    final tail = phone.substring(phone.length - 4);
    return '${phone.substring(0, phone.length > 6 ? 3 : 1)}***$tail';
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    AppLogging.mfa('_verifyCode — START (len=${code.length})');
    if (code.length != 6) {
      AppLogging.mfa('_verifyCode — ❌ invalid length');
      safeSetState(() => _errorMessage = context.l10n.authMfaEnterSixDigitCode);
      return;
    }

    if (_verificationId == null) {
      AppLogging.mfa('_verifyCode — ❌ no verificationId');
      safeSetState(() => _errorMessage = context.l10n.authMfaNoVerificationId);
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
    AppLogging.mfa(
      '_resolveWithCredential — START '
      '(mounted=$mounted, providerId=${credential.providerId})',
    );
    try {
      final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
      AppLogging.mfa('_resolveWithCredential — calling resolver.resolveSignIn');
      final userCredential = await widget.resolver.resolveSignIn(assertion);
      AppLogging.mfa(
        '_resolveWithCredential — ✅ resolveSignIn returned '
        '(uid=${userCredential.user?.uid}, mounted=$mounted)',
      );

      if (!mounted) {
        AppLogging.mfa(
          '_resolveWithCredential — ⚠️ dialog unmounted before pop, '
          'credential dropped',
        );
        return;
      }
      safeNavigatorPop(userCredential);
      AppLogging.mfa('_resolveWithCredential — popped with credential');
    } on FirebaseAuthException catch (e) {
      AppLogging.mfa(
        '_resolveWithCredential — ❌ FirebaseAuthException '
        'code=${e.code} message=${e.message}',
      );
      safeSetState(() {
        _isVerifying = false;
        _errorMessage = friendlyMFAError(e, context.l10n);
      });
    } catch (e) {
      AppLogging.mfa('_resolveWithCredential — ❌ $e');
      safeSetState(() {
        _isVerifying = false;
        _errorMessage = friendlyMFAError(e, context.l10n);
      });
    }
  }

  String _getMaskedPhone() {
    final phoneHint = widget.resolver.hints
        .whereType<PhoneMultiFactorInfo>()
        .firstOrNull;
    return phoneHint?.phoneNumber ?? context.l10n.authMfaYourPhone;
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
              context.l10n.authMfaVerifyIdentityTitle,
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
            context.l10n.authMfaSendingCode,
            style: TextStyle(color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          Text(
            context.l10n.authMfaEnterCodeSentTo(_getMaskedPhone()),
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
              hintText: '000000', // lint-allow: hardcoded-string
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
            style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
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
                  side: BorderSide(color: SemanticColors.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                child: Text(context.l10n.authMfaCancelButton),
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
                      : Text(context.l10n.authMfaVerifyButton),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
