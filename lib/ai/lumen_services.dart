import '../data/app_store.dart';
import 'chat_session.dart';
import 'context_builder.dart';
import 'lumen_engine.dart';
import 'lumen_state.dart';
import 'model_manager.dart';

/// Bundle de las dependencias de Lumen, creadas en `main.dart` y propagadas
/// como un solo prop por el árbol de widgets (en lugar de cinco).
///
/// La construcción del [LumenChatSession] se hace lazy porque solo tiene
/// sentido cuando el engine ya está cargado.
class LumenServices {
  LumenServices({required AppStore store})
      : state = LumenState(),
        _contextBuilder = LumenContextBuilder(store),
        _internal = _Internal() {
    modelManager = LumenModelManager(state);
    engine = LumenEngine(state: state, modelManager: modelManager);
  }

  final LumenState state;
  late final LumenModelManager modelManager;
  late final LumenEngine engine;
  final LumenContextBuilder _contextBuilder;
  final _Internal _internal;

  /// Devuelve la sesión de chat actual o crea una nueva si todavía no existe.
  /// Tirar la sesión limpia el historial (ver [clearSession]).
  LumenChatSession get session {
    return _internal.session ??=
        LumenChatSession(engine, contextBuilder: _contextBuilder);
  }

  Future<void> clearSession() async {
    if (_internal.session != null) {
      await _internal.session!.clear();
      _internal.session!.dispose();
      _internal.session = null;
    }
  }
}

class _Internal {
  LumenChatSession? session;
}
