// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/auth_providers.dart';
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';
import 'mfa_enrollment_screen.dart';
import 'mfa_error_messages.dart';
import 'mfa_verification_dialog.dart';

/// Screen for managing multi-factor authentication settings
class MFAManagementScreen extends ConsumerStatefulWidget {
  const MFAManagementScreen({super.key});

  @override
  ConsumerState<MFAManagementScreen> createState() =>
      _MFAManagementScreenState();
}

class _MFAManagementScreenState extends ConsumerState<MFAManagementScreen>
    with LifecycleSafeMixin {
  List<MultiFactorInfo> _enrolledFactors = [];
  bool _isLoadingFactors = true;

  @override
  void initState() {
    super.initState();
    AppLogging.mfa('MFAManagementScreen initState — starting initial load');
    _loadFactors();
  }

  Future<void> _loadFactors() async {
    AppLogging.mfa('_loadFactors — begin');
    safeSetState(() => _isLoadingFactors = true);
    try {
      final authService = ref.read(authServiceProvider);
      AppLogging.mfa('_loadFactors — calling getEnrolledMFAFactors()');
      final factors = await authService.getEnrolledMFAFactors();
      AppLogging.mfa(
        '_loadFactors — received ${factors.length} factor(s): '
        '${factors.map((f) => 'uid=${f.uid}, name=${f.displayName}, type=${f.factorId}').join('; ')}',
      );
      if (!mounted) {
        AppLogging.mfa('_loadFactors — widget disposed after fetch, aborting');
        return;
      }
      safeSetState(() {
        _enrolledFactors = factors;
        _isLoadingFactors = false;
      });
      AppLogging.mfa('_loadFactors — state updated, isLoading=false');
    } catch (e, st) {
      AppLogging.mfa('_loadFactors — ERROR: $e\n$st');
      if (!mounted) {
        AppLogging.mfa('_loadFactors — widget disposed after error, aborting');
        return;
      }
      safeSetState(() => _isLoadingFactors = false);
    }
  }

  Future<void> _enrollMFA() async {
    AppLogging.mfa('_enrollMFA — user tapped Enable Two-Factor Auth');
    final haptics = ref.read(hapticServiceProvider);
    final navigator = Navigator.of(context);

    await haptics.trigger(HapticType.medium);

    AppLogging.mfa('_enrollMFA — pushing MFAEnrollmentScreen');
    final result = await navigator.push<bool>(
      MaterialPageRoute(builder: (context) => const MFAEnrollmentScreen()),
    );
    AppLogging.mfa('_enrollMFA — MFAEnrollmentScreen returned: $result');

    if (result == true && mounted) {
      AppLogging.mfa(
        '_enrollMFA — enrollment succeeded, invalidating provider and reloading',
      );
      // Refresh both local screen state and global provider
      ref.invalidate(enrolledMFAFactorsProvider);
      await _loadFactors();
    } else {
      AppLogging.mfa(
        '_enrollMFA — enrollment not confirmed or widget disposed '
        '(result=$result, mounted=$mounted)',
      );
    }
  }

  Future<void> _removeFactor(MultiFactorInfo factor) async {
    AppLogging.mfa(
      '_removeFactor — user tapped remove for factor '
      'uid=${factor.uid}, name=${factor.displayName}, type=${factor.factorId}',
    );
    final haptics = ref.read(hapticServiceProvider);

    await haptics.trigger(HapticType.warning);

    if (!mounted) {
      AppLogging.mfa('_removeFactor — widget disposed after haptic, aborting');
      return;
    }

    AppLogging.mfa('_removeFactor — showing confirmation dialog');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Two-Factor Auth?',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'Your account will be less secure. You can re-enable it anytime.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    AppLogging.mfa(
      '_removeFactor — dialog result: confirmed=$confirmed, mounted=$mounted',
    );

    if (confirmed != true || !mounted) {
      AppLogging.mfa(
        '_removeFactor — aborting: '
        '${confirmed != true ? 'user cancelled' : 'widget disposed'}',
      );
      return;
    }

    AppLogging.mfa(
      '_removeFactor — proceeding with unenroll for uid=${factor.uid}',
    );

    try {
      final authService = ref.read(authServiceProvider);
      AppLogging.mfa(
        '_removeFactor — calling authService.unenrollMFA(${factor.uid})',
      );
      await authService.unenrollMFA(factor.uid);
      AppLogging.mfa('_removeFactor — unenrollMFA returned successfully');

      if (!mounted) {
        AppLogging.mfa(
          '_removeFactor — widget disposed after unenroll, aborting UI update',
        );
        return;
      }

      await haptics.trigger(HapticType.success);
      if (!mounted) {
        AppLogging.mfa(
          '_removeFactor — widget disposed after success haptic, aborting',
        );
        return;
      }
      safeShowSnackBar('Two-factor authentication removed');
      AppLogging.mfa(
        '_removeFactor — success snackbar shown, '
        'invalidating provider and reloading factors',
      );

      // Refresh both local screen state and global provider
      ref.invalidate(enrolledMFAFactorsProvider);
      await _loadFactors();
      AppLogging.mfa('_removeFactor — reload complete after removal');
    } on FirebaseAuthMultiFactorException catch (e) {
      // Re-auth triggered an MFA challenge for the SAME account.
      // The account has MFA enabled, so re-authentication also requires
      // the second factor. Show the MFA verification dialog, then retry.
      AppLogging.mfa(
        '_removeFactor — re-auth requires MFA verification, '
        'showing MFA dialog (hints=${e.resolver.hints.length})',
      );

      if (!mounted) return;

      final credential = await MFAVerificationDialog.show(context, e.resolver);

      if (credential == null) {
        AppLogging.mfa(
          '_removeFactor — user cancelled MFA verification during re-auth',
        );
        return;
      }

      AppLogging.mfa(
        '_removeFactor — MFA re-auth succeeded, retrying unenroll',
      );

      if (!mounted) return;

      // Re-auth is now complete with MFA — retry the unenroll
      try {
        final authService = ref.read(authServiceProvider);
        await authService.unenrollMFA(factor.uid);
        AppLogging.mfa(
          '_removeFactor — unenrollMFA succeeded after MFA re-auth',
        );

        if (!mounted) return;

        await haptics.trigger(HapticType.success);
        if (!mounted) return;
        safeShowSnackBar('Two-factor authentication removed');

        ref.invalidate(enrolledMFAFactorsProvider);
        await _loadFactors();
        AppLogging.mfa(
          '_removeFactor — reload complete after MFA re-auth removal',
        );
      } on FirebaseAuthException catch (retryErr) {
        AppLogging.mfa(
          '_removeFactor — retry after MFA re-auth failed: '
          'code=${retryErr.code}, message=${retryErr.message}',
        );
        if (!mounted) return;
        await haptics.trigger(HapticType.error);
        if (!mounted) return;
        final friendlyMsg = friendlyMFAError(retryErr);
        AppLogging.mfa('_removeFactor — showing error snackbar: $friendlyMsg');
        safeShowSnackBar(friendlyMsg);
      } catch (retryErr) {
        AppLogging.mfa(
          '_removeFactor — unexpected retry error: '
          'type=${retryErr.runtimeType}, error=$retryErr',
        );
        if (!mounted) return;
        await haptics.trigger(HapticType.error);
        if (!mounted) return;
        safeShowSnackBar(friendlyMFAError(retryErr));
      }
    } on FirebaseAuthException catch (e, st) {
      AppLogging.mfa(
        '_removeFactor — FirebaseAuthException: '
        'code=${e.code}, message=${e.message}, '
        'credential=${e.credential}, email=${e.email}, '
        'tenantId=${e.tenantId}\n$st',
      );

      if (e.code == 'reauthentication-cancelled') {
        AppLogging.mfa(
          '_removeFactor — user cancelled re-authentication, '
          'no error shown',
        );
        return;
      }

      if (e.code == 'wrong-account-selected') {
        AppLogging.mfa(
          '_removeFactor — wrong account selected during re-auth, '
          'showing warning so user can retry',
        );
        if (!mounted) return;
        await haptics.trigger(HapticType.warning);
        if (!mounted) return;
        final friendlyMsg = friendlyMFAError(e);
        AppLogging.mfa(
          '_removeFactor — showing warning snackbar: $friendlyMsg',
        );
        safeShowSnackBar(friendlyMsg, type: SnackBarType.warning);
        return;
      }

      if (!mounted) return;
      await haptics.trigger(HapticType.error);
      if (!mounted) return;
      final friendlyMsg = friendlyMFAError(e);
      AppLogging.mfa('_removeFactor — showing error snackbar: $friendlyMsg');
      safeShowSnackBar(friendlyMsg);
    } on FirebaseException catch (e, st) {
      AppLogging.mfa(
        '_removeFactor — FirebaseException: '
        'code=${e.code}, message=${e.message}, plugin=${e.plugin}\n$st',
      );
      if (!mounted) return;
      await haptics.trigger(HapticType.error);
      if (!mounted) return;
      final friendlyMsg = friendlyMFAError(e);
      AppLogging.mfa('_removeFactor — showing error snackbar: $friendlyMsg');
      safeShowSnackBar(friendlyMsg);
    } catch (e, st) {
      AppLogging.mfa(
        '_removeFactor — unexpected error: '
        'type=${e.runtimeType}, error=$e\n$st',
      );
      if (!mounted) return;
      await haptics.trigger(HapticType.error);
      if (!mounted) return;
      final friendlyMsg = friendlyMFAError(e);
      AppLogging.mfa('_removeFactor — showing error snackbar: $friendlyMsg');
      safeShowSnackBar(friendlyMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrolledFactors = _enrolledFactors;
    final hasMFA = enrolledFactors.isNotEmpty;

    AppLogging.mfa(
      'build — isLoading=$_isLoadingFactors, '
      'factorCount=${enrolledFactors.length}, hasMFA=$hasMFA',
    );

    if (_isLoadingFactors) {
      AppLogging.mfa('build — rendering loading state');
      return GlassScaffold.body(
        title: 'Two-Factor Authentication',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GlassScaffold(
      title: 'Two-Factor Authentication',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasMFA ? Icons.security : Icons.security_outlined,
                      size: 48,
                      color: hasMFA ? Colors.green : context.textSecondary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasMFA ? 'Protected' : 'Not Enabled',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasMFA
                                ? 'Your account is protected with 2FA'
                                : 'Add an extra layer of security',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Enrolled Factors List
              if (enrolledFactors.isNotEmpty) ...[
                Text(
                  'Active Methods',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...enrolledFactors.map((factor) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.border),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.phone_android,
                          color: context.accentColor,
                        ),
                      ),
                      title: Text(
                        factor.displayName ?? 'Phone',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        _formatFactorInfo(factor),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeFactor(factor),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // Add Button
              if (!hasMFA)
                FilledButton.icon(
                  onPressed: _enrollMFA,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Enable Two-Factor Auth'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

              // Info Section
              const SizedBox(height: 32),
              Text(
                'How it works',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                context,
                icon: Icons.phone_android,
                title: 'SMS Verification',
                description:
                    'Receive a verification code via text message when signing in',
              ),
              const SizedBox(height: 8),
              _buildInfoTile(
                context,
                icon: Icons.security,
                title: 'Extra Security',
                description:
                    'Protects your account even if your password is compromised',
              ),
              const SizedBox(height: 8),
              _buildInfoTile(
                context,
                icon: Icons.access_time,
                title: 'Quick & Easy',
                description:
                    'Takes just a few seconds to verify during sign-in',
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: context.accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFactorInfo(MultiFactorInfo factor) {
    final enrollmentTime = factor.enrollmentTimestamp;
    final date = DateTime.fromMillisecondsSinceEpoch(
      enrollmentTime.toInt() * 1000,
    );
    return 'Added ${_formatDate(date)}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
  }
}
