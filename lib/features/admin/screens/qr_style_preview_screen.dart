// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/branded_qr_code.dart';
import '../../../core/widgets/glass_scaffold.dart';

/// Preview screen showing all available QR code styles with the app logo.
///
/// Allows admins to see how each style looks before choosing one
/// for the app's default QR code appearance.
class QrStylePreviewScreen extends ConsumerStatefulWidget {
  const QrStylePreviewScreen({super.key});

  @override
  ConsumerState<QrStylePreviewScreen> createState() =>
      _QrStylePreviewScreenState();
}

class _QrStylePreviewScreenState extends ConsumerState<QrStylePreviewScreen> {
  QrStyle _selectedStyle = QrStyle.dots;

  @override
  Widget build(BuildContext context) {
    const sampleData = 'socialmesh://widget/id:SAMPLE_PREVIEW_DATA';

    return GlassScaffold.body(
      title: 'QR Code Styles',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.qr_code_2, color: context.accentColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Branded QR Code Styles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Preview different QR code styles with the Socialmesh '
                  'logo. All styles use Level H error correction for '
                  'reliable scanning.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Style cards
          _StyleCard(
            style: QrStyle.smooth,
            title: 'Smooth',
            description: 'Modern, rounded liquid-like modules. Premium feel.',
            sampleData: sampleData,
            isSelected: _selectedStyle == QrStyle.smooth,
            onTap: () => _selectStyle(QrStyle.smooth),
          ),
          const SizedBox(height: 16),

          _StyleCard(
            style: QrStyle.dots,
            title: 'Dots',
            description: 'Circular dot modules. Clean and minimal look.',
            sampleData: sampleData,
            isSelected: _selectedStyle == QrStyle.dots,
            onTap: () => _selectStyle(QrStyle.dots),
          ),
          const SizedBox(height: 16),

          _StyleCard(
            style: QrStyle.squares,
            title: 'Squares',
            description: 'Classic blocky QR style. Maximum compatibility.',
            sampleData: sampleData,
            isSelected: _selectedStyle == QrStyle.squares,
            onTap: () => _selectStyle(QrStyle.squares),
          ),
          const SizedBox(height: 32),

          // Elevated Styles Header
          Row(
            children: [
              Icon(Icons.auto_awesome, color: context.accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'ELEVATED STYLES',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.accentColor,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Premium color treatments using ${_selectedStyle.name} pattern',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 16),

          // Elevated styles horizontal scroll
          SizedBox(
            height: 280,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                // 1. Neon Glow
                _ElevatedStyleCard(
                  title: 'Neon Glow',
                  icon: Icons.lightbulb,
                  sampleData: sampleData,
                  style: _selectedStyle,
                  qrForeground: context.accentColor,
                  qrBackground: const Color(0xFF0D0D0D),
                  containerDecoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.accentColor.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.accentColor.withValues(alpha: 0.5),
                        blurRadius: 25,
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: context.accentColor.withValues(alpha: 0.3),
                        blurRadius: 50,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // 2. Frosted Glass
                _ElevatedStyleCard(
                  title: 'Frosted Glass',
                  icon: Icons.blur_on,
                  sampleData: sampleData,
                  style: _selectedStyle,
                  qrForeground: context.textPrimary.withValues(alpha: 0.85),
                  qrBackground: Colors.white.withValues(alpha: 0.15),
                  containerDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.25),
                        Colors.white.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 3. Inverted Dark
                _ElevatedStyleCard(
                  title: 'Inverted',
                  icon: Icons.invert_colors,
                  sampleData: sampleData,
                  style: _selectedStyle,
                  qrForeground: Colors.white,
                  qrBackground: const Color(0xFF1A1A1A),
                  containerDecoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 4. Holographic
                _ElevatedStyleCard(
                  title: 'Holographic',
                  icon: Icons.gradient,
                  sampleData: sampleData,
                  style: _selectedStyle,
                  qrForeground: const Color(0xFF6366F1),
                  qrBackground: Colors.white,
                  useGradientQr: true,
                  containerDecoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFEC4899),
                        Color(0xFF8B5CF6),
                        Color(0xFF3B82F6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 16),

                // 5. Accent Branded
                _ElevatedStyleCard(
                  title: 'Accent Branded',
                  icon: Icons.palette,
                  sampleData: sampleData,
                  style: _selectedStyle,
                  qrForeground: context.accentColor,
                  qrBackground: context.accentColor.withValues(alpha: 0.08),
                  containerDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.accentColor.withValues(alpha: 0.2),
                        context.accentColor.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.accentColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.accentColor.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // 6. Minimal Outline
                _ElevatedStyleCard(
                  title: 'Minimal',
                  icon: Icons.crop_square,
                  sampleData: sampleData,
                  style: _selectedStyle,
                  qrForeground: context.textPrimary,
                  qrBackground: Colors.transparent,
                  containerDecoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.border, width: 1),
                  ),
                ),
                const SizedBox(width: 16),

                // 7. Cyberpunk
                _ElevatedStyleCard(
                  title: 'Cyberpunk',
                  icon: Icons.electric_bolt,
                  sampleData: sampleData,
                  style: _selectedStyle,
                  qrForeground: const Color(0xFF00FF88),
                  qrBackground: const Color(0xFF0A0A0A),
                  containerDecoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00FF88).withValues(alpha: 0.7),
                      width: 2,
                    ),
                    boxShadow: [
                      const BoxShadow(
                        color: Color(0x6600FF88),
                        blurRadius: 20,
                        spreadRadius: -4,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF0080).withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(10, 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // 8. Accent Gradient (Sunset-style using accent colors)
                _AccentGradientStyleCard(
                  title: 'Accent Glow',
                  icon: Icons.wb_twilight,
                  sampleData: sampleData,
                  style: _selectedStyle,
                ),
                const SizedBox(width: 16),

                // 9. Ocean Deep
                _ElevatedStyleCard(
                  title: 'Ocean',
                  icon: Icons.water,
                  sampleData: sampleData,
                  style: _selectedStyle,
                  qrForeground: const Color(0xFF0891B2),
                  qrBackground: Colors.white,
                  containerDecoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF06B6D4),
                        Color(0xFF0284C7),
                        Color(0xFF1E40AF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // 10. Monochrome Luxury
                _ElevatedStyleCard(
                  title: 'Luxury',
                  icon: Icons.diamond,
                  sampleData: sampleData,
                  style: _selectedStyle,
                  qrForeground: const Color(0xFF1F1F1F),
                  qrBackground: const Color(0xFFF5F5F5),
                  containerDecoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE5E5E5),
                        Color(0xFFB8B8B8),
                        Color(0xFF9CA3AF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 15,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Large preview of selected style
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Selected: ${_selectedStyle.name.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.accentColor,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: BrandedQrCode(
                    data: sampleData,
                    size: 220,
                    style: _selectedStyle,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Scan to verify',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
                ),
              ],
            ),
          ),

          // Bottom padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  void _selectStyle(QrStyle style) {
    HapticFeedback.selectionClick();
    setState(() => _selectedStyle = style);
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.style,
    required this.title,
    required this.description,
    required this.sampleData,
    required this.isSelected,
    required this.onTap,
  });

  final QrStyle style;
  final String title;
  final String description;
  final String sampleData;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? context.accentColor : context.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // QR preview
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: BrandedQrCode(data: sampleData, size: 80, style: style),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: context.accentColor,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElevatedStyleCard extends StatelessWidget {
  const _ElevatedStyleCard({
    required this.title,
    required this.icon,
    required this.sampleData,
    required this.style,
    required this.qrForeground,
    required this.qrBackground,
    required this.containerDecoration,
    this.useGradientQr = false,
  });

  final String title;
  final IconData icon;
  final String sampleData;
  final QrStyle style;
  final Color qrForeground;
  final Color qrBackground;
  final BoxDecoration containerDecoration;
  final bool useGradientQr;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: containerDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _labelColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _labelColor,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // QR Code
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: qrBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: BrandedQrCode(
                    data: sampleData,
                    size: 130,
                    style: style,
                    foregroundColor: qrForeground,
                    backgroundColor: qrBackground,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Style indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _labelColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                style.name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _labelColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _labelColor {
    // Calculate luminance to decide label color
    final bgColor = containerDecoration.color ?? Colors.black;
    final gradient = containerDecoration.gradient;

    if (gradient != null && gradient is LinearGradient) {
      // Use first gradient color for luminance calculation
      final firstColor = gradient.colors.first;
      return firstColor.computeLuminance() > 0.5
          ? const Color(0xFF1F1F1F)
          : Colors.white;
    }

    return bgColor.computeLuminance() > 0.5
        ? const Color(0xFF1F1F1F)
        : Colors.white;
  }
}

/// Special card that uses the theme accent color for a sunset-style gradient.
class _AccentGradientStyleCard extends StatelessWidget {
  const _AccentGradientStyleCard({
    required this.title,
    required this.icon,
    required this.sampleData,
    required this.style,
  });

  final String title;
  final IconData icon;
  final String sampleData;
  final QrStyle style;

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    // Create gradient from lighter to darker accent shades
    final lightAccent = HSLColor.fromColor(accent)
        .withLightness(
          (HSLColor.fromColor(accent).lightness + 0.15).clamp(0.0, 1.0),
        )
        .toColor();
    final darkAccent = HSLColor.fromColor(accent)
        .withLightness(
          (HSLColor.fromColor(accent).lightness - 0.15).clamp(0.0, 1.0),
        )
        .toColor();

    return SizedBox(
      width: 200,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lightAccent, accent, darkAccent],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.5),
              blurRadius: 25,
              spreadRadius: -4,
            ),
            BoxShadow(
              color: darkAccent.withValues(alpha: 0.3),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // QR Code
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: BrandedQrCode(
                    data: sampleData,
                    size: 130,
                    style: style,
                    foregroundColor: accent,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Style indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                style.name,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
