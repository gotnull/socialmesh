import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Types of primitive elements available in the widget builder
enum ElementType {
  text, // Dynamic text with bindings
  icon, // Material/custom icons
  image, // Static or bound images
  gauge, // Linear/radial progress
  chart, // Sparkline, history graphs
  map, // Mini map with node position
  shape, // Rectangle, circle, dividers
  conditional, // Show/hide based on data
  container, // Layout container
  row, // Horizontal layout
  column, // Vertical layout
  spacer, // Flexible space
  stack, // Overlapping elements
  button, // Action button with tap behavior
}

/// Types of gauges available
enum GaugeType { linear, radial, arc, battery, signal }

/// Types of charts available
enum ChartType { sparkline, bar, line, area }

/// Types of shapes available
enum ShapeType {
  rectangle,
  circle,
  roundedRect,
  dividerHorizontal,
  dividerVertical,
}

/// Conditional operators for conditional elements
enum ConditionalOperator {
  equals,
  notEquals,
  greaterThan,
  lessThan,
  greaterOrEqual,
  lessOrEqual,
  isNull,
  isNotNull,
  contains,
  isEmpty,
  isNotEmpty,
}

/// Action types for tappable elements
enum ActionType {
  none, // No action
  sendMessage, // Open quick message sheet
  shareLocation, // Share current location
  traceroute, // Open traceroute sheet
  requestPositions, // Request positions from all nodes
  sos, // Open SOS confirmation
  navigate, // Navigate to a screen
  openUrl, // Open external URL
  copyToClipboard, // Copy bound value
}

/// Text alignment options
enum TextAlignOption { left, center, right, justify }

/// Alignment options for containers
enum AlignmentOption {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// Main axis alignment for Row/Column
enum MainAxisAlignmentOption {
  start,
  end,
  center,
  spaceBetween,
  spaceAround,
  spaceEvenly,
}

/// Cross axis alignment for Row/Column
enum CrossAxisAlignmentOption { start, end, center, stretch, baseline }

/// Style configuration for an element
class StyleSchema {
  final double? width;
  final double? height;
  final double? padding;
  final double? paddingLeft;
  final double? paddingRight;
  final double? paddingTop;
  final double? paddingBottom;
  final double? margin;
  final double? marginLeft;
  final double? marginRight;
  final double? marginTop;
  final double? marginBottom;
  final String? backgroundColor; // Hex color
  final String? borderColor;
  final double? borderWidth;
  final double? borderRadius;
  final String? textColor;
  final double? fontSize;
  final String? fontWeight; // normal, bold, w100-w900
  final TextAlignOption? textAlign;
  final AlignmentOption? alignment;
  final MainAxisAlignmentOption? mainAxisAlignment;
  final CrossAxisAlignmentOption? crossAxisAlignment;
  final double? opacity;
  final bool? expanded; // For flexible children
  final int? flex; // Flex factor
  final double? spacing; // For Row/Column spacing

  const StyleSchema({
    this.width,
    this.height,
    this.padding,
    this.paddingLeft,
    this.paddingRight,
    this.paddingTop,
    this.paddingBottom,
    this.margin,
    this.marginLeft,
    this.marginRight,
    this.marginTop,
    this.marginBottom,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.textColor,
    this.fontSize,
    this.fontWeight,
    this.textAlign,
    this.alignment,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.opacity,
    this.expanded,
    this.flex,
    this.spacing,
  });

  /// Convert Flutter Alignment to AlignmentOption
  static AlignmentOption? alignmentToOption(Alignment? alignment) {
    if (alignment == null) return null;
    if (alignment == Alignment.topLeft) return AlignmentOption.topLeft;
    if (alignment == Alignment.topCenter) return AlignmentOption.topCenter;
    if (alignment == Alignment.topRight) return AlignmentOption.topRight;
    if (alignment == Alignment.centerLeft) return AlignmentOption.centerLeft;
    if (alignment == Alignment.center) return AlignmentOption.center;
    if (alignment == Alignment.centerRight) return AlignmentOption.centerRight;
    if (alignment == Alignment.bottomLeft) return AlignmentOption.bottomLeft;
    if (alignment == Alignment.bottomCenter) {
      return AlignmentOption.bottomCenter;
    }
    if (alignment == Alignment.bottomRight) return AlignmentOption.bottomRight;
    return AlignmentOption.center;
  }

  /// Convert AlignmentOption to Flutter Alignment
  Alignment? get alignmentValue {
    switch (alignment) {
      case AlignmentOption.topLeft:
        return Alignment.topLeft;
      case AlignmentOption.topCenter:
        return Alignment.topCenter;
      case AlignmentOption.topRight:
        return Alignment.topRight;
      case AlignmentOption.centerLeft:
        return Alignment.centerLeft;
      case AlignmentOption.center:
        return Alignment.center;
      case AlignmentOption.centerRight:
        return Alignment.centerRight;
      case AlignmentOption.bottomLeft:
        return Alignment.bottomLeft;
      case AlignmentOption.bottomCenter:
        return Alignment.bottomCenter;
      case AlignmentOption.bottomRight:
        return Alignment.bottomRight;
      case null:
        return null;
    }
  }

  MainAxisAlignment? get mainAxisAlignmentValue {
    switch (mainAxisAlignment) {
      case MainAxisAlignmentOption.start:
        return MainAxisAlignment.start;
      case MainAxisAlignmentOption.end:
        return MainAxisAlignment.end;
      case MainAxisAlignmentOption.center:
        return MainAxisAlignment.center;
      case MainAxisAlignmentOption.spaceBetween:
        return MainAxisAlignment.spaceBetween;
      case MainAxisAlignmentOption.spaceAround:
        return MainAxisAlignment.spaceAround;
      case MainAxisAlignmentOption.spaceEvenly:
        return MainAxisAlignment.spaceEvenly;
      case null:
        return null;
    }
  }

  CrossAxisAlignment? get crossAxisAlignmentValue {
    switch (crossAxisAlignment) {
      case CrossAxisAlignmentOption.start:
        return CrossAxisAlignment.start;
      case CrossAxisAlignmentOption.end:
        return CrossAxisAlignment.end;
      case CrossAxisAlignmentOption.center:
        return CrossAxisAlignment.center;
      case CrossAxisAlignmentOption.stretch:
        return CrossAxisAlignment.stretch;
      case CrossAxisAlignmentOption.baseline:
        return CrossAxisAlignment.baseline;
      case null:
        return null;
    }
  }

  TextAlign? get textAlignValue {
    switch (textAlign) {
      case TextAlignOption.left:
        return TextAlign.left;
      case TextAlignOption.center:
        return TextAlign.center;
      case TextAlignOption.right:
        return TextAlign.right;
      case TextAlignOption.justify:
        return TextAlign.justify;
      case null:
        return null;
    }
  }

  FontWeight? get fontWeightValue {
    switch (fontWeight) {
      case 'normal':
        return FontWeight.normal;
      case 'bold':
        return FontWeight.bold;
      case 'w100':
        return FontWeight.w100;
      case 'w200':
        return FontWeight.w200;
      case 'w300':
        return FontWeight.w300;
      case 'w400':
        return FontWeight.w400;
      case 'w500':
        return FontWeight.w500;
      case 'w600':
        return FontWeight.w600;
      case 'w700':
        return FontWeight.w700;
      case 'w800':
        return FontWeight.w800;
      case 'w900':
        return FontWeight.w900;
      default:
        return null;
    }
  }

  Color? get backgroundColorValue =>
      backgroundColor != null ? parseColor(backgroundColor!) : null;
  Color? get borderColorValue =>
      borderColor != null ? parseColor(borderColor!) : null;
  Color? get textColorValue =>
      textColor != null ? parseColor(textColor!) : null;

  /// Parses a hex color string to a Color
  static Color parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  EdgeInsets? get paddingInsets {
    if (padding != null) return EdgeInsets.all(padding!);
    if (paddingLeft != null ||
        paddingRight != null ||
        paddingTop != null ||
        paddingBottom != null) {
      return EdgeInsets.only(
        left: paddingLeft ?? 0,
        right: paddingRight ?? 0,
        top: paddingTop ?? 0,
        bottom: paddingBottom ?? 0,
      );
    }
    return null;
  }

  EdgeInsets? get marginInsets {
    if (margin != null) return EdgeInsets.all(margin!);
    if (marginLeft != null ||
        marginRight != null ||
        marginTop != null ||
        marginBottom != null) {
      return EdgeInsets.only(
        left: marginLeft ?? 0,
        right: marginRight ?? 0,
        top: marginTop ?? 0,
        bottom: marginBottom ?? 0,
      );
    }
    return null;
  }

  StyleSchema copyWith({
    double? width,
    double? height,
    double? padding,
    double? paddingLeft,
    double? paddingRight,
    double? paddingTop,
    double? paddingBottom,
    double? margin,
    double? marginLeft,
    double? marginRight,
    double? marginTop,
    double? marginBottom,
    String? backgroundColor,
    String? borderColor,
    double? borderWidth,
    double? borderRadius,
    String? textColor,
    double? fontSize,
    String? fontWeight,
    TextAlignOption? textAlign,
    AlignmentOption? alignment,
    MainAxisAlignmentOption? mainAxisAlignment,
    CrossAxisAlignmentOption? crossAxisAlignment,
    double? opacity,
    bool? expanded,
    int? flex,
    double? spacing,
  }) {
    return StyleSchema(
      width: width ?? this.width,
      height: height ?? this.height,
      padding: padding ?? this.padding,
      paddingLeft: paddingLeft ?? this.paddingLeft,
      paddingRight: paddingRight ?? this.paddingRight,
      paddingTop: paddingTop ?? this.paddingTop,
      paddingBottom: paddingBottom ?? this.paddingBottom,
      margin: margin ?? this.margin,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      textColor: textColor ?? this.textColor,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      textAlign: textAlign ?? this.textAlign,
      alignment: alignment ?? this.alignment,
      mainAxisAlignment: mainAxisAlignment ?? this.mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment ?? this.crossAxisAlignment,
      opacity: opacity ?? this.opacity,
      expanded: expanded ?? this.expanded,
      flex: flex ?? this.flex,
      spacing: spacing ?? this.spacing,
    );
  }

  Map<String, dynamic> toJson() => {
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (padding != null) 'padding': padding,
    if (paddingLeft != null) 'paddingLeft': paddingLeft,
    if (paddingRight != null) 'paddingRight': paddingRight,
    if (paddingTop != null) 'paddingTop': paddingTop,
    if (paddingBottom != null) 'paddingBottom': paddingBottom,
    if (margin != null) 'margin': margin,
    if (marginLeft != null) 'marginLeft': marginLeft,
    if (marginRight != null) 'marginRight': marginRight,
    if (marginTop != null) 'marginTop': marginTop,
    if (marginBottom != null) 'marginBottom': marginBottom,
    if (backgroundColor != null) 'backgroundColor': backgroundColor,
    if (borderColor != null) 'borderColor': borderColor,
    if (borderWidth != null) 'borderWidth': borderWidth,
    if (borderRadius != null) 'borderRadius': borderRadius,
    if (textColor != null) 'textColor': textColor,
    if (fontSize != null) 'fontSize': fontSize,
    if (fontWeight != null) 'fontWeight': fontWeight,
    if (textAlign != null) 'textAlign': textAlign!.name,
    if (alignment != null) 'alignment': alignment!.name,
    if (mainAxisAlignment != null) 'mainAxisAlignment': mainAxisAlignment!.name,
    if (crossAxisAlignment != null)
      'crossAxisAlignment': crossAxisAlignment!.name,
    if (opacity != null) 'opacity': opacity,
    if (expanded != null) 'expanded': expanded,
    if (flex != null) 'flex': flex,
    if (spacing != null) 'spacing': spacing,
  };

  factory StyleSchema.fromJson(Map<String, dynamic> json) {
    return StyleSchema(
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      padding: (json['padding'] as num?)?.toDouble(),
      paddingLeft: (json['paddingLeft'] as num?)?.toDouble(),
      paddingRight: (json['paddingRight'] as num?)?.toDouble(),
      paddingTop: (json['paddingTop'] as num?)?.toDouble(),
      paddingBottom: (json['paddingBottom'] as num?)?.toDouble(),
      margin: (json['margin'] as num?)?.toDouble(),
      marginLeft: (json['marginLeft'] as num?)?.toDouble(),
      marginRight: (json['marginRight'] as num?)?.toDouble(),
      marginTop: (json['marginTop'] as num?)?.toDouble(),
      marginBottom: (json['marginBottom'] as num?)?.toDouble(),
      backgroundColor: json['backgroundColor'] as String?,
      borderColor: json['borderColor'] as String?,
      borderWidth: (json['borderWidth'] as num?)?.toDouble(),
      borderRadius: (json['borderRadius'] as num?)?.toDouble(),
      textColor: json['textColor'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      fontWeight: json['fontWeight'] as String?,
      textAlign: json['textAlign'] != null
          ? TextAlignOption.values.firstWhere(
              (e) => e.name == json['textAlign'],
              orElse: () => TextAlignOption.left,
            )
          : null,
      alignment: json['alignment'] != null
          ? AlignmentOption.values.firstWhere(
              (e) => e.name == json['alignment'],
              orElse: () => AlignmentOption.center,
            )
          : null,
      mainAxisAlignment: json['mainAxisAlignment'] != null
          ? MainAxisAlignmentOption.values.firstWhere(
              (e) => e.name == json['mainAxisAlignment'],
              orElse: () => MainAxisAlignmentOption.start,
            )
          : null,
      crossAxisAlignment: json['crossAxisAlignment'] != null
          ? CrossAxisAlignmentOption.values.firstWhere(
              (e) => e.name == json['crossAxisAlignment'],
              orElse: () => CrossAxisAlignmentOption.center,
            )
          : null,
      opacity: (json['opacity'] as num?)?.toDouble(),
      expanded: json['expanded'] as bool?,
      flex: json['flex'] as int?,
      spacing: (json['spacing'] as num?)?.toDouble(),
    );
  }
}

/// Data binding configuration
class BindingSchema {
  final String path; // e.g., "node.batteryLevel", "node.temperature"
  final String? format; // Format string, e.g., "{value}%", "{value}°C"
  final String? defaultValue; // Fallback when data is null
  final String?
  transform; // Optional transform: "round", "floor", "ceil", "uppercase", "lowercase"

  const BindingSchema({
    required this.path,
    this.format,
    this.defaultValue,
    this.transform,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    if (format != null) 'format': format,
    if (defaultValue != null) 'defaultValue': defaultValue,
    if (transform != null) 'transform': transform,
  };

  factory BindingSchema.fromJson(Map<String, dynamic> json) {
    return BindingSchema(
      path: json['path'] as String,
      format: json['format'] as String?,
      defaultValue: json['defaultValue'] as String?,
      transform: json['transform'] as String?,
    );
  }
}

/// Action configuration for tappable elements
class ActionSchema {
  final ActionType type;
  final String? navigateTo; // Screen/route name for navigate action
  final String? url; // URL for openUrl action
  final bool? requiresNodeSelection; // Whether to show node picker first
  final bool? requiresChannelSelection; // Whether to show channel picker first
  final String? label; // Button label override

  const ActionSchema({
    required this.type,
    this.navigateTo,
    this.url,
    this.requiresNodeSelection,
    this.requiresChannelSelection,
    this.label,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    if (navigateTo != null) 'navigateTo': navigateTo,
    if (url != null) 'url': url,
    if (requiresNodeSelection != null)
      'requiresNodeSelection': requiresNodeSelection,
    if (requiresChannelSelection != null)
      'requiresChannelSelection': requiresChannelSelection,
    if (label != null) 'label': label,
  };

  factory ActionSchema.fromJson(Map<String, dynamic> json) {
    return ActionSchema(
      type: ActionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ActionType.none,
      ),
      navigateTo: json['navigateTo'] as String?,
      url: json['url'] as String?,
      requiresNodeSelection: json['requiresNodeSelection'] as bool?,
      requiresChannelSelection: json['requiresChannelSelection'] as bool?,
      label: json['label'] as String?,
    );
  }
}

/// Conditional configuration for conditional elements
class ConditionalSchema {
  final String bindingPath; // Data path to evaluate
  final ConditionalOperator operator;
  final dynamic value; // Value to compare against

  const ConditionalSchema({
    required this.bindingPath,
    required this.operator,
    this.value,
  });

  Map<String, dynamic> toJson() => {
    'bindingPath': bindingPath,
    'operator': operator.name,
    if (value != null) 'value': value,
  };

  factory ConditionalSchema.fromJson(Map<String, dynamic> json) {
    return ConditionalSchema(
      bindingPath: json['bindingPath'] as String,
      operator: ConditionalOperator.values.firstWhere(
        (e) => e.name == json['operator'],
        orElse: () => ConditionalOperator.isNotNull,
      ),
      value: json['value'],
    );
  }
}

/// Element schema - defines a single primitive element
class ElementSchema {
  final String id;
  final ElementType type;
  final StyleSchema style;
  final BindingSchema? binding;
  final ConditionalSchema? condition;
  final ActionSchema? action; // Tap action for this element
  final List<ElementSchema> children;

  // Type-specific properties
  final String? text; // For text elements
  final String? iconName; // For icon elements (Material icon name)
  final double? iconSize;
  final String? imageUrl; // For image elements
  final String? imageAsset; // For local asset images
  final GaugeType? gaugeType; // For gauge elements
  final double? gaugeMin;
  final double? gaugeMax;
  final String? gaugeColor;
  final String? gaugeBackgroundColor;
  final ChartType? chartType; // For chart elements
  final String? chartBindingPath; // Data source for chart
  final int? chartMaxPoints; // Max data points to display
  final ShapeType? shapeType; // For shape elements
  final String? shapeColor;

  ElementSchema({
    String? id,
    required this.type,
    this.style = const StyleSchema(),
    this.binding,
    this.condition,
    this.action,
    this.children = const [],
    this.text,
    this.iconName,
    this.iconSize,
    this.imageUrl,
    this.imageAsset,
    this.gaugeType,
    this.gaugeMin,
    this.gaugeMax,
    this.gaugeColor,
    this.gaugeBackgroundColor,
    this.chartType,
    this.chartBindingPath,
    this.chartMaxPoints,
    this.shapeType,
    this.shapeColor,
  }) : id = id ?? const Uuid().v4();

  ElementSchema copyWith({
    String? id,
    ElementType? type,
    StyleSchema? style,
    BindingSchema? binding,
    ConditionalSchema? condition,
    ActionSchema? action,
    List<ElementSchema>? children,
    String? text,
    String? iconName,
    double? iconSize,
    String? imageUrl,
    String? imageAsset,
    GaugeType? gaugeType,
    double? gaugeMin,
    double? gaugeMax,
    String? gaugeColor,
    String? gaugeBackgroundColor,
    ChartType? chartType,
    String? chartBindingPath,
    int? chartMaxPoints,
    ShapeType? shapeType,
    String? shapeColor,
  }) {
    return ElementSchema(
      id: id ?? this.id,
      type: type ?? this.type,
      style: style ?? this.style,
      binding: binding ?? this.binding,
      condition: condition ?? this.condition,
      action: action ?? this.action,
      children: children ?? this.children,
      text: text ?? this.text,
      iconName: iconName ?? this.iconName,
      iconSize: iconSize ?? this.iconSize,
      imageUrl: imageUrl ?? this.imageUrl,
      imageAsset: imageAsset ?? this.imageAsset,
      gaugeType: gaugeType ?? this.gaugeType,
      gaugeMin: gaugeMin ?? this.gaugeMin,
      gaugeMax: gaugeMax ?? this.gaugeMax,
      gaugeColor: gaugeColor ?? this.gaugeColor,
      gaugeBackgroundColor: gaugeBackgroundColor ?? this.gaugeBackgroundColor,
      chartType: chartType ?? this.chartType,
      chartBindingPath: chartBindingPath ?? this.chartBindingPath,
      chartMaxPoints: chartMaxPoints ?? this.chartMaxPoints,
      shapeType: shapeType ?? this.shapeType,
      shapeColor: shapeColor ?? this.shapeColor,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'style': style.toJson(),
    if (binding != null) 'binding': binding!.toJson(),
    if (condition != null) 'condition': condition!.toJson(),
    if (action != null) 'action': action!.toJson(),
    if (children.isNotEmpty)
      'children': children.map((c) => c.toJson()).toList(),
    if (text != null) 'text': text,
    if (iconName != null) 'iconName': iconName,
    if (iconSize != null) 'iconSize': iconSize,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (imageAsset != null) 'imageAsset': imageAsset,
    if (gaugeType != null) 'gaugeType': gaugeType!.name,
    if (gaugeMin != null) 'gaugeMin': gaugeMin,
    if (gaugeMax != null) 'gaugeMax': gaugeMax,
    if (gaugeColor != null) 'gaugeColor': gaugeColor,
    if (gaugeBackgroundColor != null)
      'gaugeBackgroundColor': gaugeBackgroundColor,
    if (chartType != null) 'chartType': chartType!.name,
    if (chartBindingPath != null) 'chartBindingPath': chartBindingPath,
    if (chartMaxPoints != null) 'chartMaxPoints': chartMaxPoints,
    if (shapeType != null) 'shapeType': shapeType!.name,
    if (shapeColor != null) 'shapeColor': shapeColor,
  };

  factory ElementSchema.fromJson(Map<String, dynamic> json) {
    return ElementSchema(
      id: json['id'] as String?,
      type: ElementType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ElementType.text,
      ),
      style: json['style'] != null
          ? StyleSchema.fromJson(json['style'] as Map<String, dynamic>)
          : const StyleSchema(),
      binding: json['binding'] != null
          ? BindingSchema.fromJson(json['binding'] as Map<String, dynamic>)
          : null,
      condition: json['condition'] != null
          ? ConditionalSchema.fromJson(
              json['condition'] as Map<String, dynamic>,
            )
          : null,
      action: json['action'] != null
          ? ActionSchema.fromJson(json['action'] as Map<String, dynamic>)
          : null,
      children:
          (json['children'] as List<dynamic>?)
              ?.map((c) => ElementSchema.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      text: json['text'] as String?,
      iconName: json['iconName'] as String?,
      iconSize: (json['iconSize'] as num?)?.toDouble(),
      imageUrl: json['imageUrl'] as String?,
      imageAsset: json['imageAsset'] as String?,
      gaugeType: json['gaugeType'] != null
          ? GaugeType.values.firstWhere(
              (e) => e.name == json['gaugeType'],
              orElse: () => GaugeType.linear,
            )
          : null,
      gaugeMin: (json['gaugeMin'] as num?)?.toDouble(),
      gaugeMax: (json['gaugeMax'] as num?)?.toDouble(),
      gaugeColor: json['gaugeColor'] as String?,
      gaugeBackgroundColor: json['gaugeBackgroundColor'] as String?,
      chartType: json['chartType'] != null
          ? ChartType.values.firstWhere(
              (e) => e.name == json['chartType'],
              orElse: () => ChartType.sparkline,
            )
          : null,
      chartBindingPath: json['chartBindingPath'] as String?,
      chartMaxPoints: json['chartMaxPoints'] as int?,
      shapeType: json['shapeType'] != null
          ? ShapeType.values.firstWhere(
              (e) => e.name == json['shapeType'],
              orElse: () => ShapeType.rectangle,
            )
          : null,
      shapeColor: json['shapeColor'] as String?,
    );
  }
}

/// Widget size category for grid layout
enum CustomWidgetSize {
  small, // 1x1
  medium, // 2x1
  large, // 2x2
  custom, // User-defined size
}

/// Complete widget schema - the root definition
class WidgetSchema {
  final String id;
  final String name;
  final String? description;
  final String? author;
  final String version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CustomWidgetSize size;
  final double? customWidth;
  final double? customHeight;
  final ElementSchema root;
  final List<String> tags;
  final String? thumbnailUrl;
  final bool isPublic;
  final int? downloadCount;
  final double? rating;

  WidgetSchema({
    String? id,
    required this.name,
    this.description,
    this.author,
    this.version = '1.0.0',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.size = CustomWidgetSize.medium,
    this.customWidth,
    this.customHeight,
    required this.root,
    this.tags = const [],
    this.thumbnailUrl,
    this.isPublic = false,
    this.downloadCount,
    this.rating,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Get the effective width based on size preset or custom value
  double get effectiveWidth {
    if (size == CustomWidgetSize.custom && customWidth != null) {
      return customWidth!;
    }
    switch (size) {
      case CustomWidgetSize.small:
        return 160;
      case CustomWidgetSize.medium:
        return 320;
      case CustomWidgetSize.large:
        return 320;
      case CustomWidgetSize.custom:
        return customWidth ?? 320;
    }
  }

  /// Get the effective height based on size preset or custom value
  double get effectiveHeight {
    if (size == CustomWidgetSize.custom && customHeight != null) {
      return customHeight!;
    }
    switch (size) {
      case CustomWidgetSize.small:
        return 160;
      case CustomWidgetSize.medium:
        return 160;
      case CustomWidgetSize.large:
        return 320;
      case CustomWidgetSize.custom:
        return customHeight ?? 160;
    }
  }

  WidgetSchema copyWith({
    String? id,
    String? name,
    String? description,
    String? author,
    String? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    CustomWidgetSize? size,
    double? customWidth,
    double? customHeight,
    ElementSchema? root,
    List<String>? tags,
    String? thumbnailUrl,
    bool? isPublic,
    int? downloadCount,
    double? rating,
  }) {
    return WidgetSchema(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      author: author ?? this.author,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      size: size ?? this.size,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      root: root ?? this.root,
      tags: tags ?? this.tags,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isPublic: isPublic ?? this.isPublic,
      downloadCount: downloadCount ?? this.downloadCount,
      rating: rating ?? this.rating,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    if (author != null) 'author': author,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'size': size.name,
    if (customWidth != null) 'customWidth': customWidth,
    if (customHeight != null) 'customHeight': customHeight,
    'root': root.toJson(),
    'tags': tags,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    'isPublic': isPublic,
    if (downloadCount != null) 'downloadCount': downloadCount,
    if (rating != null) 'rating': rating,
  };

  factory WidgetSchema.fromJson(Map<String, dynamic> json) {
    return WidgetSchema(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      author: json['author'] as String?,
      version: json['version'] as String? ?? '1.0.0',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      size: CustomWidgetSize.values.firstWhere(
        (e) => e.name == json['size'],
        orElse: () => CustomWidgetSize.medium,
      ),
      customWidth: (json['customWidth'] as num?)?.toDouble(),
      customHeight: (json['customHeight'] as num?)?.toDouble(),
      root: ElementSchema.fromJson(json['root'] as Map<String, dynamic>),
      tags:
          (json['tags'] as List<dynamic>?)?.map((t) => t as String).toList() ??
          [],
      thumbnailUrl: json['thumbnailUrl'] as String?,
      isPublic: json['isPublic'] as bool? ?? false,
      downloadCount: json['downloadCount'] as int?,
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }

  /// Convert to pretty-printed JSON string for export
  String toJsonString() {
    final encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}

/// JSON encoder for pretty printing
class JsonEncoder {
  final String? indent;

  const JsonEncoder.withIndent(this.indent);

  String convert(Map<String, dynamic> json) {
    return _encode(json, 0);
  }

  String _encode(dynamic value, int depth) {
    final spaces = indent != null ? indent! * depth : '';
    final nextSpaces = indent != null ? indent! * (depth + 1) : '';

    if (value == null) return 'null';
    if (value is bool) return value.toString();
    if (value is num) return value.toString();
    if (value is String) return '"${_escapeString(value)}"';

    if (value is List) {
      if (value.isEmpty) return '[]';
      final items = value.map((v) => '$nextSpaces${_encode(v, depth + 1)}');
      return '[\n${items.join(',\n')}\n$spaces]';
    }

    if (value is Map<String, dynamic>) {
      if (value.isEmpty) return '{}';
      final entries = value.entries.map(
        (e) => '$nextSpaces"${e.key}": ${_encode(e.value, depth + 1)}',
      );
      return '{\n${entries.join(',\n')}\n$spaces}';
    }

    return value.toString();
  }

  String _escapeString(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }
}
