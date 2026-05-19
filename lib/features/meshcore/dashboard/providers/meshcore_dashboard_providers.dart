// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meshcore_dashboard_widget_config.dart';

// SharedPreferences storage key. Protocol-scoped so MeshCore widget
// state never collides with the Meshtastic dashboard's `dashboard_widgets`
// key.
const String _kMeshCoreDashboardWidgetsKey = 'meshcore_dashboard_widgets';

final meshCoreDashboardWidgetsProvider =
    NotifierProvider<
      MeshCoreDashboardWidgetsNotifier,
      List<MeshCoreDashboardWidgetConfig>
    >(MeshCoreDashboardWidgetsNotifier.new);

class MeshCoreDashboardEditModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setEditMode(bool value) => state = value;
}

final meshCoreDashboardEditModeProvider =
    NotifierProvider<MeshCoreDashboardEditModeNotifier, bool>(
      MeshCoreDashboardEditModeNotifier.new,
    );

class MeshCoreDashboardWidgetsNotifier
    extends Notifier<List<MeshCoreDashboardWidgetConfig>> {
  static const int maxWidgets = 20;

  @override
  List<MeshCoreDashboardWidgetConfig> build() {
    _loadWidgets();
    return [];
  }

  Future<void> _loadWidgets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_kMeshCoreDashboardWidgetsKey);

    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        state = jsonList
            .map(
              (e) => MeshCoreDashboardWidgetConfig.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList();
      } catch (_) {
        state = _getDefaultWidgets();
        _saveWidgets();
      }
    } else {
      state = _getDefaultWidgets();
      _saveWidgets();
    }
  }

  List<MeshCoreDashboardWidgetConfig> _getDefaultWidgets() {
    return const [
      MeshCoreDashboardWidgetConfig(
        id: 'meshcore_network_overview_1',
        type: MeshCoreDashboardWidgetType.networkOverview,
        order: 0,
        isFavorite: true,
      ),
      MeshCoreDashboardWidgetConfig(
        id: 'meshcore_quick_actions_1',
        type: MeshCoreDashboardWidgetType.quickActions,
        order: 1,
      ),
      MeshCoreDashboardWidgetConfig(
        id: 'meshcore_nearby_contacts_1',
        type: MeshCoreDashboardWidgetType.nearbyContacts,
        order: 2,
      ),
      MeshCoreDashboardWidgetConfig(
        id: 'meshcore_recent_messages_1',
        type: MeshCoreDashboardWidgetType.recentMessages,
        order: 3,
      ),
    ];
  }

  Future<void> _saveWidgets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_kMeshCoreDashboardWidgetsKey, jsonString);
  }

  void addWidget(MeshCoreDashboardWidgetType type) {
    if (state.length >= maxWidgets) return;
    final info = MeshCoreWidgetRegistry.getInfo(type);
    final newWidget = MeshCoreDashboardWidgetConfig(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      size: info.defaultSize,
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
    final index = state.indexWhere((w) => w.id == id);
    if (index == -1) return;

    final widget = state[index];
    final newIsFavorite = !widget.isFavorite;

    if (newIsFavorite) {
      // Favoriting hoists the widget to the top so the favorite cluster
      // always reads top-down on the dashboard.
      final widgets = List<MeshCoreDashboardWidgetConfig>.from(state);
      widgets.removeAt(index);
      widgets.insert(0, widget.copyWith(isFavorite: true));
      state = widgets.asMap().entries.map((e) {
        return e.value.copyWith(order: e.key);
      }).toList();
    } else {
      // Un-favoriting keeps current position; only the flag toggles.
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
    final widgets = List<MeshCoreDashboardWidgetConfig>.from(state);
    final widget = widgets.removeAt(oldIndex);
    widgets.insert(newIndex, widget);

    state = widgets.asMap().entries.map((e) {
      return e.value.copyWith(order: e.key);
    }).toList();
    _saveWidgets();
  }

  void changeSize(String id, MeshCoreWidgetSize size) {
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
