// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

/// Icon category for organization
class IconCategory {
  final String name;
  final List<IconOption> icons;

  const IconCategory({required this.name, required this.icons});
}

/// Individual icon option with display name
class IconOption {
  final String name;
  final String displayName;
  final IconData icon;

  const IconOption({
    required this.name,
    required this.displayName,
    required this.icon,
  });
}

/// Selector for choosing Material icons with visual preview
class IconSelector extends StatefulWidget {
  final String? selectedIcon;
  final ValueChanged<String> onSelected;

  const IconSelector({super.key, this.selectedIcon, required this.onSelected});

  /// Show the icon selector as a bottom sheet
  static Future<String?> show({
    required BuildContext context,
    String? selectedIcon,
  }) {
    return AppBottomSheet.showScrollable<String>(
      context: context,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (scrollController) => _IconSelectorContent(
        selectedIcon: selectedIcon,
        scrollController: scrollController,
      ),
    );
  }

  @override
  State<IconSelector> createState() => _IconSelectorState();
}

class _IconSelectorState extends State<IconSelector> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _IconSelectorContent extends StatefulWidget {
  final String? selectedIcon;
  final ScrollController scrollController;

  const _IconSelectorContent({
    this.selectedIcon,
    required this.scrollController,
  });

  @override
  State<_IconSelectorContent> createState() => _IconSelectorContentState();
}

class _IconSelectorContentState extends State<_IconSelectorContent> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _categories = [
    IconCategory(
      name: 'Status',
      icons: [
        IconOption(
          name: 'check_circle',
          displayName: 'Check',
          icon: Icons.check_circle,
        ),
        IconOption(
          name: 'warning',
          displayName: 'Warning',
          icon: Icons.warning,
        ),
        IconOption(name: 'error', displayName: 'Error', icon: Icons.error),
        IconOption(name: 'info', displayName: 'Info', icon: Icons.info),
        IconOption(
          name: 'help_outline',
          displayName: 'Help',
          icon: Icons.help_outline,
        ),
      ],
    ),
    IconCategory(
      name: 'Battery & Power',
      icons: [
        IconOption(
          name: 'battery_full',
          displayName: 'Full',
          icon: Icons.battery_full,
        ),
        IconOption(
          name: 'battery_alert',
          displayName: 'Alert',
          icon: Icons.battery_alert,
        ),
        IconOption(
          name: 'battery_charging_full',
          displayName: 'Charging',
          icon: Icons.battery_charging_full,
        ),
        IconOption(name: 'bolt', displayName: 'Power', icon: Icons.bolt),
      ],
    ),
    IconCategory(
      name: 'Connectivity',
      icons: [
        IconOption(
          name: 'signal_cellular_alt',
          displayName: 'Signal',
          icon: Icons.signal_cellular_alt,
        ),
        IconOption(name: 'wifi', displayName: 'WiFi', icon: Icons.wifi),
        IconOption(
          name: 'bluetooth',
          displayName: 'Bluetooth',
          icon: Icons.bluetooth,
        ),
        IconOption(name: 'hub', displayName: 'Hub', icon: Icons.hub),
        IconOption(name: 'router', displayName: 'Router', icon: Icons.router),
        IconOption(
          name: 'devices',
          displayName: 'Devices',
          icon: Icons.devices,
        ),
        IconOption(name: 'lan', displayName: 'Network', icon: Icons.lan),
      ],
    ),
    IconCategory(
      name: 'Location & Maps',
      icons: [
        IconOption(
          name: 'gps_fixed',
          displayName: 'GPS',
          icon: Icons.gps_fixed,
        ),
        IconOption(name: 'map', displayName: 'Map', icon: Icons.map),
        IconOption(
          name: 'navigation',
          displayName: 'Navigate',
          icon: Icons.navigation,
        ),
        IconOption(
          name: 'explore',
          displayName: 'Explore',
          icon: Icons.explore,
        ),
        IconOption(
          name: 'near_me',
          displayName: 'Near Me',
          icon: Icons.near_me,
        ),
        IconOption(
          name: 'location_on',
          displayName: 'Location',
          icon: Icons.location_on,
        ),
        IconOption(name: 'route', displayName: 'Route', icon: Icons.route),
      ],
    ),
    IconCategory(
      name: 'Environment',
      icons: [
        IconOption(
          name: 'thermostat',
          displayName: 'Temperature',
          icon: Icons.thermostat,
        ),
        IconOption(
          name: 'water_drop',
          displayName: 'Humidity',
          icon: Icons.water_drop,
        ),
        IconOption(name: 'air', displayName: 'Air', icon: Icons.air),
        IconOption(name: 'cloud', displayName: 'Cloud', icon: Icons.cloud),
        IconOption(name: 'wb_sunny', displayName: 'Sun', icon: Icons.wb_sunny),
        IconOption(
          name: 'compress',
          displayName: 'Pressure',
          icon: Icons.compress,
        ),
      ],
    ),
    IconCategory(
      name: 'Communication',
      icons: [
        IconOption(
          name: 'message',
          displayName: 'Message',
          icon: Icons.message,
        ),
        IconOption(name: 'chat', displayName: 'Chat', icon: Icons.chat),
        IconOption(name: 'send', displayName: 'Send', icon: Icons.send),
        IconOption(
          name: 'notifications',
          displayName: 'Notification',
          icon: Icons.notifications,
        ),
        IconOption(name: 'call', displayName: 'Call', icon: Icons.call),
      ],
    ),
    IconCategory(
      name: 'Data & Charts',
      icons: [
        IconOption(name: 'speed', displayName: 'Speed', icon: Icons.speed),
        IconOption(
          name: 'timeline',
          displayName: 'Timeline',
          icon: Icons.timeline,
        ),
        IconOption(
          name: 'trending_up',
          displayName: 'Up',
          icon: Icons.trending_up,
        ),
        IconOption(
          name: 'trending_down',
          displayName: 'Down',
          icon: Icons.trending_down,
        ),
        IconOption(
          name: 'show_chart',
          displayName: 'Chart',
          icon: Icons.show_chart,
        ),
        IconOption(
          name: 'analytics',
          displayName: 'Analytics',
          icon: Icons.analytics,
        ),
      ],
    ),
    IconCategory(
      name: 'Actions',
      icons: [
        IconOption(
          name: 'flash_on',
          displayName: 'Flash',
          icon: Icons.flash_on,
        ),
        IconOption(
          name: 'refresh',
          displayName: 'Refresh',
          icon: Icons.refresh,
        ),
        IconOption(
          name: 'settings',
          displayName: 'Settings',
          icon: Icons.settings,
        ),
        IconOption(name: 'edit', displayName: 'Edit', icon: Icons.edit),
        IconOption(name: 'delete', displayName: 'Delete', icon: Icons.delete),
        IconOption(name: 'add', displayName: 'Add', icon: Icons.add),
        IconOption(name: 'remove', displayName: 'Remove', icon: Icons.remove),
      ],
    ),
    IconCategory(
      name: 'Favorites',
      icons: [
        IconOption(
          name: 'favorite',
          displayName: 'Heart',
          icon: Icons.favorite,
        ),
        IconOption(name: 'star', displayName: 'Star', icon: Icons.star),
        IconOption(
          name: 'bookmark',
          displayName: 'Bookmark',
          icon: Icons.bookmark,
        ),
        IconOption(
          name: 'thumb_up',
          displayName: 'Thumbs Up',
          icon: Icons.thumb_up,
        ),
      ],
    ),
  ];

  List<IconOption> get _filteredIcons {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return [];

    final results = <IconOption>[];
    for (final category in _categories) {
      for (final icon in category.icons) {
        if (icon.name.toLowerCase().contains(query) ||
            icon.displayName.toLowerCase().contains(query)) {
          results.add(icon);
        }
      }
    }
    return results;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Select Icon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),

          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search icons...',
              hintStyle: TextStyle(color: context.textSecondary),
              prefixIcon: Icon(
                Icons.search,
                color: context.textSecondary,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: context.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: context.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults(accentColor)
                : _buildCategoryList(accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(Color accentColor) {
    final results = _filteredIcons;
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: context.textSecondary),
            SizedBox(height: 8),
            Text(
              'No icons found',
              style: TextStyle(color: context.textSecondary),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: widget.scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) =>
          _buildIconTile(results[index], accentColor),
    );
  }

  Widget _buildCategoryList(Color accentColor) {
    return ListView.builder(
      controller: widget.scrollController,
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: category.icons.length,
              itemBuilder: (context, iconIndex) =>
                  _buildIconTile(category.icons[iconIndex], accentColor),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildIconTile(IconOption option, Color accentColor) {
    final isSelected = widget.selectedIcon == option.name;

    return Tooltip(
      message: option.displayName,
      child: InkWell(
        onTap: () => Navigator.pop(context, option.name),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.2)
                : context.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? accentColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                option.icon,
                size: 24,
                color: isSelected ? accentColor : context.textSecondary,
              ),
              SizedBox(height: 4),
              Text(
                option.displayName,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? accentColor : context.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
