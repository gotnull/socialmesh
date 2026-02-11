// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme.dart';

/// A hardened image widget that never crashes on load/decode errors.
///
/// Features:
/// - Always shows placeholder during loading
/// - Always shows error fallback on failure (never throws)
/// - Memory-efficient with cacheWidth/cacheHeight
/// - Supports network, file, memory, and asset images
/// - Handles corrupt image data gracefully
/// - Prevents fatal errors from reaching FlutterError.onError
///
/// Usage:
/// ```dart
/// SafeImage.network(
///   'https://example.com/image.jpg',
///   width: 200,
///   height: 200,
/// )
///
/// SafeImage.file(
///   File('/path/to/image.jpg'),
///   width: 100,
///   height: 100,
/// )
///
/// SafeImage.memory(
///   bytes,
///   width: 50,
///   height: 50,
/// )
/// ```
class SafeImage extends StatelessWidget {
  const SafeImage._({
    super.key,
    this.imageProvider,
    this.url,
    this.file,
    this.bytes,
    this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.cacheWidth,
    this.cacheHeight,
    this.color,
    this.colorBlendMode,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  });

  /// Creates a SafeImage from a network URL.
  factory SafeImage.network(
    String url, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    BoxShape shape = BoxShape.rectangle,
    Widget? placeholder,
    Widget? errorWidget,
    Duration fadeInDuration = const Duration(milliseconds: 200),
    int? cacheWidth,
    int? cacheHeight,
    Color? color,
    BlendMode? colorBlendMode,
    Alignment alignment = Alignment.center,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    Map<String, String>? headers,
  }) {
    return SafeImage._(
      key: key,
      url: url,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      shape: shape,
      placeholder: placeholder,
      errorWidget: errorWidget,
      fadeInDuration: fadeInDuration,
      cacheWidth: cacheWidth ?? _calculateCacheSize(width),
      cacheHeight: cacheHeight ?? _calculateCacheSize(height),
      color: color,
      colorBlendMode: colorBlendMode,
      alignment: alignment,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
    );
  }

  /// Creates a SafeImage from a local file.
  factory SafeImage.file(
    File file, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    BoxShape shape = BoxShape.rectangle,
    Widget? placeholder,
    Widget? errorWidget,
    Duration fadeInDuration = const Duration(milliseconds: 200),
    int? cacheWidth,
    int? cacheHeight,
    Color? color,
    BlendMode? colorBlendMode,
    Alignment alignment = Alignment.center,
    String? semanticLabel,
    bool excludeFromSemantics = false,
  }) {
    return SafeImage._(
      key: key,
      file: file,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      shape: shape,
      placeholder: placeholder,
      errorWidget: errorWidget,
      fadeInDuration: fadeInDuration,
      cacheWidth: cacheWidth ?? _calculateCacheSize(width),
      cacheHeight: cacheHeight ?? _calculateCacheSize(height),
      color: color,
      colorBlendMode: colorBlendMode,
      alignment: alignment,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
    );
  }

  /// Creates a SafeImage from memory bytes.
  factory SafeImage.memory(
    Uint8List bytes, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    BoxShape shape = BoxShape.rectangle,
    Widget? placeholder,
    Widget? errorWidget,
    Duration fadeInDuration = const Duration(milliseconds: 200),
    int? cacheWidth,
    int? cacheHeight,
    Color? color,
    BlendMode? colorBlendMode,
    Alignment alignment = Alignment.center,
    String? semanticLabel,
    bool excludeFromSemantics = false,
  }) {
    return SafeImage._(
      key: key,
      bytes: bytes,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      shape: shape,
      placeholder: placeholder,
      errorWidget: errorWidget,
      fadeInDuration: fadeInDuration,
      cacheWidth: cacheWidth ?? _calculateCacheSize(width),
      cacheHeight: cacheHeight ?? _calculateCacheSize(height),
      color: color,
      colorBlendMode: colorBlendMode,
      alignment: alignment,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
    );
  }

  /// Creates a SafeImage from an asset.
  factory SafeImage.asset(
    String assetPath, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    BoxShape shape = BoxShape.rectangle,
    Widget? placeholder,
    Widget? errorWidget,
    Duration fadeInDuration = const Duration(milliseconds: 200),
    int? cacheWidth,
    int? cacheHeight,
    Color? color,
    BlendMode? colorBlendMode,
    Alignment alignment = Alignment.center,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    AssetBundle? bundle,
    String? package,
  }) {
    return SafeImage._(
      key: key,
      assetPath: assetPath,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      shape: shape,
      placeholder: placeholder,
      errorWidget: errorWidget,
      fadeInDuration: fadeInDuration,
      cacheWidth: cacheWidth ?? _calculateCacheSize(width),
      cacheHeight: cacheHeight ?? _calculateCacheSize(height),
      color: color,
      colorBlendMode: colorBlendMode,
      alignment: alignment,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
    );
  }

  /// Creates a SafeImage from an ImageProvider directly.
  factory SafeImage.provider(
    ImageProvider imageProvider, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    BoxShape shape = BoxShape.rectangle,
    Widget? placeholder,
    Widget? errorWidget,
    Duration fadeInDuration = const Duration(milliseconds: 200),
    Color? color,
    BlendMode? colorBlendMode,
    Alignment alignment = Alignment.center,
    String? semanticLabel,
    bool excludeFromSemantics = false,
  }) {
    return SafeImage._(
      key: key,
      imageProvider: imageProvider,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      shape: shape,
      placeholder: placeholder,
      errorWidget: errorWidget,
      fadeInDuration: fadeInDuration,
      color: color,
      colorBlendMode: colorBlendMode,
      alignment: alignment,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
    );
  }

  final ImageProvider? imageProvider;
  final String? url;
  final File? file;
  final Uint8List? bytes;
  final String? assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final int? cacheWidth;
  final int? cacheHeight;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Alignment alignment;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  /// Calculate cache size based on display size for memory efficiency.
  /// Uses 2x for retina displays.
  static int? _calculateCacheSize(double? displaySize) {
    if (displaySize == null || displaySize.isInfinite || displaySize.isNaN) {
      return null;
    }
    // 2x for retina, capped at reasonable max
    return (displaySize * 2).toInt().clamp(1, 2048);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _SafeImageLoader(
      imageProvider: imageProvider,
      url: url,
      file: file,
      bytes: bytes,
      assetPath: assetPath,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder ?? _buildDefaultPlaceholder(context),
      errorWidget: errorWidget ?? _buildDefaultError(context),
      fadeInDuration: fadeInDuration,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      color: color,
      colorBlendMode: colorBlendMode,
      alignment: alignment,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
    );

    if (borderRadius != null && shape == BoxShape.rectangle) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    } else if (shape == BoxShape.circle) {
      child = ClipOval(child: child);
    }

    return child;
  }

  Widget _buildDefaultPlaceholder(BuildContext context) {
    final finiteW = (width != null && width!.isFinite) ? width! : 40.0;
    final finiteH = (height != null && height!.isFinite) ? height! : 40.0;
    final spinnerSize = finiteW < finiteH ? finiteW * 0.3 : finiteH * 0.3;
    return Container(
      width: width,
      height: height,
      color: context.card.withValues(alpha: 0.3),
      child: Center(
        child: SizedBox(
          width: spinnerSize,
          height: spinnerSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.textSecondary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultError(BuildContext context) {
    final finiteW = (width != null && width!.isFinite) ? width! : 40.0;
    final finiteH = (height != null && height!.isFinite) ? height! : 40.0;
    final iconSize = finiteW < finiteH ? finiteW * 0.4 : finiteH * 0.4;
    return Container(
      width: width,
      height: height,
      color: context.card.withValues(alpha: 0.3),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: iconSize,
          color: context.textSecondary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// Internal stateful widget that handles the actual image loading with error handling.
class _SafeImageLoader extends StatefulWidget {
  const _SafeImageLoader({
    this.imageProvider,
    this.url,
    this.file,
    this.bytes,
    this.assetPath,
    this.width,
    this.height,
    required this.fit,
    required this.placeholder,
    required this.errorWidget,
    required this.fadeInDuration,
    this.cacheWidth,
    this.cacheHeight,
    this.color,
    this.colorBlendMode,
    required this.alignment,
    this.semanticLabel,
    required this.excludeFromSemantics,
  });

  final ImageProvider? imageProvider;
  final String? url;
  final File? file;
  final Uint8List? bytes;
  final String? assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget placeholder;
  final Widget errorWidget;
  final Duration fadeInDuration;
  final int? cacheWidth;
  final int? cacheHeight;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Alignment alignment;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  @override
  State<_SafeImageLoader> createState() => _SafeImageLoaderState();
}

class _SafeImageLoaderState extends State<_SafeImageLoader> {
  _LoadState _state = _LoadState.loading;

  @override
  Widget build(BuildContext context) {
    if (_state == _LoadState.error) {
      return widget.errorWidget;
    }

    return _buildImage();
  }

  Widget _buildImage() {
    // Build the appropriate Image widget based on source
    Widget image;

    if (widget.imageProvider != null) {
      image = Image(
        image: widget.imageProvider!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        alignment: widget.alignment,
        semanticLabel: widget.semanticLabel,
        excludeFromSemantics: widget.excludeFromSemantics,
        frameBuilder: _frameBuilder,
        errorBuilder: _errorBuilder,
      );
    } else if (widget.url != null) {
      image = Image.network(
        widget.url!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        alignment: widget.alignment,
        semanticLabel: widget.semanticLabel,
        excludeFromSemantics: widget.excludeFromSemantics,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        frameBuilder: _frameBuilder,
        errorBuilder: _errorBuilder,
        loadingBuilder: _loadingBuilder,
      );
    } else if (widget.file != null) {
      image = Image.file(
        widget.file!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        alignment: widget.alignment,
        semanticLabel: widget.semanticLabel,
        excludeFromSemantics: widget.excludeFromSemantics,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        frameBuilder: _frameBuilder,
        errorBuilder: _errorBuilder,
      );
    } else if (widget.bytes != null) {
      image = Image.memory(
        widget.bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        alignment: widget.alignment,
        semanticLabel: widget.semanticLabel,
        excludeFromSemantics: widget.excludeFromSemantics,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        frameBuilder: _frameBuilder,
        errorBuilder: _errorBuilder,
      );
    } else if (widget.assetPath != null) {
      image = Image.asset(
        widget.assetPath!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        alignment: widget.alignment,
        semanticLabel: widget.semanticLabel,
        excludeFromSemantics: widget.excludeFromSemantics,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        frameBuilder: _frameBuilder,
        errorBuilder: _errorBuilder,
      );
    } else {
      // No source provided - show error
      return widget.errorWidget;
    }

    return image;
  }

  Widget _frameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded || frame != null) {
      // Image is loaded
      if (_state != _LoadState.loaded && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _state = _LoadState.loaded);
        });
      }
      return AnimatedSwitcher(
        duration: wasSynchronouslyLoaded
            ? Duration.zero
            : widget.fadeInDuration,
        child: child,
      );
    }
    // Still loading
    return widget.placeholder;
  }

  Widget _loadingBuilder(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  ) {
    if (loadingProgress == null) {
      return child; // frameBuilder handles the transition
    }
    return widget.placeholder;
  }

  Widget _errorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    // Log but don't crash - this is the key safety feature
    debugPrint('SafeImage error: $error');

    // Update state safely
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _state = _LoadState.error);
      });
    }

    return widget.errorWidget;
  }
}

enum _LoadState { loading, loaded, error }
