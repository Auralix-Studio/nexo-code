part of '../app_store.dart';

/// Orden y tamaño de las tarjetas del inicio, guardados en el dispositivo.
mixin _DashboardStore on _StoreBase {
  static const List<DashboardWidgetConfig> _defaultDashboardLayout = [
    DashboardWidgetConfig(id: 'stats_promedio', span: 2),
    DashboardWidgetConfig(id: 'stats_creditos', span: 2),
    DashboardWidgetConfig(id: 'stats_clases_hoy', span: 2),
    DashboardWidgetConfig(id: 'stats_pagos', span: 2),
    DashboardWidgetConfig(id: 'next_class', span: 4),
    DashboardWidgetConfig(id: 'today_classes', span: 4),
    DashboardWidgetConfig(id: 'pending_payments', span: 4),
  ];
  List<DashboardWidgetConfig> dashboardLayout = [..._defaultDashboardLayout];

  void _loadDashboardLayout() {
    final s = AppStorage.instance.dashboardConfigJson;
    if (s != null) {
      try {
        final list = (jsonDecode(s) as List)
            .map(
              (e) => DashboardWidgetConfig.fromJson(e as Map<String, dynamic>),
            )
            .toList();
        if (list.isNotEmpty) {
          // Migración automática si existe stats_grid
          final i = list.indexWhere((e) => e.id == 'stats_grid');
          if (i >= 0) {
            list.removeAt(i);
            list.insertAll(i, [
              const DashboardWidgetConfig(id: 'stats_promedio', span: 1),
              const DashboardWidgetConfig(id: 'stats_creditos', span: 1),
              const DashboardWidgetConfig(id: 'stats_clases_hoy', span: 1),
              const DashboardWidgetConfig(id: 'stats_pagos', span: 1),
            ]);
          }
          // Toda tarjeta conocida debe estar presente.
          for (final d in _defaultDashboardLayout) {
            if (!list.any((e) => e.id == d.id)) list.add(d);
          }
          for (var i = 0; i < list.length; i++) {
            if (!list[i].id.startsWith('stats_') && list[i].span < 4) {
              list[i] = list[i].copyWith(span: 4);
            }
          }
          dashboardLayout = list;
          return;
        }
      } catch (_) {}
    }
    dashboardLayout = [..._defaultDashboardLayout];
  }

  void saveDashboardLayout() {
    final s = jsonEncode(dashboardLayout.map((e) => e.toJson()).toList());
    AppStorage.instance.setDashboardConfigJson(s);
    _notify();
  }

  String? editingDashboardWidgetId;
  void setEditingDashboardWidget(String? id) {
    editingDashboardWidgetId = id;
    _notify();
  }

  void reorderDashboard(String oldId, String newId, {bool save = true}) {
    final oldIndex = dashboardLayout.indexWhere((w) => w.id == oldId);
    int newIndex = dashboardLayout.indexWhere((w) => w.id == newId);
    if (oldIndex == -1 || newIndex == -1 || oldIndex == newIndex) return;

    final item = dashboardLayout.removeAt(oldIndex);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    dashboardLayout.insert(newIndex, item);

    if (save) saveDashboardLayout();
    _notify();
  }

  void setDashboardWidgetSpan(String id, int span) {
    final i = dashboardLayout.indexWhere((e) => e.id == id);
    if (i >= 0) {
      if (dashboardLayout[i].span != span) {
        dashboardLayout[i] = dashboardLayout[i].copyWith(span: span);
        saveDashboardLayout();
      }
    }
  }
}
