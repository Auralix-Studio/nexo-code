import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'lumen_state.dart';
import 'model_manager.dart';

/// Singleton wrapper sobre `flutter_gemma` para Lumen.
///
/// Responsabilidades: cargar el .task en memoria, mantener una sola
/// [InferenceChat] por sesión, liberar RAM con [unload]. No formatea
/// prompts ni gestiona historial UI — eso vive en [LumenChatSession].
class LumenEngine {
  LumenEngine({
    required LumenState state,
    required LumenModelManager modelManager,
    List<Tool> tools = const [],
    Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> args)?
        toolExecutor,
  })  : _state = state,
        _modelManager = modelManager,
        _tools = tools,
        _toolExecutor = toolExecutor;

  /// Flag maestro de tool-calling. **Default false**: hasta que el modelo
  /// entrenado emita function calls de forma fiable, Lumen sigue con la
  /// pre-inyección de datos (más robusta para modelos chicos). Cuando el
  /// modelo soporte tools, poné esto en `true`.
  static const bool useTools = false;

  // Ventana de contexto. 4096 cubre preámbulo + KB chico + pregunta corta.
  static const int _maxTokens = 4096;

  /// Máximo de rondas tool→resultado→modelo por turno (evita loops infinitos
  /// si el modelo sigue pidiendo herramientas sin converger a una respuesta).
  static const int _maxToolRounds = 4;

  // Sampling único — usado tanto en load() como en resetConversation().
  // Greedy puro: con temp=0 + topK=1 el 270M nunca entra en loops de
  // `**\n\n**\n\n**`. Sampling estocástico (temp>0) lo rompía a partir
  // del segundo turno, que era cuando `resetConversation` creaba un chat
  // nuevo con parámetros distintos a los de load(). Ahora son los mismos.
  static const double _temperature = 0.0;
  static const int _topK = 1;

  // Si la carga del modelo no termina en 60s asumimos que se colgó
  // (visto con .task corruptos o presión de memoria extrema). Mejor
  // fallar visible que dejar la UI en "cargando…" para siempre.
  static const Duration _loadTimeout = Duration(seconds: 60);

  final LumenState _state;
  final LumenModelManager _modelManager;
  final List<Tool> _tools;
  final Future<Map<String, dynamic>> Function(
      String name, Map<String, dynamic> args)? _toolExecutor;

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _initialized = false;

  bool get isLoaded => _model != null && _chat != null;

  /// ¿Está activo el modo tool-calling? Requiere el flag + tools + ejecutor.
  bool get toolsEnabled =>
      useTools && _tools.isNotEmpty && _toolExecutor != null;

  String get activeModelId => _state.activeModel.id;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await FlutterGemma.initialize();
    _initialized = true;
  }

  Future<InferenceChat> _newChat() {
    return _model!.createChat(
      temperature: _temperature,
      topK: _topK,
      modelType: ModelType.gemmaIt,
      tools: toolsEnabled ? _tools : const [],
      supportsFunctionCalls: toolsEnabled,
    );
  }

  /// Carga el modelo en memoria. No-op si ya está cargado.
  Future<void> load() async {
    if (isLoaded) return;
    if (!await _modelManager.isDownloaded()) {
      throw StateError('Modelo no descargado. Llamar download() primero.');
    }
    _state.setStatus(LumenStatus.loading);
    try {
      await _doLoad().timeout(_loadTimeout);
      _state.setStatus(LumenStatus.loaded);
    } on TimeoutException {
      await _hardReset();
      _state.setStatus(
        LumenStatus.error,
        error: 'La carga tardó demasiado. Probá reiniciar la app o '
            're-descargar el modelo desde Configuración → Lumen.',
      );
      rethrow;
    } catch (e) {
      await _hardReset();
      _state.setStatus(LumenStatus.error, error: 'No se pudo cargar: $e');
      rethrow;
    }
  }

  Future<void> _doLoad() async {
    await _ensureInitialized();
    final path = await _modelManager.modelPath();

    // Validación de tamaño contra spec — barato (un stat) y atrapa el
    // modo de corrupción más común (descarga interrumpida que dejó el
    // archivo con bytes faltantes). El SHA-256 completo ya se valida en
    // download(); aquí evitamos cargar basura que igual va a fallar.
    final f = File(path);
    final actual = await f.length();
    final spec = _state.activeModel;
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final expected = spec.artifactFor(isDesktop: isDesktop).sizeBytes;
    if (actual != expected) {
      // Borrar para forzar re-descarga en el próximo flujo.
      try { await f.delete(); } catch (_) {}
      throw StateError(
        'Modelo corrupto (tamaño $actual vs esperado $expected). '
        'Lo borré — vuelve a descargarlo desde Configuración → Lumen.',
      );
    }

    await FlutterGemma
        .installModel(modelType: ModelType.gemmaIt)
        .fromFile(path)
        .install();

    _model = await FlutterGemma.getActiveModel(maxTokens: _maxTokens);
    _chat = await _newChat();
  }

  /// Stream de tokens parciales de la respuesta del modelo a [userMessage].
  ///
  /// Con [toolsEnabled] corre un loop tool-calling: si el modelo emite un
  /// [FunctionCallResponse], ejecuta la herramienta, reenvía el resultado y
  /// vuelve a generar — hasta [_maxToolRounds] rondas o hasta que el modelo
  /// produzca texto final. Sin tools, es un único pase (comportamiento previo).
  Stream<String> respond(String userMessage) async* {
    final chat = _chat;
    if (chat == null) {
      throw StateError('Engine no cargado. Llamar load() primero.');
    }

    if (!toolsEnabled) {
      await chat.addQuery(Message.text(text: userMessage, isUser: true));
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          yield response.token;
        } else {
          debugPrint('[LumenEngine] non-text response: ${response.runtimeType}');
        }
      }
      return;
    }

    // ── Modo tool-calling ──
    Message next = Message.text(text: userMessage, isUser: true);
    for (var round = 0; round < _maxToolRounds; round++) {
      await chat.addQuery(next);

      FunctionCallResponse? call;
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          yield response.token;
        } else if (response is FunctionCallResponse) {
          call = response;
          break; // ejecutar la herramienta y reenviar el resultado
        } else {
          debugPrint('[LumenEngine] otra respuesta: ${response.runtimeType}');
        }
      }

      if (call == null) return; // el modelo dio su respuesta final en texto

      Map<String, dynamic> result;
      try {
        result = await _toolExecutor!(call.name, call.args);
      } catch (e) {
        result = {'error': e.toString()};
      }
      next = Message.toolResponse(toolName: call.name, response: result);
    }
    // Tope de rondas alcanzado: el modelo siguió pidiendo herramientas sin
    // converger. Mejor cerrar el turno que quedar en loop.
    debugPrint('[LumenEngine] tool loop alcanzó $_maxToolRounds rondas');
  }

  Future<void> stop() async {
    try {
      await _chat?.session.stopGeneration();
    } catch (e) {
      debugPrint('[LumenEngine] stop falló: $e');
    }
  }

  /// Tira el historial y crea un chat nuevo con los MISMOS parámetros de
  /// sampling que load(). Antes esta función usaba temp=0.7/topK=40 que
  /// hacía colapsar al 270M en loops; ahora delega en [_newChat].
  Future<void> resetConversation() async {
    if (_model == null) return;
    _chat = await _newChat();
  }

  Future<void> unload() async {
    await _hardReset();
    if (_state.status == LumenStatus.loaded) {
      _state.setStatus(LumenStatus.ready);
    }
  }

  Future<void> _hardReset() async {
    try { await _model?.close(); } catch (_) {}
    _model = null;
    _chat = null;
  }
}
