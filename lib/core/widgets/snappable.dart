import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

/// Thanos snap effect widget - disintegrates any child widget into dust
/// Based on the approach from https://fidev.io/thanos-snap-effect-in-flutter/
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

  /// Values from -1 to 1 to dislocate the layers a bit
  List<double>? _randoms;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.snapOnTap ? () => isGone ? reset() : snap() : null,
      child: Stack(
        children: <Widget>[
          if (_layers != null) ..._layers!.map(_imageToWidget),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return _animationController.isDismissed
                  ? child!
                  : const SizedBox.shrink();
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

    // Create an image for every bucket
    final images = List<img.Image>.generate(
      widget.numberOfBuckets,
      (i) => img.Image(width: fullImage.width, height: fullImage.height),
    );

    // For every line of pixels
    for (int y = 0; y < fullImage.height; y++) {
      // Generate weight list of probabilities determining
      // to which bucket should given pixels go
      final weights = List<int>.generate(
        widget.numberOfBuckets,
        (bucket) =>
            _gauss(y / fullImage.height, bucket / widget.numberOfBuckets),
      );
      int sumOfWeights = weights.fold(0, (sum, el) => sum + el);

      // For every pixel in a line
      for (int x = 0; x < fullImage.width; x++) {
        // Get the pixel from fullImage
        final pixel = fullImage.getPixel(x, y);
        // Choose a bucket for a pixel
        int imageIndex = _pickABucket(weights, sumOfWeights);
        // Set the pixel from chosen bucket
        images[imageIndex].setPixel(x, y, pixel);
      }
    }

    _layers = await compute<List<img.Image>, List<Uint8List>>(
      _encodeImages,
      images,
    );

    // Prepare random dislocations and set state
    setState(() {
      _randoms = List.generate(
        widget.numberOfBuckets,
        (i) => (math.Random().nextDouble() - 0.5) * 2,
      );
    });

    // Give a short delay to draw images
    await Future.delayed(const Duration(milliseconds: 100));

    // Start the snap!
    _animationController.forward();
  }

  /// I am... IRON MAN   ~Tony Stark
  void reset() {
    setState(() {
      _layers = null;
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

    Offset randomOffset = widget.randomDislocationOffset.scale(
      _randoms![index],
      _randoms![index],
    );

    Animation<Offset> offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: widget.offset + randomOffset,
    ).animate(animation);

    return AnimatedBuilder(
      animation: _animationController,
      child: Image.memory(layer),
      builder: (context, child) {
        return Transform.translate(
          offset: offsetAnimation.value,
          child: Opacity(
            opacity: math.cos(animation.value * math.pi / 2),
            child: child,
          ),
        );
      },
    );
  }

  /// Returns index of a randomly chosen bucket
  int _pickABucket(List<int> weights, int sumOfWeights) {
    int rnd = math.Random().nextInt(sumOfWeights);
    int chosenImage = 0;
    for (int i = 0; i < widget.numberOfBuckets; i++) {
      if (rnd < weights[i]) {
        chosenImage = i;
        break;
      }
      rnd -= weights[i];
    }
    return chosenImage;
  }

  /// Gets an Image from a [child] and caches [size] for later use
  Future<img.Image?> _getImageFromWidget() async {
    final boundary =
        _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    // Cache image size for later
    size = boundary.size;
    final image = await boundary.toImage();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final pngBytes = byteData.buffer.asUint8List();
    return img.decodeImage(pngBytes);
  }

  int _gauss(double center, double value) =>
      (1000 * math.exp(-(math.pow((value - center), 2) / 0.14))).round();
}

/// This is slow! Run it in separate isolate
List<Uint8List> _encodeImages(List<img.Image> images) {
  return images.map((i) => Uint8List.fromList(img.encodePng(i))).toList();
}
