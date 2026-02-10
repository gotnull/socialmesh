// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Modified: Icon sizes increased from 15dp to 24dp for mobile touch targets.

import 'package:flutter/material.dart';

import 'standard_interfaces/vs_dynamic_interface.dart';
import 'vs_node_data.dart';

/// Interface icon size — enlarged from upstream 15dp for mobile usability.
const double kInterfaceIconSize = 24.0;

/// Base interface class.
///
/// Used for base input and output interface.
abstract class VSInterfaceData {
  VSInterfaceData({
    required this.type,
    this.interfaceIconBuilder,
    String? title,
    this.toolTip,
  }) : _title = title ?? "";

  /// The color this interface will display in the UI.
  Color get interfaceColor;

  /// Can be used to insert your own interface icon widget.
  ///
  /// You need to pass [anchor] as the widget key for the lines to work
  /// correctly.
  Widget Function(BuildContext context, GlobalKey anchor, VSInterfaceData data)?
  interfaceIconBuilder;

  /// The type of this interface.
  ///
  /// Important for deserialization.
  final String type;

  /// The title displayed on the interface.
  ///
  /// Useful for localization.
  String get title => _title.isNotEmpty ? _title : type;
  set title(String data) => _title = data;
  String _title = "";

  /// A tooltip displayed on the widget.
  final String? toolTip;

  /// The parent node of this interface.
  VSNodeData? nodeData;

  /// The current offset of the interface relative to the origin of the parent
  /// (top-left corner).
  Offset? widgetOffset;
}

/// Base input interface.
///
/// Makes sure only correct types can be connected.
abstract class VSInputData extends VSInterfaceData {
  VSInputData({
    required super.type,
    super.interfaceIconBuilder,
    super.title,
    super.toolTip,
    VSOutputData? initialConnection,
  }) {
    connectedInterface = initialConnection;
  }

  /// The icon displayed for this interface.
  ///
  /// Will use [interfaceColor] by default.
  ///
  /// Switches between [Icons.radio_button_unchecked] and
  /// [Icons.radio_button_checked] depending on whether a node is connected.
  Widget getInterfaceIcon({
    required BuildContext context,
    required GlobalKey anchor,
  }) {
    if (interfaceIconBuilder != null) {
      return interfaceIconBuilder!(context, anchor, this);
    }

    final icon = connectedInterface == null
        ? Icons.radio_button_unchecked
        : Icons.radio_button_checked;

    return Icon(
      icon,
      key: anchor,
      color: interfaceColor,
      size: kInterfaceIconSize,
    );
  }

  /// The currently connected interface of this input.
  ///
  /// Returns null if no interface is connected.
  VSOutputData? get connectedInterface => _connectedInterface;
  VSOutputData? _connectedInterface;
  set connectedInterface(VSOutputData? data) {
    if (data == null || acceptInput(data)) {
      _connectedInterface = data;
      nodeData?.onUpdatedConnection?.call(this);
    }
  }

  /// The list of types this input will interface with.
  ///
  /// The supplied type needs to extend [VSOutputData].
  List<Type> get acceptedTypes;

  bool acceptInput(VSOutputData data) {
    return acceptedTypes.contains(data.runtimeType) ||
        data.runtimeType == VSDynamicOutputData;
  }

  Map<String, dynamic> toJson() {
    return {"name": type, "connectedNode": connectedInterface?.toJson()};
  }
}

/// Base output interface.
abstract class VSOutputData<T> extends VSInterfaceData {
  VSOutputData({
    required super.type,
    super.interfaceIconBuilder,
    super.title,
    super.toolTip,
    this.outputFunction,
  });

  /// The icon displayed for this interface.
  ///
  /// Will use [interfaceColor] and [Icons.circle] by default.
  Widget getInterfaceIcon({
    required BuildContext context,
    required GlobalKey anchor,
  }) {
    if (interfaceIconBuilder != null) {
      return interfaceIconBuilder!(context, anchor, this);
    }

    return Icon(
      Icons.circle,
      key: anchor,
      color: interfaceColor,
      size: kInterfaceIconSize,
    );
  }

  /// The function this interface will execute on evaluation.
  final T Function(Map<String, dynamic>)? outputFunction;

  Map<String, dynamic> toJson() {
    return {"name": type, "nodeData": nodeData?.id};
  }
}
