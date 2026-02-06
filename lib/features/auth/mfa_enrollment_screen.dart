// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/auth_providers.dart';
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';
import 'mfa_error_messages.dart';

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
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.medium);

    safeSetState(() => _isLoading = true);

    final authService = ref.read(authServiceProvider);
    final phoneNumber = _phoneController.text.trim();

    await authService.enrollMFA(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        safeSetState(() {
          _verificationId = verificationId;
          _isCodeSent = true;
          _isLoading = false;
        });
        showSuccessSnackBar(context, 'Verification code sent to $phoneNumber');
      },
      onError: (errorCode) {
        if (!mounted) return;
        safeSetState(() => _isLoading = false);
        showErrorSnackBar(context, friendlyMFAErrorCode(errorCode));
      },
    );
  }

  Future<void> _verifyCode() async {
    if (_verificationId == null) return;
    if (_codeController.text.trim().length != 6) {
      showWarningSnackBar(context, 'Please enter the 6-digit code');
      return;
    }

    final haptics = ref.read(hapticServiceProvider);
    final navigator = Navigator.of(context);

    await haptics.trigger(HapticType.medium);

    safeSetState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.completeMFAEnrollment(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
        displayName: 'Phone',
      );

      if (!mounted) return;

      await haptics.trigger(HapticType.success);
      if (!mounted) return;
      safeShowSnackBar('Two-factor authentication enabled');

      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      await haptics.trigger(HapticType.error);
      if (!mounted) return;
      safeShowSnackBar(friendlyMFAError(e));
      safeSetState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
