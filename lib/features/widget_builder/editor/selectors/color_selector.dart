import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/app_bottom_sheet.dart' as app_sheets;

/// Helper to convert Color to hex string
String colorToHex(Color color) {
  return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}

/// Helper to parse hex string to Color
Color? hexToColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (_) {
    return null;
  }
}

/// A simple color selector using the app's accent colors.
/// Shows a grid of color swatches that the user can tap to select.
class ColorSelector extends StatelessWidget {
  final Color? currentColor;
  final void Function(Color color) onSelect;
  final bool showLabel;

  const ColorSelector({
    super.key,
    this.currentColor,
    required this.onSelect,
    this.showLabel = true,
  });

  /// Show as a bottom sheet and return selected color
  static Future<Color?> show(BuildContext context, {Color? currentColor}) {
    return app_sheets.AppBottomSheet.show<Color>(
      context: context,
      child: _ColorSelectorSheet(currentColor: currentColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Text(
            'COLOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textTertiary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < AccentColors.all.length; i++)
              _ColorSwatch(
                color: AccentColors.all[i],
                name: AccentColors.names[i],
                isSelected: _isSelected(AccentColors.all[i]),
                onTap: () => onSelect(AccentColors.all[i]),
              ),
          ],
        ),
      ],
    );
  }

  bool _isSelected(Color color) {
    if (currentColor == null) return false;
    return currentColor!.toARGB32() == color.toARGB32();
  }
}

/// Color swatch widget
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}

/// Bottom sheet version for standalone color selection
class _ColorSelectorSheet extends StatelessWidget {
  final Color? currentColor;

  const _ColorSelectorSheet({this.currentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Color',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ColorSelector(
          currentColor: currentColor,
          onSelect: (color) => Navigator.pop(context, color),
          showLabel: false,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Compact inline color selector for property editors
class InlineColorSelector extends StatelessWidget {
  final String label;
  final Color? currentColor;
  final Color defaultColor;
  final void Function(Color color) onSelect;

  const InlineColorSelector({
    super.key,
    required this.label,
    this.currentColor,
    required this.defaultColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = currentColor ?? defaultColor;
    final colorName = AccentColors.nameFor(displayColor);

    return InkWell(
      onTap: () async {
        final color = await ColorSelector.show(
          context,
          currentColor: displayColor,
        );
        if (color != null) {
          onSelect(color);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.border),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: displayColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondary,
                    ),
                  ),
                  Text(
                    colorName,
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.palette_outlined,
              size: 18,
              color: context.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
