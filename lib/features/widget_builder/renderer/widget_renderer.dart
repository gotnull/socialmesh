// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/widget_schema.dart';
import '../models/data_binding.dart';
import 'primitive_renderers.dart';
import 'widget_action_handler.dart';
import '../../../core/theme.dart';
import '../../../models/mesh_models.dart';

/// Main widget renderer - interprets WidgetSchema and builds Flutter widgets
class WidgetRenderer extends ConsumerWidget {
  final WidgetSchema schema;
  final MeshNode? node;
  final Map<int, MeshNode>? allNodes;
  final Color accentColor;
  final bool isPreview;
  final bool usePlaceholderData;
  final String? selectedElementId;
  final void Function(String elementId)? onElementTap;

  /// Whether to enable action handling (disabled in editor preview)
  final bool enableActions;

  /// Whether to show the outer card decoration (set false when embedded in another card)
  final bool showCard;

  /// Device-level signal data (from protocol streams)
  final int? deviceRssi;
  final double? deviceSnr;
  final double? deviceChannelUtil;

  const WidgetRenderer({
    super.key,
    required this.schema,
    this.node,
    this.allNodes,
    required this.accentColor,
    this.isPreview = false,
    this.usePlaceholderData = false,
    this.selectedElementId,
    this.onElementTap,
    this.enableActions = true,
    this.showCard = true,
    this.deviceRssi,
    this.deviceSnr,
    this.deviceChannelUtil,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Create binding engine with current context
    final bindingEngine = DataBindingEngine();
    bindingEngine.setUsePlaceholderData(usePlaceholderData);
    bindingEngine.setCurrentNode(node);
    bindingEngine.setAllNodes(allNodes);
    bindingEngine.setDeviceSignal(
      rssi: deviceRssi,
      snr: deviceSnr,
      channelUtil: deviceChannelUtil,
    );

    final content = _ElementRenderer(
      element: schema.root,
      bindingEngine: bindingEngine,
      accentColor: accentColor,
      isPreview: isPreview,
      selectedElementId: selectedElementId,
      onElementTap: onElementTap,
      enableActions: enableActions && !isPreview,
      ref: ref,
      fillParent: schema.root.style.expanded == true,
    );

    if (!showCard) {
      return content;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.topLeft,
      child: content,
    );
  }
}

/// Internal element renderer - recursively renders elements
class _ElementRenderer extends StatelessWidget {
  final ElementSchema element;
  final DataBindingEngine bindingEngine;
  final Color accentColor;
  final bool isPreview;
  final String? selectedElementId;
  final void Function(String elementId)? onElementTap;
  final bool enableActions;
  final WidgetRef ref;
  final bool fillParent;

  const _ElementRenderer({
    required this.element,
    required this.bindingEngine,
    required this.accentColor,
    required this.ref,
    this.isPreview = false,
    this.selectedElementId,
    this.onElementTap,
    this.enableActions = false,
    this.fillParent = false,
  });

  @override
  Widget build(BuildContext context) {
    // Check condition first
    if (element.condition != null) {
      final conditionMet = bindingEngine.evaluateCondition(element.condition!);
      if (!conditionMet) {
        return const SizedBox.shrink();
      }
    }

    // Build the element widget
    Widget child = _buildElement(context);

    // Apply styling wrapper
    child = _applyStyle(child);

    // Add selection highlight in editor mode
    if (isPreview && onElementTap != null) {
      final isSelected = selectedElementId == element.id;
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onElementTap!(element.id),
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(color: accentColor, width: 2),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: child,
        ),
      );
    }
    // Add action handling for runtime mode with visual feedback
    else if (enableActions && element.action != null) {
      // Wrap in Material + InkWell for tap feedback
      child = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              WidgetActionHandler.handleAction(context, ref, element.action!),
          borderRadius: BorderRadius.circular(element.style.borderRadius ?? 12),
          splashColor: accentColor.withValues(alpha: 0.3),
          highlightColor: accentColor.withValues(alpha: 0.1),
          child: child,
        ),
      );
    }

    return child;
  }

  Widget _buildElement(BuildContext context) {
    switch (element.type) {
      case ElementType.text:
        return TextRenderer(
          element: element,
          bindingEngine: bindingEngine,
          accentColor: accentColor,
        );

      case ElementType.icon:
        return IconRenderer(
          element: element,
          bindingEngine: bindingEngine,
          accentColor: accentColor,
        );

      case ElementType.image:
        return _buildImage(context);

      case ElementType.gauge:
        return GaugeRenderer(
          element: element,
          bindingEngine: bindingEngine,
          accentColor: accentColor,
        );

      case ElementType.chart:
        return ChartRenderer(
          element: element,
          bindingEngine: bindingEngine,
          accentColor: accentColor,
          isPreview: isPreview,
        );

      case ElementType.map:
        return _buildMap(context);

      case ElementType.shape:
        return _buildShape(context);

      case ElementType.conditional:
        return _buildConditional();

      case ElementType.container:
        return _buildContainer(context);

      case ElementType.row:
        return _buildRow(context);

      case ElementType.column:
        return _buildColumn(context);

      case ElementType.spacer:
        return SpacerRenderer(element: element);

      case ElementType.stack:
        return _buildStack(context);

      case ElementType.button:
        return _buildButton();
    }
  }

  Widget _buildButton() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: element.style.padding ?? 12,
        vertical: (element.style.padding ?? 12) / 2,
      ),
      decoration: BoxDecoration(
        color: element.style.backgroundColorValue ?? accentColor,
        borderRadius: BorderRadius.circular(element.style.borderRadius ?? 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (element.iconName != null) ...[
            Icon(
              _getIconData(element.iconName!),
              size: element.iconSize ?? 18,
              color: element.style.textColorValue ?? Colors.white,
            ),
            if (element.text != null && element.text!.isNotEmpty)
              const SizedBox(width: 6),
          ],
          if (element.text != null && element.text!.isNotEmpty)
            Text(
              element.text!,
              style: TextStyle(
                color: element.style.textColorValue ?? Colors.white,
                fontSize: element.style.fontSize ?? 14,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconData(String name) {
    const iconMap = {
      'star': Icons.star,
      'favorite': Icons.favorite,
      'battery_full': Icons.battery_full,
      'signal_cellular_alt': Icons.signal_cellular_alt,
      'wifi': Icons.wifi,
      'gps_fixed': Icons.gps_fixed,
      'thermostat': Icons.thermostat,
      'water_drop': Icons.water_drop,
      'check_circle': Icons.check_circle,
      'warning': Icons.warning,
      'error': Icons.error,
      'info': Icons.info,
      'send': Icons.send,
      'message': Icons.message,
      'flash_on': Icons.flash_on,
      'speed': Icons.speed,
      'hub': Icons.hub,
      'router': Icons.router,
      'touch_app': Icons.touch_app,
      'location_on': Icons.location_on,
      'timeline': Icons.timeline,
      'refresh': Icons.refresh,
      'warning_amber': Icons.warning_amber,
    };
    return iconMap[name] ?? Icons.help_outline;
  }

  Widget _buildImage(BuildContext context) {
    if (element.imageAsset != null) {
      return Image.asset(
        element.imageAsset!,
        width: element.style.width,
        height: element.style.height,
        fit: BoxFit.contain,
        errorBuilder: (ctx, error, stackTrace) => _buildImagePlaceholder(ctx),
      );
    }

    if (element.imageUrl != null) {
      return Image.network(
        element.imageUrl!,
        width: element.style.width,
        height: element.style.height,
        fit: BoxFit.contain,
        errorBuilder: (ctx, error, stackTrace) => _buildImagePlaceholder(ctx),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return _buildImagePlaceholder(ctx);
        },
      );
    }

    return _buildImagePlaceholder(context);
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Container(
      width: element.style.width ?? 40,
      height: element.style.height ?? 40,
      decoration: BoxDecoration(
        color: context.border,
        borderRadius: BorderRadius.circular(element.style.borderRadius ?? 4),
      ),
      child: Icon(
        Icons.image_outlined,
        color: context.textTertiary,
        size: (element.style.width ?? 40) * 0.5,
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    // Placeholder for mini map - actual map implementation would use flutter_map
    return Container(
      width: element.style.width,
      height: element.style.height ?? 100,
      decoration: BoxDecoration(
        color: context.background,
        borderRadius: BorderRadius.circular(element.style.borderRadius ?? 8),
        border: Border.all(color: context.border),
      ),
      child: Stack(
        children: [
          // Grid pattern to simulate map
          CustomPaint(
            size: Size(
              element.style.width ?? double.infinity,
              element.style.height ?? 100,
            ),
            painter: _MapGridPainter(),
          ),
          // Center marker
          Center(child: Icon(Icons.location_on, color: accentColor, size: 24)),
          // Label
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.card.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Map View',
                style: TextStyle(color: context.textTertiary, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditional() {
    // For conditional elements, render children
    if (element.children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: element.children.map((child) {
        return _ElementRenderer(
          element: child,
          bindingEngine: bindingEngine,
          accentColor: accentColor,
          isPreview: isPreview,
          selectedElementId: selectedElementId,
          onElementTap: onElementTap,
          enableActions: enableActions,
          ref: ref,
        );
      }).toList(),
    );
  }

  Widget _buildShape(BuildContext context) {
    // Build child widget if shape has children (e.g., circle with icon inside)
    Widget? childWidget;
    if (element.children.isNotEmpty) {
      // For shapes, we typically have a single centered child
      if (element.children.length == 1) {
        childWidget = _ElementRenderer(
          element: element.children.first,
          bindingEngine: bindingEngine,
          accentColor: accentColor,
          isPreview: isPreview,
          selectedElementId: selectedElementId,
          onElementTap: onElementTap,
          enableActions: enableActions,
          ref: ref,
        );
      } else {
        // Multiple children - stack them
        childWidget = Stack(
          alignment: Alignment.center,
          children: element.children.map((child) {
            return _ElementRenderer(
              element: child,
              bindingEngine: bindingEngine,
              accentColor: accentColor,
              isPreview: isPreview,
              selectedElementId: selectedElementId,
              onElementTap: onElementTap,
              enableActions: enableActions,
              ref: ref,
            );
          }).toList(),
        );
      }
    }

    return ShapeRenderer(
      element: element,
      accentColor: accentColor,
      borderColor: context.border,
      child: childWidget,
    );
  }

  Widget _buildContainer(BuildContext context) {
    final children = element.children.map((child) {
      return _ElementRenderer(
        element: child,
        bindingEngine: bindingEngine,
        accentColor: accentColor,
        isPreview: isPreview,
        selectedElementId: selectedElementId,
        onElementTap: onElementTap,
        enableActions: enableActions,
        ref: ref,
      );
    }).toList();

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    // Single child - just return it directly, let _applyStyle handle sizing
    if (children.length == 1) {
      return children.first;
    }

    // Multiple children - stack them in a column
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          element.style.mainAxisAlignmentValue ?? MainAxisAlignment.start,
      crossAxisAlignment:
          element.style.crossAxisAlignmentValue ?? CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildRow(BuildContext context) {
    final spacing = element.style.spacing ?? 0;
    final children = <Widget>[];
    final shouldStretch = fillParent || element.style.expanded == true;

    for (var i = 0; i < element.children.length; i++) {
      final child = element.children[i];
      Widget childWidget = _ElementRenderer(
        element: child,
        bindingEngine: bindingEngine,
        accentColor: accentColor,
        isPreview: isPreview,
        selectedElementId: selectedElementId,
        onElementTap: onElementTap,
        enableActions: enableActions,
        ref: ref,
        fillParent: child.style.expanded == true,
      );

      // Wrap in Expanded if style.expanded is true or flex is set
      if (child.style.expanded == true || child.style.flex != null) {
        childWidget = Expanded(flex: child.style.flex ?? 1, child: childWidget);
      }

      children.add(childWidget);

      // Add spacing between children (not after last)
      if (spacing > 0 && i < element.children.length - 1) {
        children.add(SizedBox(width: spacing));
      }
    }

    // Use max size when alignment needs space distribution or when filling parent
    final alignment =
        element.style.mainAxisAlignmentValue ?? MainAxisAlignment.start;
    final needsMaxSize =
        shouldStretch ||
        alignment == MainAxisAlignment.spaceAround ||
        alignment == MainAxisAlignment.spaceBetween ||
        alignment == MainAxisAlignment.spaceEvenly;

    // Use stretch for cross axis only when explicitly filling parent container
    final crossAxisAlignment =
        element.style.crossAxisAlignmentValue ?? CrossAxisAlignment.center;

    Widget row = Row(
      mainAxisSize: needsMaxSize ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: alignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );

    return row;
  }

  Widget _buildColumn(BuildContext context) {
    final spacing = element.style.spacing ?? 0;
    final children = <Widget>[];

    for (var i = 0; i < element.children.length; i++) {
      final child = element.children[i];
      Widget childWidget = _ElementRenderer(
        element: child,
        bindingEngine: bindingEngine,
        accentColor: accentColor,
        isPreview: isPreview,
        selectedElementId: selectedElementId,
        onElementTap: onElementTap,
        enableActions: enableActions,
        ref: ref,
      );

      // Wrap in Expanded if style.expanded is true
      if (child.style.expanded == true) {
        childWidget = Expanded(flex: child.style.flex ?? 1, child: childWidget);
      }

      children.add(childWidget);

      // Add spacing between children (not after last)
      if (spacing > 0 && i < element.children.length - 1) {
        children.add(SizedBox(height: spacing));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          element.style.mainAxisAlignmentValue ?? MainAxisAlignment.start,
      crossAxisAlignment:
          element.style.crossAxisAlignmentValue ?? CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildStack(BuildContext context) {
    return Stack(
      alignment: element.style.alignmentValue ?? Alignment.center,
      children: element.children.map((child) {
        return _ElementRenderer(
          element: child,
          bindingEngine: bindingEngine,
          accentColor: accentColor,
          isPreview: isPreview,
          selectedElementId: selectedElementId,
          onElementTap: onElementTap,
          enableActions: enableActions,
          ref: ref,
        );
      }).toList(),
    );
  }

  Widget _applyStyle(Widget child) {
    // Apply padding
    if (element.style.paddingInsets != null) {
      child = Padding(padding: element.style.paddingInsets!, child: child);
    }

    // Resolve colors with accent color support
    // Note: Skip backgroundColor for shapes since ShapeRenderer handles it
    final isShape = element.type == ElementType.shape;
    final bgColor = (!isShape && element.style.backgroundColor != null)
        ? StyleSchema.resolveColor(element.style.backgroundColor!, accentColor)
        : null;
    final borderColor = element.style.borderColor != null
        ? StyleSchema.resolveColor(element.style.borderColor!, accentColor)
        : null;

    // Apply container decoration with alignment
    // Note: Skip border for shapes since ShapeRenderer handles it
    final hasDecoration =
        bgColor != null ||
        (!isShape && element.style.borderWidth != null) ||
        (!isShape && element.style.borderRadius != null);
    final hasAlignment = element.style.alignmentValue != null;

    // Get size constraints - these should be applied WITH the decoration
    // so alignment works correctly within the sized container
    final hasSize =
        !isShape &&
        (element.style.width != null || element.style.height != null);

    if (hasDecoration || hasAlignment || hasSize) {
      child = Container(
        width: hasSize ? element.style.width : null,
        height: hasSize ? element.style.height : null,
        alignment: element.style.alignmentValue,
        decoration: hasDecoration
            ? BoxDecoration(
                color: bgColor,
                borderRadius: element.style.borderRadius != null
                    ? BorderRadius.circular(element.style.borderRadius!)
                    : null,
                border: element.style.borderWidth != null
                    ? Border.all(
                        color: borderColor ?? AppTheme.darkBorder,
                        width: element.style.borderWidth!,
                      )
                    : null,
              )
            : null,
        child: child,
      );
    }

    // Apply margin
    if (element.style.marginInsets != null) {
      child = Padding(padding: element.style.marginInsets!, child: child);
    }

    // Apply opacity
    if (element.style.opacity != null) {
      child = Opacity(opacity: element.style.opacity!, child: child);
    }

    return child;
  }
}

/// Custom painter for map grid background
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.darkBorder.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    const gridSize = 20.0;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wrapper widget that provides live data to WidgetRenderer
class LiveWidgetRenderer extends StatelessWidget {
  final WidgetSchema schema;
  final MeshNode? node;
  final Map<int, MeshNode>? allNodes;
  final Color accentColor;

  const LiveWidgetRenderer({
    super.key,
    required this.schema,
    this.node,
    this.allNodes,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return WidgetRenderer(
      schema: schema,
      node: node,
      allNodes: allNodes,
      accentColor: accentColor,
    );
  }
}
