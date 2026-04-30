// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n_extension.dart';
import '../core/theme.dart';
import '../core/widgets/glass_scaffold.dart';
import '../providers/app_providers.dart';

/// Shown when [AppInitNotifier] enters [AppInitState.error] — bootstrap
/// failed (Firebase init, settings load, etc.). Tap to retry.
class ErrorScreen extends ConsumerWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassScaffold.body(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorRed,
              ),
              const SizedBox(height: AppTheme.spacing24),
              Text(
                'Something went wrong', // lint-allow: hardcoded-string
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                'Failed to initialize the app. Please try again.', // lint-allow: hardcoded-string
                style: context.titleSmallStyle?.copyWith(
                  color: context.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppTheme.spacing32),
              ElevatedButton(
                onPressed: () {
                  ref.read(appInitProvider.notifier).initialize();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
