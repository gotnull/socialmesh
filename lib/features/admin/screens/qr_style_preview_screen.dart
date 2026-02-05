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
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
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
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
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
