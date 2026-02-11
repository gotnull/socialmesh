// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/auth_providers.dart';
import '../../services/haptic_service.dart';
import 'mfa_enrollment_screen.dart';
import 'mfa_error_messages.dart';

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
    _loadFactors();
  }

  Future<void> _loadFactors() async {
    safeSetState(() => _isLoadingFactors = true);
    try {
      final authService = ref.read(authServiceProvider);
      final factors = await authService.getEnrolledMFAFactors();
      if (!mounted) return;
      safeSetState(() {
        _enrolledFactors = factors;
        _isLoadingFactors = false;
      });
    } catch (_) {
      if (!mounted) return;
      safeSetState(() => _isLoadingFactors = false);
    }
  }

  Future<void> _enrollMFA() async {
    final haptics = ref.read(hapticServiceProvider);
    final navigator = Navigator.of(context);

    await haptics.trigger(HapticType.medium);

    final result = await navigator.push<bool>(
      MaterialPageRoute(builder: (context) => const MFAEnrollmentScreen()),
    );

    if (result == true && mounted) {
      // Refresh both local screen state and global provider
      ref.invalidate(enrolledMFAFactorsProvider);
      await _loadFactors();
    }
  }

  Future<void> _removeFactor(MultiFactorInfo factor) async {
    final haptics = ref.read(hapticServiceProvider);

    await haptics.trigger(HapticType.warning);

    if (!mounted) return;

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

    if (confirmed != true || !mounted) return;

    try {
      final authService = ref.read(authServiceProvider);
      await authService.unenrollMFA(factor.uid);

      if (!mounted) return;

      await haptics.trigger(HapticType.success);
      if (!mounted) return;
      safeShowSnackBar('Two-factor authentication removed');

      // Refresh both local screen state and global provider
      ref.invalidate(enrolledMFAFactorsProvider);
      await _loadFactors();
    } catch (e) {
      if (!mounted) return;
      await haptics.trigger(HapticType.error);
      if (!mounted) return;
      safeShowSnackBar(friendlyMFAError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrolledFactors = _enrolledFactors;
    final hasMFA = enrolledFactors.isNotEmpty;

    if (_isLoadingFactors) {
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
