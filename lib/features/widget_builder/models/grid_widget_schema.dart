import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Simplified element types for grid-based widget builder
enum GridElementType {
  text, // Dynamic text with bindings
  icon, // Material icons
  iconText, // Icon + text horizontal layout
  gauge, // Circular/linear progress indicator
  chart, // Sparkline/bar chart for data
  button, // Action button with tap behavior
}

extension GridElementTypeExt on GridElementType {
  String get displayName {
    switch (this) {
      case GridElementType.text:
        return 'Text';
      case GridElementType.icon:
        return 'Icon';
      case GridElementType.iconText:
        return 'Icon + Text';
      case GridElementType.gauge:
        return 'Gauge';
      case GridElementType.chart:
        return 'Chart';
      case GridElementType.button:
        return 'Button';
    }
  }
}

/// Types of gauges available
enum GaugeStyle {
  circular, // Full circle
  arc, // Semi-circle arc
  linear, // Horizontal bar
  battery, // Battery-style vertical
  signal, // Signal strength bars
}

/// Types of charts available
enum ChartStyle {
  sparkline, // Simple line
  bar, // Vertical bars
  area, // Filled area under line
}

/// Horizontal alignment options for elements
enum ElementAlignment { left, center, right }

extension ElementAlignmentExt on ElementAlignment {
  String get displayName {
    switch (this) {
      case ElementAlignment.left:
        return 'Left';
      case ElementAlignment.center:
        return 'Center';
      case ElementAlignment.right:
        return 'Right';
    }
  }

  MainAxisAlignment get mainAxisAlignment {
    switch (this) {
      case ElementAlignment.left:
        return MainAxisAlignment.start;
      case ElementAlignment.center:
        return MainAxisAlignment.center;
      case ElementAlignment.right:
        return MainAxisAlignment.end;
    }
  }

  CrossAxisAlignment get crossAxisAlignment {
    switch (this) {
      case ElementAlignment.left:
        return CrossAxisAlignment.start;
      case ElementAlignment.center:
        return CrossAxisAlignment.center;
      case ElementAlignment.right:
        return CrossAxisAlignment.end;
    }
  }
}

/// Action types for tappable elements
enum GridActionType {
  none,
  sendMessage,
  shareLocation,
  traceroute,
  requestPositions,
  sos,
  navigate,
  openUrl,
  copyToClipboard,
}

/// Data binding configuration
class GridBinding {
  final String path; // e.g., "node.batteryLevel"
  final String? format; // e.g., "{value}%"
  final String? fallback; // Default when null

  const GridBinding({required this.path, this.format, this.fallback});

  Map<String, dynamic> toJson() => {
    'path': path,
    if (format != null) 'format': format,
    if (fallback != null) 'fallback': fallback,
  };

  factory GridBinding.fromJson(Map<String, dynamic> json) {
    return GridBinding(
      path: json['path'] as String,
      format: json['format'] as String?,
      fallback: json['fallback'] as String?,
    );
  }
}

/// Action configuration
class GridAction {
  final GridActionType type;
  final String? navigateTo;
  final String? url;
  final String? label;

  const GridAction({required this.type, this.navigateTo, this.url, this.label});

  Map<String, dynamic> toJson() => {
    'type': type.name,
    if (navigateTo != null) 'navigateTo': navigateTo,
    if (url != null) 'url': url,
    if (label != null) 'label': label,
  };

  factory GridAction.fromJson(Map<String, dynamic> json) {
    return GridAction(
      type: GridActionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GridActionType.none,
      ),
      navigateTo: json['navigateTo'] as String?,
      url: json['url'] as String?,
      label: json['label'] as String?,
    );
  }
}

/// A single element positioned in the grid
class GridElement {
  final String id;
  final GridElementType type;

  // Grid position (0-based)
  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;

  // Common properties
  final GridBinding? binding;
  final GridAction? action;
  final ElementAlignment? alignment;

  // Text-specific
  final String? text;
  final double? fontSize;
  final Color? textColor;
  final FontWeight? fontWeight;

  // Icon-specific
  final String? iconName;
  final double? iconSize;
  final Color? iconColor;

  // Gauge-specific
  final GaugeStyle? gaugeStyle;
  final double? gaugeMin;
  final double? gaugeMax;
  final Color? gaugeColor;

  // Chart-specific
  final ChartStyle? chartStyle;
  final int? chartMaxPoints;
  final Color? chartColor;

  GridElement({
    String? id,
    required this.type,
    required this.row,
    required this.column,
    this.rowSpan = 1,
    this.columnSpan = 1,
    this.binding,
    this.action,
    this.alignment,
    this.text,
    this.fontSize,
    this.textColor,
    this.fontWeight,
    this.iconName,
    this.iconSize,
    this.iconColor,
    this.gaugeStyle,
    this.gaugeMin,
    this.gaugeMax,
    this.gaugeColor,
    this.chartStyle,
    this.chartMaxPoints,
    this.chartColor,
  }) : id = id ?? const Uuid().v4();

  GridElement copyWith({
    String? id,
    GridElementType? type,
    int? row,
    int? column,
    int? rowSpan,
    int? columnSpan,
    GridBinding? binding,
    GridAction? action,
    ElementAlignment? alignment,
    String? text,
    double? fontSize,
    Color? textColor,
    FontWeight? fontWeight,
    String? iconName,
    double? iconSize,
    Color? iconColor,
    GaugeStyle? gaugeStyle,
    double? gaugeMin,
    double? gaugeMax,
    Color? gaugeColor,
    ChartStyle? chartStyle,
    int? chartMaxPoints,
    Color? chartColor,
  }) {
    return GridElement(
      id: id ?? this.id,
      type: type ?? this.type,
      row: row ?? this.row,
      column: column ?? this.column,
      rowSpan: rowSpan ?? this.rowSpan,
      columnSpan: columnSpan ?? this.columnSpan,
      binding: binding ?? this.binding,
      action: action ?? this.action,
      alignment: alignment ?? this.alignment,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      fontWeight: fontWeight ?? this.fontWeight,
      iconName: iconName ?? this.iconName,
      iconSize: iconSize ?? this.iconSize,
      iconColor: iconColor ?? this.iconColor,
      gaugeStyle: gaugeStyle ?? this.gaugeStyle,
      gaugeMin: gaugeMin ?? this.gaugeMin,
      gaugeMax: gaugeMax ?? this.gaugeMax,
      gaugeColor: gaugeColor ?? this.gaugeColor,
      chartStyle: chartStyle ?? this.chartStyle,
      chartMaxPoints: chartMaxPoints ?? this.chartMaxPoints,
      chartColor: chartColor ?? this.chartColor,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'row': row,
    'column': column,
    if (rowSpan != 1) 'rowSpan': rowSpan,
    if (columnSpan != 1) 'columnSpan': columnSpan,
    if (binding != null) 'binding': binding!.toJson(),
    if (action != null) 'action': action!.toJson(),
    if (alignment != null) 'alignment': alignment!.name,
    if (text != null) 'text': text,
    if (fontSize != null) 'fontSize': fontSize,
    if (textColor != null) 'textColor': textColor!.toHex(),
    if (fontWeight != null) 'fontWeight': fontWeight!.index,
    if (iconName != null) 'iconName': iconName,
    if (iconSize != null) 'iconSize': iconSize,
    if (iconColor != null) 'iconColor': iconColor!.toHex(),
    if (gaugeStyle != null) 'gaugeStyle': gaugeStyle!.name,
    if (gaugeMin != null) 'gaugeMin': gaugeMin,
    if (gaugeMax != null) 'gaugeMax': gaugeMax,
    if (gaugeColor != null) 'gaugeColor': gaugeColor!.toHex(),
    if (chartStyle != null) 'chartStyle': chartStyle!.name,
    if (chartMaxPoints != null) 'chartMaxPoints': chartMaxPoints,
    if (chartColor != null) 'chartColor': chartColor!.toHex(),
  };

  factory GridElement.fromJson(Map<String, dynamic> json) {
    return GridElement(
      id: json['id'] as String?,
      type: GridElementType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GridElementType.text,
      ),
      row: json['row'] as int,
      column: json['column'] as int,
      rowSpan: json['rowSpan'] as int? ?? 1,
      columnSpan: json['columnSpan'] as int? ?? 1,
      binding: json['binding'] != null
          ? GridBinding.fromJson(json['binding'] as Map<String, dynamic>)
          : null,
      action: json['action'] != null
          ? GridAction.fromJson(json['action'] as Map<String, dynamic>)
          : null,
      alignment: json['alignment'] != null
          ? ElementAlignment.values.firstWhere(
              (e) => e.name == json['alignment'],
              orElse: () => ElementAlignment.left,
            )
          : null,
      text: json['text'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      textColor: json['textColor'] != null
          ? _colorFromHex(json['textColor'] as String)
          : null,
      fontWeight: json['fontWeight'] != null
          ? FontWeight.values[json['fontWeight'] as int]
          : null,
      iconName: json['iconName'] as String?,
      iconSize: (json['iconSize'] as num?)?.toDouble(),
      iconColor: json['iconColor'] != null
          ? _colorFromHex(json['iconColor'] as String)
          : null,
      gaugeStyle: json['gaugeStyle'] != null
          ? GaugeStyle.values.firstWhere(
              (e) => e.name == json['gaugeStyle'],
              orElse: () => GaugeStyle.circular,
            )
          : null,
      gaugeMin: (json['gaugeMin'] as num?)?.toDouble(),
      gaugeMax: (json['gaugeMax'] as num?)?.toDouble(),
      gaugeColor: json['gaugeColor'] != null
          ? _colorFromHex(json['gaugeColor'] as String)
          : null,
      chartStyle: json['chartStyle'] != null
          ? ChartStyle.values.firstWhere(
              (e) => e.name == json['chartStyle'],
              orElse: () => ChartStyle.sparkline,
            )
          : null,
      chartMaxPoints: json['chartMaxPoints'] as int?,
      chartColor: json['chartColor'] != null
          ? _colorFromHex(json['chartColor'] as String)
          : null,
    );
  }

  static Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

/// Widget size presets
enum GridWidgetSize {
  small, // 2x2 grid, 160x160
  medium, // 3x2 grid, 240x160
  large, // 3x3 grid, 240x240
}

extension GridWidgetSizeExt on GridWidgetSize {
  String get label {
    switch (this) {
      case GridWidgetSize.small:
        return 'S';
      case GridWidgetSize.medium:
        return 'M';
      case GridWidgetSize.large:
        return 'L';
    }
  }

  int get rows {
    switch (this) {
      case GridWidgetSize.small:
        return 2;
      case GridWidgetSize.medium:
        return 2;
      case GridWidgetSize.large:
        return 3;
    }
  }

  int get columns {
    switch (this) {
      case GridWidgetSize.small:
        return 2;
      case GridWidgetSize.medium:
        return 3;
      case GridWidgetSize.large:
        return 3;
    }
  }
}

/// Extension to convert Color to hex string
extension ColorToHex on Color {
  String toHex() {
    final argb = toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

/// Complete grid-based widget definition
class GridWidgetSchema {
  final String id;
  final String name;
  final String? description;
  final GridWidgetSize size;
  final int gridRows;
  final int gridColumns;
  final List<GridElement> elements;
  final String? backgroundColor;
  final double? customWidth;
  final double? customHeight;
  final DateTime createdAt;
  final DateTime updatedAt;

  GridWidgetSchema({
    String? id,
    required this.name,
    this.description,
    this.size = GridWidgetSize.medium,
    int? gridRows,
    int? gridColumns,
    this.elements = const [],
    this.backgroundColor,
    this.customWidth,
    this.customHeight,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       gridRows = gridRows ?? size.rows,
       gridColumns = gridColumns ?? size.columns,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Get pixel dimensions based on size (or custom)
  double get width =>
      customWidth ??
      switch (size) {
        GridWidgetSize.small => 160,
        GridWidgetSize.medium => 240,
        GridWidgetSize.large => 240,
      };

  double get height =>
      customHeight ??
      switch (size) {
        GridWidgetSize.small => 160,
        GridWidgetSize.medium => 160,
        GridWidgetSize.large => 240,
      };

  /// Check if a grid cell is occupied
  bool isCellOccupied(int row, int col) {
    for (final element in elements) {
      if (row >= element.row &&
          row < element.row + element.rowSpan &&
          col >= element.column &&
          col < element.column + element.columnSpan) {
        return true;
      }
    }
    return false;
  }

  /// Get element at a specific cell (if any)
  GridElement? elementAt(int row, int col) {
    for (final element in elements) {
      if (row >= element.row &&
          row < element.row + element.rowSpan &&
          col >= element.column &&
          col < element.column + element.columnSpan) {
        return element;
      }
    }
    return null;
  }

  /// Check if an element can be placed at a position
  bool canPlaceElement(
    int row,
    int col,
    int rowSpan,
    int colSpan, [
    String? excludeId,
  ]) {
    // Check bounds
    if (row < 0 ||
        col < 0 ||
        row + rowSpan > gridRows ||
        col + colSpan > gridColumns) {
      return false;
    }

    // Check for overlaps
    for (final element in elements) {
      if (element.id == excludeId) continue;

      final elementEndRow = element.row + element.rowSpan;
      final elementEndCol = element.column + element.columnSpan;
      final newEndRow = row + rowSpan;
      final newEndCol = col + colSpan;

      // Check for overlap
      if (row < elementEndRow &&
          newEndRow > element.row &&
          col < elementEndCol &&
          newEndCol > element.column) {
        return false;
      }
    }
    return true;
  }

  GridWidgetSchema copyWith({
    String? id,
    String? name,
    String? description,
    GridWidgetSize? size,
    int? gridRows,
    int? gridColumns,
    List<GridElement>? elements,
    String? backgroundColor,
    double? customWidth,
    double? customHeight,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    // If size is changing, update grid dimensions to match
    final newSize = size ?? this.size;
    final newRows = size != null ? newSize.rows : (gridRows ?? this.gridRows);
    final newCols = size != null
        ? newSize.columns
        : (gridColumns ?? this.gridColumns);

    return GridWidgetSchema(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      size: newSize,
      gridRows: newRows,
      gridColumns: newCols,
      elements: elements ?? this.elements,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Add an element to the grid
  GridWidgetSchema addElement(GridElement element) {
    return copyWith(elements: [...elements, element]);
  }

  /// Remove an element by ID
  GridWidgetSchema removeElement(String elementId) {
    return copyWith(
      elements: elements.where((e) => e.id != elementId).toList(),
    );
  }

  /// Update an element
  GridWidgetSchema updateElement(GridElement updated) {
    return copyWith(
      elements: elements.map((e) => e.id == updated.id ? updated : e).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'size': size.name,
    'gridRows': gridRows,
    'gridColumns': gridColumns,
    'elements': elements.map((e) => e.toJson()).toList(),
    if (backgroundColor != null) 'backgroundColor': backgroundColor,
    if (customWidth != null) 'customWidth': customWidth,
    if (customHeight != null) 'customHeight': customHeight,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory GridWidgetSchema.fromJson(Map<String, dynamic> json) {
    return GridWidgetSchema(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      size: GridWidgetSize.values.firstWhere(
        (e) => e.name == json['size'],
        orElse: () => GridWidgetSize.medium,
      ),
      gridRows: json['gridRows'] as int?,
      gridColumns: json['gridColumns'] as int?,
      elements:
          (json['elements'] as List<dynamic>?)
              ?.map((e) => GridElement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      backgroundColor: json['backgroundColor'] as String?,
      customWidth: (json['customWidth'] as num?)?.toDouble(),
      customHeight: (json['customHeight'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
