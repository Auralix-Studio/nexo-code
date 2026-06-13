import '../core/config.dart';
import '../core/storage.dart';
import '../data/app_store.dart';
import 'chat_session.dart';
import 'context_builder.dart';
import 'lumen_engine.dart';
import 'lumen_state.dart';
import 'lumen_tools.dart';
import 'model_manager.dart';

/// Bundle de las dependencias de Lumen, creadas en `main.dart` y propagadas
/// como un solo prop por el árbol de widgets (en lugar de cinco).
///
/// La construcción del [LumenChatSession] se hace lazy porque solo tiene
/// sentido cuando el engine ya está cargado.
class LumenServices {
  LumenServices({required AppStore store, required AppStorage storage})
      : _storage = storage,
        state = LumenState(
          initialModel: LumenConfig.byId(storage.lumenModelId),
        ),
        _contextBuilder = LumenContextBuilder(store),
        _internal = _Internal() {
    modelManager = LumenModelManager(state);
    final tools = LumenTools(store);
    engine = LumenEngine(
      state: state,
      modelManager: modelManager,
      // Definiciones siempre disponibles; el engine solo las usa si
      // `LumenEngine.useTools` está activo (ver flag).
      tools: LumenTools.definitions,
      toolExecutor: tools.execute,
    );
  }

  final AppStorage _storage;
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

  /// Cambia el modelo activo y persiste la elección.
  ///
  /// Si el modelo nuevo es distinto al actual y había uno cargado en RAM,
  /// descarga el engine para forzar una recarga limpia con la nueva spec
  /// en el próximo uso. NO toca el archivo del modelo viejo en disco —
  /// el caller decide si lo borra (ver [LumenModelManager.delete]).
  Future<void> switchModel(LumenModelSpec model) async {
    if (state.activeModel.id == model.id) return;
    await engine.unload();
    await clearSession();
    state.setActiveModel(model);
    await _storage.setLumenModelId(model.id);
    state.reset();
  }
}

class _Internal {
  LumenChatSession? session;
}
