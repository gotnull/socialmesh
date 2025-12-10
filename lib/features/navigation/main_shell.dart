import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/animations.dart';
import '../../providers/app_providers.dart';
import '../../services/haptic_service.dart';
import '../channels/channels_screen.dart';
import '../messaging/messaging_screen.dart';
import '../nodes/nodes_screen.dart';
import '../map/map_screen.dart';
import '../dashboard/widget_dashboard_screen.dart';
import '../scanner/scanner_screen.dart';
import '../device/region_selection_screen.dart';

/// Main navigation shell with bottom navigation bar
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 3; // Start on Nodes tab

  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.wifi_tethering_outlined,
      activeIcon: Icons.wifi_tethering,
      label: 'Channels',
    ),
    _NavItem(
      icon: Icons.message_outlined,
      activeIcon: Icons.message,
      label: 'Messages',
    ),
    _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map'),
    _NavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Nodes',
    ),
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
  ];

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const ChannelsScreen();
      case 1:
        return const MessagingScreen();
      case 2:
        return const MapScreen();
      case 3:
        return const NodesScreen();
      case 4:
        return const WidgetDashboardScreen();
      default:
        return const ChannelsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final autoReconnectState = ref.watch(autoReconnectStateProvider);
    final settingsAsync = ref.watch(settingsServiceProvider);

    // Auto-reconnect and live activity managers are now watched at app level in main.dart

    // Watch for UNSET region - firmware updates can reset it!
    // BUT only if we haven't already marked region as configured (user set it before)
    // During auto-reconnect, the region might briefly show UNSET before config loads
    final needsRegionSetup = ref.watch(needsRegionSetupProvider);
    final regionConfigured =
        settingsAsync.whenOrNull(
          data: (settings) => settings.regionConfigured,
        ) ??
        false;

    final isConnected = connectionStateAsync.when(
      data: (state) => state == DeviceConnectionState.connected,
      loading: () => false,
      error: (e, s) => false,
    );
    final isReconnecting =
        autoReconnectState == AutoReconnectState.scanning ||
        autoReconnectState == AutoReconnectState.connecting;

    // Check if we need to show the "Connect Device" screen
    // Show it when: not connected AND not reconnecting AND auto-reconnect is disabled
    // This forces manual connection when the user has opted out of auto-reconnect
    final autoReconnectEnabled =
        settingsAsync.whenOrNull(data: (settings) => settings.autoReconnect) ??
        true;

    // Only gate on auto-reconnect if we're genuinely disconnected
    // If connected (even with auto-reconnect disabled), show the main app
    if (!isConnected && !isReconnecting && !autoReconnectEnabled) {
      return const ScannerScreen(isInline: true);
    }

    // If connected but region is UNSET, force region selection
    // This catches firmware updates/resets that clear the region
    // BUT: skip this during auto-reconnect if user already configured region before
    // The device config might not have loaded yet, and we don't want a loop
    if (isConnected && needsRegionSetup && !regionConfigured) {
      debugPrint(
        '⚠️ MainShell: Connected but region is UNSET and not configured - forcing region setup',
      );
      return const RegionSelectionScreen(isInitialSetup: true);
    }

    // Build the main scaffold
    final mainScaffold = Scaffold(
      body: Column(
        children: [
          // Main content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_currentIndex),
                child: _buildScreen(_currentIndex),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = _currentIndex == index;

                // Show warning badge on Device tab (index 4) when disconnected
                final showWarningBadge = index == 4 && !isConnected;
                // Show reconnecting indicator
                final showReconnectingBadge = index == 4 && isReconnecting;
                // Show badge on Nodes tab (index 3) when new nodes discovered
                final showNodesBadge = index == 3 && _hasNewNodes(ref);

                return _NavBarItem(
                  icon: isSelected ? item.activeIcon : item.icon,
                  label: item.label,
                  isSelected: isSelected,
                  showBadge:
                      (index == 1 && _hasUnreadMessages(ref)) || showNodesBadge,
                  showWarningBadge: showWarningBadge && !showReconnectingBadge,
                  showReconnectingBadge: showReconnectingBadge,
                  onTap: () {
                    ref.haptics.tabChange();
                    // Clear new nodes badge when navigating to Nodes tab
                    if (index == 3) {
                      ref.read(newNodesCountProvider.notifier).reset();
                    }
                    setState(() => _currentIndex = index);
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );

    return mainScaffold;
  }

  bool _hasUnreadMessages(WidgetRef ref) {
    return ref.watch(hasUnreadMessagesProvider);
  }

  bool _hasNewNodes(WidgetRef ref) {
    return ref.watch(newNodesCountProvider) > 0;
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool showBadge;
  final bool showWarningBadge;
  final bool showReconnectingBadge;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.showBadge = false,
    this.showWarningBadge = false,
    this.showReconnectingBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine icon color
    final accentColor = theme.colorScheme.primary;
    Color iconColor;
    if (isSelected) {
      iconColor = accentColor;
    } else if (showReconnectingBadge) {
      iconColor = Colors.amber;
    } else if (showWarningBadge) {
      iconColor = Colors.orange;
    } else {
      iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    // Determine label color
    Color labelColor;
    if (isSelected) {
      labelColor = accentColor;
    } else if (showReconnectingBadge) {
      labelColor = Colors.amber;
    } else if (showWarningBadge) {
      labelColor = Colors.orange;
    } else {
      labelColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: AnimatedMorphIcon(
                    icon: icon,
                    size: 24,
                    color: iconColor,
                  ),
                ),
                if (showBadge)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                if (showReconnectingBadge)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: _PulsingDot(color: Colors.amber),
                  )
                else if (showWarningBadge)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: labelColor,
                fontFamily: AppTheme.fontFamily,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).scaffoldBackgroundColor,
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
