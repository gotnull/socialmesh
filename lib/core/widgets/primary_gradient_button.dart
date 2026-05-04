// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'animations.dart';

/// Canonical full-width gradient action used for primary sheet/form submits.
class PrimaryGradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  final Color? accentColor;

  const PrimaryGradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !isLoading && onPressed != null;
    final accent = accentColor ?? context.accentColor;

    return BouncyTap(
      enabled: active,
      onTap: active
          ? () {
              HapticFeedback.lightImpact();
              onPressed?.call();
            }
          : null,
      scaleFactor: 0.98,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [accent, accent.withValues(alpha: 0.75)],
                )
              : null,
          color: active ? null : context.border.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: AppTheme.spacing16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: AppTheme.spacing20,
                height: AppTheme.spacing20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    SemanticColors.onAccent,
                  ),
                ),
              )
            else ...[
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: active
                      ? SemanticColors.onAccent
                      : context.textTertiary,
                ),
                const SizedBox(width: AppTheme.spacing8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? SemanticColors.onAccent
                      : context.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
