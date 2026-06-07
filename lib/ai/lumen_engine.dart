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

  // 4096 deja ~3.5K tokens libres tras inyectar el preamble (~600 tokens) y
  // la KB completa (~2.5K tokens). Suficiente para una conversación corta.
  // Subirlo a 8192 si el usuario reporta truncamiento del contexto.
  static const int _maxTokens = 4096;

  final LumenState _state;
  final LumenModelManager _modelManager;

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _initialized = false;

  bool get isLoaded => _model != null && _chat != null;

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
      _chat = await _model!.createChat();

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
  Future<void> resetConversation() async {
    if (_model == null) return;
    _chat = await _model!.createChat();
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
