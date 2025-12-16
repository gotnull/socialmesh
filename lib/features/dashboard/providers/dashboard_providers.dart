import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_widget_config.dart';

/// Provider for dashboard widget configurations
final dashboardWidgetsProvider =
    NotifierProvider<DashboardWidgetsNotifier, List<DashboardWidgetConfig>>(
      DashboardWidgetsNotifier.new,
    );

/// Edit mode notifier for the dashboard
class DashboardEditModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setEditMode(bool value) => state = value;
}

/// Edit mode state for the dashboard
final dashboardEditModeProvider =
    NotifierProvider<DashboardEditModeNotifier, bool>(
      DashboardEditModeNotifier.new,
    );

/// Notifier to manage dashboard widget configurations
class DashboardWidgetsNotifier extends Notifier<List<DashboardWidgetConfig>> {
  static const String _storageKey = 'dashboard_widgets';

  @override
  List<DashboardWidgetConfig> build() {
    _loadWidgets();
    return [];
  }

  Future<void> _loadWidgets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        state = jsonList
            .map(
              (e) => DashboardWidgetConfig.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      } catch (e) {
        // If loading fails, use defaults
        state = _getDefaultWidgets();
        _saveWidgets();
      }
    } else {
      // First time - use default widgets
      state = _getDefaultWidgets();
      _saveWidgets();
    }
  }

  List<DashboardWidgetConfig> _getDefaultWidgets() {
    return [
      DashboardWidgetConfig(
        id: 'network_overview_1',
        type: DashboardWidgetType.networkOverview,
        size: WidgetSize.medium,
        order: 0,
        isFavorite: true,
      ),
      DashboardWidgetConfig(
        id: 'signal_strength_1',
        type: DashboardWidgetType.signalStrength,
        size: WidgetSize.large,
        order: 1,
        isFavorite: true,
      ),
      DashboardWidgetConfig(
        id: 'recent_messages_1',
        type: DashboardWidgetType.recentMessages,
        size: WidgetSize.medium,
        order: 2,
      ),
      DashboardWidgetConfig(
        id: 'nearby_nodes_1',
        type: DashboardWidgetType.nearbyNodes,
        size: WidgetSize.medium,
        order: 3,
      ),
    ];
  }

  Future<void> _saveWidgets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  void addWidget(DashboardWidgetType type) {
    final info = WidgetRegistry.getInfo(type);
    final newWidget = DashboardWidgetConfig(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      size: info.defaultSize,
      order: state.length,
    );
    state = [...state, newWidget];
    _saveWidgets();
  }

  /// Add a custom widget configuration (for schema-based widgets)
  void addCustomWidget(DashboardWidgetConfig config) {
    final newWidget = config.copyWith(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      order: state.length,
    );
    state = [...state, newWidget];
    _saveWidgets();
  }

  void removeWidget(String id) {
    state = state.where((w) => w.id != id).toList();
    _reorderAfterRemoval();
    _saveWidgets();
  }

  void toggleFavorite(String id) {
    // Find the widget
    final index = state.indexWhere((w) => w.id == id);
    if (index == -1) return;

    final widget = state[index];
    final newIsFavorite = !widget.isFavorite;

    if (newIsFavorite) {
      // Moving to favorites: move to top of list
      final widgets = List<DashboardWidgetConfig>.from(state);
      widgets.removeAt(index);
      widgets.insert(0, widget.copyWith(isFavorite: true));

      // Update order values
      state = widgets.asMap().entries.map((e) {
        return e.value.copyWith(order: e.key);
      }).toList();
    } else {
      // Removing from favorites: keep position but toggle flag
      state = state.map((w) {
        if (w.id == id) {
          return w.copyWith(isFavorite: false);
        }
        return w;
      }).toList();
    }
    _saveWidgets();
  }

  void toggleVisibility(String id) {
    state = state.map((w) {
      if (w.id == id) {
        return w.copyWith(isVisible: !w.isVisible);
      }
      return w;
    }).toList();
    _saveWidgets();
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final widgets = List<DashboardWidgetConfig>.from(state);
    final widget = widgets.removeAt(oldIndex);
    widgets.insert(newIndex, widget);

    // Update order values
    state = widgets.asMap().entries.map((e) {
      return e.value.copyWith(order: e.key);
    }).toList();
    _saveWidgets();
  }

  void changeSize(String id, WidgetSize size) {
    state = state.map((w) {
      if (w.id == id) {
        return w.copyWith(size: size);
      }
      return w;
    }).toList();
    _saveWidgets();
  }

  void _reorderAfterRemoval() {
    state = state.asMap().entries.map((e) {
      return e.value.copyWith(order: e.key);
    }).toList();
  }

  void resetToDefaults() {
    state = _getDefaultWidgets();
    _saveWidgets();
  }
}
