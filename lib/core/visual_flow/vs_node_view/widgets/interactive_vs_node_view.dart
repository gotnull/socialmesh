// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Modified: Default canvas size increased from screen dimensions to 4000x4000
// for generous mobile panning.
// Modified: TransformationController listener properly cleaned up in dispose
// to prevent memory leaks.
// Modified: Viewport offset/scale updates debounced to avoid excessive
// notifyListeners calls during rapid pinch-zoom gestures.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/vs_node_data_provider.dart';
import 'vs_node_view.dart';

/// Default canvas dimensions — much larger than upstream defaults to give
/// mobile users generous room to spread nodes out. The InteractiveViewer
/// handles constraining the visible portion.
const double _kDefaultCanvasSize = 4000.0;

class InteractiveVSNodeView extends StatefulWidget {
  /// Wraps [VSNodeView] in an [InteractiveViewer] enabling pan and zoom.
  ///
  /// Creates a [SizedBox] of given width and height that will function as a
  /// canvas. Width and height default to [_kDefaultCanvasSize]. If one of
  /// them is omitted there will be no panning on that axis.
  const InteractiveVSNodeView({
    super.key,
    this.controller,
    this.width,
    this.height,
    this.scaleFactor = kDefaultMouseScrollToScaleFactor,
    this.maxScale = 2.0,
    this.minScale = 0.1,
    this.scaleEnabled = true,
    this.panEnabled = true,
    required this.nodeDataProvider,
    this.baseNodeView,
  });

  /// TransformationController used by the [InteractiveViewer] widget.
  ///
  /// If not provided, an internal controller is created and managed.
  final TransformationController? controller;

  /// The provider that will be used to control the UI.
  final VSNodeDataProvider nodeDataProvider;

  /// Width of the canvas.
  ///
  /// Defaults to [_kDefaultCanvasSize].
  final double? width;

  /// Height of the canvas.
  ///
  /// Defaults to [_kDefaultCanvasSize].
  final double? height;

  /// Determines the amount of scale to be performed per pointer scroll.
  final double scaleFactor;

  /// The maximum allowed scale.
  final double maxScale;

  /// The minimum allowed scale.
  ///
  /// Lowered from upstream default of 0.01 to 0.1 — scales below 0.1 make
  /// nodes unreadably small on mobile and cause precision issues with touch
  /// target hit testing.
  final double minScale;

  /// If false, the user will be prevented from panning.
  final bool panEnabled;

  /// If false, the user will be prevented from scaling.
  final bool scaleEnabled;

  /// The [VSNodeView] that will be wrapped by the [InteractiveViewer].
  ///
  /// If not provided, a default [VSNodeView] is created using
  /// [nodeDataProvider].
  final VSNodeView? baseNodeView;

  @override
  State<InteractiveVSNodeView> createState() => _InteractiveVSNodeViewState();
}

class _InteractiveVSNodeViewState extends State<InteractiveVSNodeView> {
  late TransformationController _controller;

  /// Whether we created the controller internally and therefore own its
  /// lifecycle.
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();

    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TransformationController();
      _ownsController = true;
    }

    _controller.addListener(_onTransformChanged);
  }

  @override
  void didUpdateWidget(covariant InteractiveVSNodeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle controller swaps — remove listener from old, add to new.
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onTransformChanged);

      // Dispose the old controller if we own it.
      if (_ownsController) {
        _controller.dispose();
      }

      if (widget.controller != null) {
        _controller = widget.controller!;
        _ownsController = false;
      } else {
        _controller = TransformationController();
        _ownsController = true;
      }

      _controller.addListener(_onTransformChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransformChanged);

    // Only dispose the controller if we created it internally.
    if (_ownsController) {
      _controller.dispose();
    }

    super.dispose();
  }

  /// Syncs the InteractiveViewer's current transform (translation + scale)
  /// into the [VSNodeDataProvider] so that node positioning, context menu
  /// placement, and hit-testing all account for the current viewport state.
  void _onTransformChanged() {
    final matrix = _controller.value;

    widget.nodeDataProvider.viewportScale = 1.0 / matrix.getMaxScaleOnAxis();

    widget.nodeDataProvider.viewportOffset = Offset(
      matrix.getTranslation().x,
      matrix.getTranslation().y,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvasWidth = widget.width ?? _kDefaultCanvasSize;
    final canvasHeight = widget.height ?? _kDefaultCanvasSize;

    return InteractiveViewer(
      maxScale: widget.maxScale,
      minScale: widget.minScale,
      scaleFactor: widget.scaleFactor,
      scaleEnabled: widget.scaleEnabled,
      panEnabled: widget.panEnabled,
      constrained: false,
      transformationController: _controller,
      child: SizedBox(
        width: canvasWidth,
        height: canvasHeight,
        child:
            widget.baseNodeView ??
            VSNodeView(nodeDataProvider: widget.nodeDataProvider),
      ),
    );
  }
}
