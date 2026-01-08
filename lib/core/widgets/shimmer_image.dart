import 'package:flutter/material.dart';

import '../theme.dart';

/// A network image with shimmer loading effect.
/// Provides visual feedback while images load.
class ShimmerImage extends StatefulWidget {
  const ShimmerImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Widget? errorWidget;
  final Duration fadeInDuration;

  @override
  State<ShimmerImage> createState() => _ShimmerImageState();
}

class _ShimmerImageState extends State<ShimmerImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ?? _buildErrorPlaceholder(context);
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: Image.network(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedSwitcher(
            duration: widget.fadeInDuration,
            child: frame != null ? child : _buildShimmer(context),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hasError = true);
          });
          return widget.errorWidget ?? _buildErrorPlaceholder(context);
        },
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? widget.borderRadius
                : null,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.card,
                context.card.withValues(alpha: 0.5),
                context.card,
              ],
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value,
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.rectangle
            ? widget.borderRadius
            : null,
        color: context.card,
      ),
      child: Icon(
        Icons.broken_image_outlined,
        color: context.textSecondary,
        size: 24,
      ),
    );
  }
}

/// A circular avatar with shimmer loading effect.
class ShimmerAvatar extends StatefulWidget {
  const ShimmerAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    this.fallbackText,
    this.backgroundColor,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.animateIn = false,
    this.animationDelay = Duration.zero,
  });

  final String? imageUrl;
  final double radius;
  final String? fallbackText;
  final Color? backgroundColor;
  final Duration fadeInDuration;
  final bool animateIn;
  final Duration animationDelay;

  @override
  State<ShimmerAvatar> createState() => _ShimmerAvatarState();
}

class _ShimmerAvatarState extends State<ShimmerAvatar>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _entryController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    if (widget.animateIn) {
      Future.delayed(widget.animationDelay, () {
        if (mounted) {
          _entryController.forward();
        }
      });
    } else {
      _entryController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        widget.backgroundColor ?? context.accentColor.withValues(alpha: 0.2);

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _opacityAnimation.value, child: child),
        );
      },
      child: widget.imageUrl != null && !_hasError
          ? _buildNetworkAvatar(context, bgColor)
          : _buildFallbackAvatar(context, bgColor),
    );
  }

  Widget _buildNetworkAvatar(BuildContext context, Color bgColor) {
    return ClipOval(
      child: Container(
        width: widget.radius * 2,
        height: widget.radius * 2,
        color: bgColor,
        child: Image.network(
          widget.imageUrl!,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedSwitcher(
              duration: widget.fadeInDuration,
              child: frame != null
                  ? child
                  : _buildShimmerCircle(context, bgColor),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasError = true);
            });
            return _buildFallbackContent(context);
          },
        ),
      ),
    );
  }

  Widget _buildShimmerCircle(BuildContext context, Color bgColor) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return Container(
          width: widget.radius * 2,
          height: widget.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [bgColor, bgColor.withValues(alpha: 0.3), bgColor],
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value,
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackAvatar(BuildContext context, Color bgColor) {
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
      child: Center(child: _buildFallbackContent(context)),
    );
  }

  Widget _buildFallbackContent(BuildContext context) {
    if (widget.fallbackText != null) {
      return Text(
        widget.fallbackText!,
        style: TextStyle(
          fontSize: widget.radius * 0.7,
          fontWeight: FontWeight.bold,
          color: context.accentColor,
        ),
      );
    }
    return Icon(Icons.person, size: widget.radius, color: context.accentColor);
  }
}

/// A banner image with shimmer loading effect.
class ShimmerBanner extends StatefulWidget {
  const ShimmerBanner({
    super.key,
    required this.imageUrl,
    this.height = 180,
    this.fallback,
    this.fadeInDuration = const Duration(milliseconds: 300),
  });

  final String? imageUrl;
  final double height;
  final Widget? fallback;
  final Duration fadeInDuration;

  @override
  State<ShimmerBanner> createState() => _ShimmerBannerState();
}

class _ShimmerBannerState extends State<ShimmerBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || _hasError) {
      return widget.fallback ?? _buildShimmer(context);
    }

    return Image.network(
      widget.imageUrl!,
      height: widget.height,
      width: double.infinity,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: widget.fadeInDuration,
          child: frame != null ? child : _buildShimmer(context),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hasError = true);
        });
        return widget.fallback ?? _buildShimmer(context);
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.card,
                context.card.withValues(alpha: 0.5),
                context.card,
              ],
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value,
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
