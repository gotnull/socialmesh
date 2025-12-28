import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/revenuecat_config.dart';
import '../../core/theme.dart';
import '../../providers/subscription_providers.dart';

/// Home widgets configuration screen for Widget Pack owners
/// Shows available iOS/Android widgets and instructions for adding them
class HomeWidgetsScreen extends ConsumerStatefulWidget {
  const HomeWidgetsScreen({super.key});

  @override
  ConsumerState<HomeWidgetsScreen> createState() => _HomeWidgetsScreenState();
}

class _HomeWidgetsScreenState extends ConsumerState<HomeWidgetsScreen> {
  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'Home Widgets',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          _buildHeader(context, accentColor),
          const SizedBox(height: 24),

          // Available Widgets Section
          _buildSectionHeader('AVAILABLE WIDGETS'),
          const SizedBox(height: 12),
          _buildWidgetCard(
            context,
            icon: Icons.people,
            title: 'Mesh Status',
            description: 'Shows connected nodes count and mesh health',
            sizes: ['Small', 'Medium'],
            accentColor: accentColor,
          ),
          const SizedBox(height: 12),
          _buildWidgetCard(
            context,
            icon: Icons.message,
            title: 'Recent Messages',
            description: 'Displays latest messages from your mesh',
            sizes: ['Medium', 'Large'],
            accentColor: accentColor,
          ),
          const SizedBox(height: 12),
          _buildWidgetCard(
            context,
            icon: Icons.battery_full,
            title: 'Device Battery',
            description: 'Shows battery level of your connected device',
            sizes: ['Small'],
            accentColor: accentColor,
          ),
          const SizedBox(height: 12),
          _buildWidgetCard(
            context,
            icon: Icons.send,
            title: 'Quick Message',
            description: 'Send a canned response with one tap',
            sizes: ['Small', 'Medium'],
            accentColor: accentColor,
          ),
          const SizedBox(height: 12),
          _buildWidgetCard(
            context,
            icon: Icons.gps_fixed,
            title: 'Location Beacon',
            description: 'Share your location with a single tap',
            sizes: ['Small'],
            accentColor: accentColor,
          ),
          const SizedBox(height: 24),

          // How to Add Section
          _buildSectionHeader('HOW TO ADD WIDGETS'),
          const SizedBox(height: 12),
          _buildInstructions(context, accentColor),
          const SizedBox(height: 24),

          // Tips Section
          _buildSectionHeader('TIPS'),
          const SizedBox(height: 12),
          _buildTipsSection(context, accentColor),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color accentColor) {
    final storeProductsAsync = ref.watch(storeProductsProvider);
    final storeProducts = storeProductsAsync.when(
      data: (data) => data,
      loading: () => <String, StoreProductInfo>{},
      error: (e, s) => <String, StoreProductInfo>{},
    );
    final widgetPackName =
        storeProducts[RevenueCatConfig.widgetPackProductId]?.title ??
        'Widget Pack';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.3),
            accentColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.widgets, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widgetPackName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                Text(
                  'Add widgets to your home screen for quick access',
                  style: TextStyle(fontSize: 14, color: context.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildWidgetCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required List<String> sizes,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: context.textTertiary),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: sizes.map((size) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: context.border),
                      ),
                      child: Text(
                        size,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions(BuildContext context, Color accentColor) {
    final isIOS = Platform.isIOS;
    final steps = isIOS
        ? [
            _InstructionStep(
              number: 1,
              title: 'Long press on home screen',
              description: 'Press and hold any empty area until apps jiggle',
            ),
            _InstructionStep(
              number: 2,
              title: 'Tap the + button',
              description: 'Located in the top-left corner',
            ),
            _InstructionStep(
              number: 3,
              title: 'Search for "Socialmesh"',
              description: 'Or scroll to find our widgets',
            ),
            _InstructionStep(
              number: 4,
              title: 'Choose a widget size',
              description: 'Swipe to see available sizes, tap "Add Widget"',
            ),
            _InstructionStep(
              number: 5,
              title: 'Position and tap Done',
              description: 'Drag to your preferred location',
            ),
          ]
        : [
            _InstructionStep(
              number: 1,
              title: 'Long press on home screen',
              description: 'Press and hold any empty area',
            ),
            _InstructionStep(
              number: 2,
              title: 'Tap "Widgets"',
              description: 'From the menu that appears',
            ),
            _InstructionStep(
              number: 3,
              title: 'Search for "Socialmesh"',
              description: 'Or scroll to find our widgets',
            ),
            _InstructionStep(
              number: 4,
              title: 'Long press and drag',
              description: 'Hold the widget and place it on your home screen',
            ),
          ];

    return Container(
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
              Icon(
                isIOS ? Icons.phone_iphone : Icons.phone_android,
                color: accentColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                isIOS ? 'iOS Instructions' : 'Android Instructions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${step.number}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          step.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection(BuildContext context, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTipRow(
            Icons.refresh,
            'Widgets update automatically when connected',
            accentColor,
          ),
          const SizedBox(height: 12),
          _buildTipRow(
            Icons.wifi_off,
            'Offline data shown when disconnected',
            accentColor,
          ),
          const SizedBox(height: 12),
          _buildTipRow(
            Icons.touch_app,
            'Tap any widget to open the app',
            accentColor,
          ),
          const SizedBox(height: 12),
          _buildTipRow(
            Icons.palette,
            'Widget colors match your accent color',
            accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text, Color accentColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentColor.withValues(alpha: 0.7)),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _InstructionStep {
  final int number;
  final String title;
  final String description;

  _InstructionStep({
    required this.number,
    required this.title,
    required this.description,
  });
}
