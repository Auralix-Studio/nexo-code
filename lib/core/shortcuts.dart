import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

enum AppShortcutType {
  schedule('action_schedule'),
  grades('action_grades'),
  payments('action_payments');

  final String id;
  const AppShortcutType(this.id);

  static AppShortcutType? fromId(String id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

class ShortcutService extends ChangeNotifier {
  static final ShortcutService instance = ShortcutService._();
  ShortcutService._();

  final QuickActions _quickActions = const QuickActions();
  AppShortcutType? _pendingAction;

  AppShortcutType? get pendingAction => _pendingAction;

  void init() {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    _quickActions.initialize((String shortcutType) {
      final type = AppShortcutType.fromId(shortcutType);
      if (type != null) {
        _pendingAction = type;
        notifyListeners();
      }
    });

    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_schedule',
        localizedTitle: 'Horario',
        icon: 'ic_schedule',
      ),
      const ShortcutItem(
        type: 'action_grades',
        localizedTitle: 'Notas',
        icon: 'ic_grades',
      ),
      const ShortcutItem(
        type: 'action_payments',
        localizedTitle: 'Pagos',
        icon: 'ic_payments',
      ),
    ]);
  }

  void consume() {
    _pendingAction = null;
  }
}
