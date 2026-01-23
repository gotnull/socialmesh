// Snappable library - Thanos snap effect in Flutter
// Ported from https://github.com/MarcinusX/snappable (pub.dev/packages/snappable)
// Copyright 2019 Fidev Marcin Szalek - BSD 2-Clause License
// Updated for Dart 3 and image package 4.x

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as image;

class Snappable extends StatefulWidget {
  /// Widget to be snapped
  final Widget child;

  /// Direction and range of snap effect
  /// (Where and how far will particles go)
  final Offset offset;

  /// Duration of whole snap animation
  final Duration duration;

  /// How much can particle be randomized,
  /// For example if [offset] is (100, 100) and [randomDislocationOffset] is (10,10),
  /// Each layer can be moved to maximum between 90 and 110.
  final Offset randomDislocationOffset;

  /// Number of layers of images,
  /// The more of them the better effect but the more heavy it is for CPU
  final int numberOfBuckets;

  /// Quick helper to snap widgets when touched
  /// If true wraps the widget in [GestureDetector] and starts [snap] when tapped
  /// Defaults to false
  final bool snapOnTap;

  /// Delay before hiding the original child after snap starts
  /// Useful to prevent a 1-frame blink while image layers decode.
  final Duration hideOriginalDelay;

  /// Function that gets called when snap ends
  final VoidCallback? onSnapped;

  const Snappable({
    super.key,
    required this.child,
    this.offset = const Offset(64, -32),
    this.duration = const Duration(milliseconds: 5000),
    this.randomDislocationOffset = const Offset(64, 32),
    this.numberOfBuckets = 16,
    this.snapOnTap = false,
    this.hideOriginalDelay = Duration.zero,
    this.onSnapped,
  });

  @override
  SnappableState createState() => SnappableState();
}

class SnappableState extends State<Snappable>
    with SingleTickerProviderStateMixin {
  static const double _singleLayerAnimationLength = 0.6;
  static const double _lastLayerAnimationStart =
      1 - _singleLayerAnimationLength;

  bool get isGone => _animationController.isCompleted;

  /// Main snap effect controller
  late AnimationController _animationController;

  /// Key to get image of a [widget.child]
  final GlobalKey _globalKey = GlobalKey();

  /// Layers of image
  List<Uint8List>? _layers;
  bool _hideOriginal = false;
  Timer? _hideOriginalTimer;

  /// Direction particles move (away from erosion origin), normalized
  double _directionX = 1.0;
  double _directionY = 0.0;

  /// Small per-layer random offsets for slight variation
  List<double>? _randomOffsets;

  /// Size of child widget
  Size? size;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    if (widget.onSnapped != null) {
      _animationController.addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onSnapped!();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _hideOriginalTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.snapOnTap ? () => isGone ? reset() : snap() : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Layers positioned at origin to prevent layout shifts
          if (_layers != null) ..._layers!.map(_imageToWidget),
          // Original child - hidden when animation starts
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _hideOriginal ? 0.0 : 1.0,
                child: child,
              );
            },
            child: RepaintBoundary(key: _globalKey, child: widget.child),
          ),
        ],
      ),
    );
  }

  /// I am... INEVITABLE      ~Thanos
  Future<void> snap() async {
    // Get image from child
    final fullImage = await _getImageFromWidget();
    if (fullImage == null) return;

    // Check if still mounted after async operation
    if (!mounted) return;

    // Do ALL heavy work in isolate: pixel distribution + PNG encoding
    final result = await compute<_SnapParams, _SnapResult>(
      _processAndEncodeImages,
      _SnapParams(
        imageBytes: fullImage.buffer.asUint8List(),
        width: fullImage.width,
        height: fullImage.height,
        numberOfBuckets: widget.numberOfBuckets,
      ),
    );

    // Check if still mounted after compute
    if (!mounted) return;

    // Set state and start animation immediately
    setState(() {
      _layers = result.layers;
      _directionX = result.directionX;
      _directionY = result.directionY;
      // Small random offsets for slight per-layer variation (±15%)
      _randomOffsets = List.generate(
        widget.numberOfBuckets,
        (i) => (math.Random().nextDouble() - 0.5) * 0.3,
      );
    });

    // Start the snap!
    _hideOriginalTimer?.cancel();
    if (widget.hideOriginalDelay == Duration.zero) {
      setState(() => _hideOriginal = true);
    } else {
      _hideOriginalTimer = Timer(widget.hideOriginalDelay, () {
        if (!mounted) return;
        setState(() => _hideOriginal = true);
      });
    }
    _animationController.forward();
  }

  /// Assemble from particles back into the widget (reverse snap)
  Future<void> dustIn() async {
    // Get image from child
    final fullImage = await _getImageFromWidget();
    if (fullImage == null) return;

    // Check if still mounted after async operation
    if (!mounted) return;

    // Do ALL heavy work in isolate: pixel distribution + PNG encoding
    final result = await compute<_SnapParams, _SnapResult>(
      _processAndEncodeImages,
      _SnapParams(
        imageBytes: fullImage.buffer.asUint8List(),
        width: fullImage.width,
        height: fullImage.height,
        numberOfBuckets: widget.numberOfBuckets,
      ),
    );

    // Check if still mounted after compute
    if (!mounted) return;

    // Set state and start reverse animation
    setState(() {
      _layers = result.layers;
      _directionX = result.directionX;
      _directionY = result.directionY;
      _randomOffsets = List.generate(
        widget.numberOfBuckets,
        (i) => (math.Random().nextDouble() - 0.5) * 0.3,
      );
      _hideOriginal = true;
      _animationController.value = 1.0;
    });

    await _animationController.reverse();
    if (!mounted) return;
    setState(() {
      _layers = null;
      _randomOffsets = null;
      _hideOriginal = false;
    });
  }

  /// I am... IRON MAN   ~Tony Stark
  void reset() {
    if (!mounted) return;
    _hideOriginalTimer?.cancel();
    setState(() {
      _layers = null;
      _randomOffsets = null;
      _hideOriginal = false;
      _animationController.reset();
    });
  }

  Widget _imageToWidget(Uint8List layer) {
    // Get layer's index in the list
    int index = _layers!.indexOf(layer);

    // Based on index, calculate when this layer should start and end
    double animationStart =
        (index / _layers!.length) * _lastLayerAnimationStart;
    double animationEnd = animationStart + _singleLayerAnimationLength;

    // Create interval animation using only part of whole animation
    CurvedAnimation animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(animationStart, animationEnd, curve: Curves.easeOut),
    );

    // Calculate total magnitude from base offset
    final baseMagnitude =
        widget.offset.distance + widget.randomDislocationOffset.distance;

    // All layers move in same direction (away from erosion origin)
    // with small per-layer variation in distance
    final distanceVariation = 1.0 + _randomOffsets![index];
    final distance = baseMagnitude * distanceVariation;

    // Particles move in the erosion direction (away from origin)
    final endOffset = Offset(_directionX * distance, _directionY * distance);

    Animation<Offset> offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: endOffset,
    ).animate(animation);

    return Positioned(
      left: 0,
      top: 0,
      width: size?.width,
      height: size?.height,
      child: AnimatedBuilder(
        animation: _animationController,
        child: Image.memory(
          layer,
          fit: BoxFit.none,
          filterQuality: FilterQuality.none,
          scale: 1.0,
        ),
        builder: (context, child) {
          return Transform.translate(
            offset: offsetAnimation.value,
            child: Opacity(
              opacity: math.cos(animation.value * math.pi / 2),
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// Gets an Image from a [child] and caches [size] for later use
  Future<image.Image?> _getImageFromWidget() async {
    final boundary =
        _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    // Cache image for later
    size = boundary.size;
    final img = await boundary.toImage();

    // Get raw RGBA bytes directly from Flutter (more reliable than PNG encode/decode)
    final byteData = await img.toByteData(format: ImageByteFormat.rawRgba);
    if (byteData == null) return null;

    // Create image directly from RGBA bytes - this preserves exact pixel colors
    return image.Image.fromBytes(
      width: img.width,
      height: img.height,
      bytes: byteData.buffer,
      format: image.Format.uint8,
      numChannels: 4,
      order: image.ChannelOrder.rgba,
    );
  }
}

/// Parameters for isolate processing
class _SnapParams {
  final Uint8List imageBytes;
  final int width;
  final int height;
  final int numberOfBuckets;

  _SnapParams({
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.numberOfBuckets,
  });
}

/// Result from isolate processing - layers + direction
class _SnapResult {
  final List<Uint8List> layers;
  final double directionX;
  final double directionY;

  _SnapResult({
    required this.layers,
    required this.directionX,
    required this.directionY,
  });
}

/// Process pixels and encode to PNG - runs in isolate for performance
_SnapResult _processAndEncodeImages(_SnapParams params) {
  final random = math.Random();

  // Recreate source image from bytes
  final fullImage = image.Image.fromBytes(
    width: params.width,
    height: params.height,
    bytes: params.imageBytes.buffer,
    format: image.Format.uint8,
    numChannels: 4,
    order: image.ChannelOrder.rgba,
  );

  // Create an image for every bucket
  final images = List<image.Image>.generate(
    params.numberOfBuckets,
    (i) => image.Image(
      width: params.width,
      height: params.height,
      format: image.Format.uint8,
      numChannels: 4,
    ),
  );

  // Pick a random erosion origin point - this is where the snap STARTS
  // Can be anywhere: corner, edge, or even outside the image for diagonal sweeps
  final originX =
      random.nextDouble() * params.width * 1.5 - params.width * 0.25;
  final originY =
      random.nextDouble() * params.height * 1.5 - params.height * 0.25;

  // Calculate max possible distance for normalization
  final corners = [
    math.sqrt(math.pow(originX, 2) + math.pow(originY, 2)),
    math.sqrt(math.pow(originX - params.width, 2) + math.pow(originY, 2)),
    math.sqrt(math.pow(originX, 2) + math.pow(originY - params.height, 2)),
    math.sqrt(
      math.pow(originX - params.width, 2) +
          math.pow(originY - params.height, 2),
    ),
  ];
  final maxDistance = corners.reduce(math.max);

  // For every pixel, assign to bucket based on distance from erosion origin
  // Closer pixels = earlier buckets = fade first (erosion starts here)
  // Farther pixels = later buckets = fade last (erosion reaches here later)
  for (int y = 0; y < params.height; y++) {
    for (int x = 0; x < params.width; x++) {
      // Distance from erosion origin
      final distance = math.sqrt(
        math.pow(x - originX, 2) + math.pow(y - originY, 2),
      );

      // Normalize to 0-1 range
      final normalizedDistance = distance / maxDistance;

      // Add small random noise so edges aren't perfectly smooth
      // This creates the dusty/particle look at the erosion boundary
      final noise = (random.nextDouble() - 0.5) * 0.15;
      final adjustedDistance = (normalizedDistance + noise).clamp(0.0, 0.999);

      // Map to bucket - closer = lower bucket = fades first
      final bucket = (adjustedDistance * params.numberOfBuckets).floor();

      final pixel = fullImage.getPixel(x, y);
      final targetPixel = images[bucket].getPixel(x, y);
      targetPixel.r = pixel.r;
      targetPixel.g = pixel.g;
      targetPixel.b = pixel.b;
      targetPixel.a = pixel.a;
    }
  }

  // Calculate direction particles should move (away from origin = toward center)
  // Find center of image
  final centerX = params.width / 2;
  final centerY = params.height / 2;
  // Direction is from origin toward center (so particles move away from erosion)
  final dirX = centerX - originX;
  final dirY = centerY - originY;
  final dirMagnitude = math.sqrt(dirX * dirX + dirY * dirY);
  final normalizedDirX = dirMagnitude > 0 ? dirX / dirMagnitude : 1.0;
  final normalizedDirY = dirMagnitude > 0 ? dirY / dirMagnitude : 0.0;

  // Encode all images to PNG
  final encodedLayers = images
      .map((img) => Uint8List.fromList(image.encodePng(img)))
      .toList();

  return _SnapResult(
    layers: encodedLayers,
    directionX: normalizedDirX,
    directionY: normalizedDirY,
  );
}
