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
  })  : _state = state,
        _modelManager = modelManager;

  // Ventana de contexto. 4096 cubre preámbulo + KB chico + pregunta corta.
  static const int _maxTokens = 4096;

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

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _initialized = false;

  bool get isLoaded => _model != null && _chat != null;

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
  Stream<String> respond(String userMessage) async* {
    final chat = _chat;
    if (chat == null) {
      throw StateError('Engine no cargado. Llamar load() primero.');
    }

    await chat.addQuery(Message.text(text: userMessage, isUser: true));

    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) {
        yield response.token;
      } else {
        // Otros tipos (function calls, metadata) no se forwarean como
        // tokens — pero los logueamos para no perderlos silenciosamente
        // si algún día el modelo empieza a emitirlos.
        debugPrint('[LumenEngine] non-text response: ${response.runtimeType}');
      }
    }
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
