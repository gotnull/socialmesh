// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/auth_providers.dart';
import '../../providers/connectivity_providers.dart';
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';
import 'mfa_error_messages.dart';
import 'mfa_verification_dialog.dart';

/// Screen for enrolling in SMS multi-factor authentication
class MFAEnrollmentScreen extends ConsumerStatefulWidget {
  const MFAEnrollmentScreen({super.key});

  @override
  ConsumerState<MFAEnrollmentScreen> createState() =>
      _MFAEnrollmentScreenState();
}

class _MFAEnrollmentScreenState extends ConsumerState<MFAEnrollmentScreen>
    with LifecycleSafeMixin {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _verificationId;
  bool _isCodeSent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    AppLogging.mfa('MFAEnrollmentScreen initState');
  }

  @override
  void dispose() {
    AppLogging.mfa('MFAEnrollmentScreen dispose');
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      AppLogging.mfa('_sendCode — blocked, device is offline');
      showErrorSnackBar(
        context,
        'Sending verification codes requires an internet connection.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      AppLogging.mfa('_sendCode — form validation failed');
      return;
    }

    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.medium);

    safeSetState(() => _isLoading = true);

    final authService = ref.read(authServiceProvider);
    final phoneNumber = _phoneController.text.trim();

    AppLogging.mfa('_sendCode — requesting code for phone=$phoneNumber');

    try {
      await authService.enrollMFA(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          AppLogging.mfa(
            '_sendCode — onCodeSent callback fired, '
            'verificationId=${verificationId.substring(0, 8)}..., '
            'resendToken=$resendToken',
          );
          if (!mounted) {
            AppLogging.mfa(
              '_sendCode — widget disposed in onCodeSent, aborting',
            );
            return;
          }
          safeSetState(() {
            _verificationId = verificationId;
            _isCodeSent = true;
            _isLoading = false;
          });
          showSuccessSnackBar(
            context,
            'Verification code sent to $phoneNumber',
          );
          AppLogging.mfa(
            '_sendCode — state updated: isCodeSent=true, isLoading=false',
          );
        },
        onError: (errorCode) {
          AppLogging.mfa(
            '_sendCode — onError callback fired, errorCode=$errorCode',
          );
          if (!mounted) {
            AppLogging.mfa('_sendCode — widget disposed in onError, aborting');
            return;
          }
          safeSetState(() => _isLoading = false);
          final friendlyMsg = friendlyMFAErrorCode(errorCode);
          AppLogging.mfa('_sendCode — showing error snackbar: $friendlyMsg');
          showErrorSnackBar(context, friendlyMsg);
        },
      );
      AppLogging.mfa('_sendCode — enrollMFA returned (callbacks pending)');
    } on FirebaseAuthMultiFactorException catch (e) {
      // Re-auth during enrollment triggered an MFA challenge (edge case:
      // account still has MFA or Firebase session state is stale).
      AppLogging.mfa(
        '_sendCode — re-auth requires MFA verification, '
        'showing MFA dialog (hints=${e.resolver.hints.length})',
      );

      if (!mounted) {
        AppLogging.mfa(
          '_sendCode — widget disposed before MFA dialog, aborting',
        );
        return;
      }

      final credential = await MFAVerificationDialog.show(context, e.resolver);

      if (credential == null || !mounted) {
        AppLogging.mfa(
          '_sendCode — user cancelled MFA verification '
          '(credential=${credential != null}, mounted=$mounted)',
        );
        safeSetState(() => _isLoading = false);
        return;
      }

      AppLogging.mfa('_sendCode — MFA re-auth succeeded, retrying enrollment');

      // Re-auth complete — retry the enrollment
      try {
        final retryService = ref.read(authServiceProvider);
        await retryService.enrollMFA(
          phoneNumber: phoneNumber,
          onCodeSent: (verificationId, resendToken) {
            AppLogging.mfa(
              '_sendCode — retry onCodeSent callback fired, '
              'verificationId=${verificationId.substring(0, 8)}...',
            );
            if (!mounted) return;
            safeSetState(() {
              _verificationId = verificationId;
              _isCodeSent = true;
              _isLoading = false;
            });
            showSuccessSnackBar(
              context,
              'Verification code sent to $phoneNumber',
            );
          },
          onError: (errorCode) {
            AppLogging.mfa(
              '_sendCode — retry onError callback: errorCode=$errorCode',
            );
            if (!mounted) return;
            safeSetState(() => _isLoading = false);
            showErrorSnackBar(context, friendlyMFAErrorCode(errorCode));
          },
        );
        AppLogging.mfa('_sendCode — retry enrollMFA returned');
      } catch (retryErr) {
        AppLogging.mfa(
          '_sendCode — retry after MFA re-auth failed: '
          'type=${retryErr.runtimeType}, error=$retryErr',
        );
        if (!mounted) return;
        safeSetState(() => _isLoading = false);
        showErrorSnackBar(context, friendlyMFAError(retryErr));
      }
    } catch (e) {
      // enrollMFA normally uses onError callback, but re-auth exceptions
      // bypass that path and throw directly.
      AppLogging.mfa(
        '_sendCode — unexpected error: type=${e.runtimeType}, error=$e',
      );
      if (!mounted) return;
      safeSetState(() => _isLoading = false);
      showErrorSnackBar(context, friendlyMFAError(e));
    }
  }

  Future<void> _verifyCode() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      AppLogging.mfa('_verifyCode — blocked, device is offline');
      showErrorSnackBar(
        context,
        'Verifying codes requires an internet connection.',
      );
      return;
    }

    if (_verificationId == null) {
      AppLogging.mfa('_verifyCode — no verificationId, aborting');
      return;
    }

    final code = _codeController.text.trim();
    if (code.length != 6) {
      AppLogging.mfa(
        '_verifyCode — invalid code length: ${code.length} (expected 6)',
      );
      showWarningSnackBar(context, 'Please enter the 6-digit code');
      return;
    }

    AppLogging.mfa(
      '_verifyCode — verifying code, '
      'verificationId=${_verificationId!.substring(0, 8)}...',
    );

    final haptics = ref.read(hapticServiceProvider);
    final navigator = Navigator.of(context);

    await haptics.trigger(HapticType.medium);

    safeSetState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      AppLogging.mfa('_verifyCode — calling completeMFAEnrollment');
      await authService.completeMFAEnrollment(
        verificationId: _verificationId!,
        smsCode: code,
        displayName: 'Phone',
      );
      AppLogging.mfa('_verifyCode — completeMFAEnrollment succeeded');

      if (!mounted) {
        AppLogging.mfa('_verifyCode — widget disposed after enrollment');
        return;
      }

      await haptics.trigger(HapticType.success);
      if (!mounted) return;
      safeShowSnackBar('Two-factor authentication enabled');
      AppLogging.mfa('_verifyCode — success, popping with result=true');

      navigator.pop(true);
    } catch (e) {
      AppLogging.mfa('_verifyCode — error: type=${e.runtimeType}, error=$e');
      if (!mounted) return;
      await haptics.trigger(HapticType.error);
      if (!mounted) return;
      final friendlyMsg = friendlyMFAError(e);
      AppLogging.mfa('_verifyCode — showing error snackbar: $friendlyMsg');
      safeShowSnackBar(friendlyMsg);
      safeSetState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLogging.mfa(
      'MFAEnrollmentScreen build — '
      'isCodeSent=$_isCodeSent, isLoading=$_isLoading, '
      'hasVerificationId=${_verificationId != null}',
    );

    return GlassScaffold.body(
      title: 'Enable Two-Factor Auth',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.security, size: 64, color: context.accentColor),
              const SizedBox(height: 24),
              Text(
                'Add an extra layer of security',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ll receive a verification code via SMS when signing in',
                style: TextStyle(fontSize: 14, color: context.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (!_isCodeSent) ...[
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !_isLoading,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+1 234 567 890',
                    prefixIcon: Icon(Icons.phone, color: context.accentColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.accentColor,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (!value.startsWith('+')) {
                      return 'Phone number must include country code (+1, +44, etc.)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _sendCode,
                  icon: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: SemanticColors.onAccent,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isLoading ? 'Sending...' : 'Send Code'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  enabled: !_isLoading,
                  maxLength: 6,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 24,
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Verification Code',
                    hintText: '000000',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.accentColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter the 6-digit code sent to ${_phoneController.text}',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _verifyCode,
                  icon: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: SemanticColors.onAccent,
                          ),
                        )
                      : const Icon(Icons.verified_user),
                  label: Text(_isLoading ? 'Verifying...' : 'Verify & Enable'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          AppLogging.mfa(
                            '_changePhoneNumber — user tapped Change Phone Number',
                          );
                          safeSetState(() {
                            _isCodeSent = false;
                            _codeController.clear();
                          });
                        },
                  child: const Text('Change Phone Number'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
