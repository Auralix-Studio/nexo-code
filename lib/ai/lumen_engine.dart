import 'package:flutter_gemma/flutter_gemma.dart';

import 'lumen_state.dart';
import 'model_manager.dart';

/// Singleton wrapper sobre `flutter_gemma` para Lumen.
///
/// Responsabilidades:
/// - Cargar el .task descargado en memoria (delega en MediaPipe LLM Inference).
/// - Mantener una única [InferenceChat] reutilizable por sesión de app.
/// - Liberar memoria con [unload] cuando el usuario desactive Lumen o cierre
///   pantalla.
///
/// No formatea prompts ni gestiona historial UI — eso vive en
/// [LumenChatSession]. Aquí solo está el motor crudo.
class LumenEngine {
  LumenEngine({
    required LumenState state,
    required LumenModelManager modelManager,
  })  : _state = state,
        _modelManager = modelManager;

  // Ventana de contexto en runtime. Tradeoff: más tokens = más RAM pero
  // permite preámbulos largos + historial. 4096 alcanza para datos del
  // estudiante + pregunta corta + respuesta. El KB de la variante Estándar
  // se inyecta entera pero solo en el 1B (que la procesa bien).
  static const int _maxTokens = 4096;

  final LumenState _state;
  final LumenModelManager _modelManager;

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _initialized = false;

  bool get isLoaded => _model != null && _chat != null;

  /// Id del modelo actualmente cargado en RAM (`_state.activeModel.id`).
  /// Lo expone para que el context builder pueda variar el preamble.
  String get activeModelId => _state.activeModel.id;

  /// Inicializa el plugin de flutter_gemma (una sola vez por proceso).
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await FlutterGemma.initialize();
    _initialized = true;
  }

  /// Carga el modelo en memoria. No-op si ya está cargado.
  ///
  /// Lanza [StateError] si el .task no está en disco — el caller debe haber
  /// corrido [LumenModelManager.download] antes.
  Future<void> load() async {
    if (isLoaded) return;

    if (!await _modelManager.isDownloaded()) {
      throw StateError('Modelo no descargado. Llamar download() primero.');
    }

    _state.setStatus(LumenStatus.loading);
    try {
      await _ensureInitialized();
      final path = await _modelManager.modelPath();

      await FlutterGemma
          .installModel(modelType: ModelType.gemmaIt)
          .fromFile(path)
          .install();

      _model = await FlutterGemma.getActiveModel(maxTokens: _maxTokens);

      // Sampling: temperature 0.7 + topK 40 + topP 0.95 = preset estándar
      // para modelos chicos (Gemma small / Phi small). El default del
      // paquete (temp 0.8, topK 1) hace decoding casi greedy que produce
      // outputs vacíos o repetitivos con prompts complejos en el 270M.
      _chat = await _model!.createChat(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        modelType: ModelType.gemmaIt,
      );

      _state.setStatus(LumenStatus.loaded);
    } catch (e) {
      _state.setStatus(LumenStatus.error, error: 'No se pudo cargar: $e');
      rethrow;
    }
  }

  /// Envía [userMessage] y devuelve un stream de tokens parciales.
  /// La concatenación de todos los tokens es la respuesta completa.
  ///
  /// El historial entre llamadas se mantiene en la [InferenceChat] interna.
  /// Para reiniciar el contexto, llamar [resetConversation].
  Stream<String> respond(String userMessage) async* {
    final chat = _chat;
    if (chat == null) {
      throw StateError('Engine no cargado. Llamar load() primero.');
    }

    await chat.addQuery(Message.text(text: userMessage, isUser: true));

    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) {
        yield response.token;
      }
    }
  }

  /// Pide al motor que pare la generación en curso (si está streamando).
  Future<void> stop() async {
    await _chat?.session.stopGeneration();
  }

  /// Tira el historial de chat y crea uno nuevo sin descargar el modelo.
  /// Mantiene los mismos parámetros de sampling que [load].
  Future<void> resetConversation() async {
    if (_model == null) return;
    _chat = await _model!.createChat(
      temperature: 0.7,
      topK: 40,
      topP: 0.95,
      modelType: ModelType.gemmaIt,
    );
  }

  /// Descarga el modelo de la RAM. El .task sigue en disco.
  Future<void> unload() async {
    await _model?.close();
    _model = null;
    _chat = null;
    if (_state.status == LumenStatus.loaded) {
      _state.setStatus(LumenStatus.ready);
    }
  }
}
