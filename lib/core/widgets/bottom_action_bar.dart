// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme.dart';

/// A fixed bottom action bar for screens that need a primary action button
/// pinned at the bottom. Uses `context.background` with a subtle top border,
/// matching the Create Signal screen's styling.
///
/// Place this as the last child inside a [Column] that fills the screen, or
/// use it as a [Scaffold.bottomNavigationBar] / similar fixed position.
///
/// Example:
/// ```dart
/// BottomActionBar(
///   child: FilledButton(
///     onPressed: _submit,
///     child: const Text('Save'),
///   ),
/// );
/// ```
///
/// For wizard-style back/next buttons:
/// ```dart
/// BottomActionBar(
///   child: Row(
///     children: [
///       Expanded(child: OutlinedButton(onPressed: _back, child: Text('Back'))),
///       SizedBox(width: AppTheme.spacing16),
///       Expanded(child: FilledButton(onPressed: _next, child: Text('Next'))),
///     ],
///   ),
/// );
/// ```
class BottomActionBar extends StatelessWidget {
  /// The button(s) to display. Typically a [FilledButton], [Row] of buttons,
  /// or a custom gradient container.
  final Widget child;

  /// Horizontal padding. Defaults to [AppTheme.spacing20].
  final double horizontalPadding;

  /// Whether to include bottom safe area padding. Defaults to true.
  final bool useSafeArea;

  const BottomActionBar({
    super.key,
    required this.child,
    this.horizontalPadding = AppTheme.spacing20,
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = useSafeArea
        ? MediaQuery.of(context).padding.bottom
        : 0.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppTheme.spacing12,
        horizontalPadding,
        AppTheme.spacing12 + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: context.background,
        border: Border(
          top: BorderSide(color: context.border.withValues(alpha: 0.2)),
        ),
      ),
      child: child,
    );
  }
}
