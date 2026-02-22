// SPDX-License-Identifier: GPL-3.0-or-later

// Mesh 3D View Selector
//
// A bottom sheet for selecting the active 3D view mode. Uses
// AppBottomSheet.show() for consistent styling with the rest of the app.
// Each view mode is presented as a tappable card with icon, title,
// description, and a selected-state indicator.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import 'mesh_3d_models.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Shows the view-mode selector bottom sheet and returns the selected mode,
/// or `null` if the user dismisses without selecting.
Future<Mesh3DViewMode?> showMesh3DViewSelector({
  required BuildContext context,
  required Mesh3DViewMode currentMode,
}) {
  return AppBottomSheet.show<Mesh3DViewMode>(
    context: context,
    child: _ViewSelectorContent(currentMode: currentMode),
  );
}

// ---------------------------------------------------------------------------
// _ViewSelectorContent
// ---------------------------------------------------------------------------

class _ViewSelectorContent extends StatelessWidget {
  final Mesh3DViewMode currentMode;

  const _ViewSelectorContent({required this.currentMode});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'View Mode',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),

        // Mode cards
        ...Mesh3DViewMode.values.map((mode) {
          final isSelected = mode == currentMode;
          return _ViewModeCard(
            mode: mode,
            isSelected: isSelected,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context, mode);
            },
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ViewModeCard
// ---------------------------------------------------------------------------

class _ViewModeCard extends StatelessWidget {
  final Mesh3DViewMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? accentColor.withValues(alpha: 0.1) : context.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: accentColor.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.4)
                    : context.border.withValues(alpha: 0.2),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.15)
                        : context.border.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    mode.icon,
                    size: 20,
                    color: isSelected ? accentColor : context.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected ? accentColor : context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mode.description,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: context.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selected indicator
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.border.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
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
