// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.

import 'dart:math';

import 'package:flutter/material.dart';

import 'data/offset_extension.dart';
import 'data/vs_interface.dart';
import 'data/vs_node_data.dart';
import 'data/vs_node_data_provider.dart';

typedef VSNodeDataBuilder = VSNodeData Function(Offset, VSOutputData?);

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(
  Iterable.generate(
    length,
    (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length)),
  ),
);

RenderBox findAndUpdateWidgetPosition({
  required GlobalKey widgetAnchor,
  required BuildContext context,
  required VSInterfaceData data,
}) {
  final renderBox =
      widgetAnchor.currentContext?.findRenderObject() as RenderBox;
  Offset position = renderBox.localToGlobal(getWidgetCenter(renderBox));

  final provider = VSNodeDataProvider.of(context);

  final newOffset =
      provider.applyViewPortTransform(position) - data.nodeData!.widgetOffset;

  if (newOffset != data.widgetOffset) {
    data.widgetOffset = newOffset;
    provider.updateOrCreateNodes([data.nodeData!], updateHistory: false);
  }

  return renderBox;
}

Offset getWidgetCenter(RenderBox? renderBox) =>
    renderBox != null ? (renderBox.size.toOffset() / 2) : Offset.zero;

Widget wrapWithToolTip({String? toolTip, required Widget child}) {
  return toolTip == null
      ? child
      : Tooltip(
          message: toolTip,
          waitDuration: const Duration(seconds: 1),
          child: child,
        );
}
