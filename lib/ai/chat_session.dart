import 'package:flutter/foundation.dart';

import 'lumen_engine.dart';

/// Origen de un mensaje en la conversación.
enum ChatRole { user, lumen }

/// Mensaje de chat para la UI. Inmutable salvo por el contenido del último
/// mensaje de Lumen mientras está siendo streameado.
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.isStreaming = false,
  }) : timestamp = timestamp ?? DateTime.now();

  final ChatRole role;
  String text;
  final DateTime timestamp;
  bool isStreaming;
}

/// Historial de chat de una sesión + orquestación de envíos al [LumenEngine].
///
/// Es lo que la UI escucha (extends [ChangeNotifier]). El engine se inyecta
/// para poder testear con un fake. El historial vive en memoria: si el user
/// cierra la app, se pierde (decisión consciente de v1; sqlite en v2).
class LumenChatSession extends ChangeNotifier {
  LumenChatSession(this._engine);

  final LumenEngine _engine;
  final List<ChatMessage> _messages = [];
  bool _busy = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isBusy => _busy;

  /// Envía [text] del usuario, encola un mensaje vacío de Lumen y lo va
  /// rellenando con cada token del stream.
  ///
  /// Si ya hay un envío en curso, lanza [StateError] — la UI debería
  /// desactivar el botón hasta que `isBusy = false`.
  Future<void> send(String text) async {
    if (_busy) {
      throw StateError('Ya hay una respuesta en curso.');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _messages.add(ChatMessage(role: ChatRole.user, text: trimmed));
    final pending = ChatMessage(
      role: ChatRole.lumen,
      text: '',
      isStreaming: true,
    );
    _messages.add(pending);
    _busy = true;
    notifyListeners();

    try {
      await for (final token in _engine.respond(trimmed)) {
        pending.text += token;
        notifyListeners();
      }
    } catch (e) {
      pending.text = pending.text.isEmpty
          ? 'Lumen no pudo responder: $e'
          : '${pending.text}\n\n[interrumpido: $e]';
    } finally {
      pending.isStreaming = false;
      _busy = false;
      notifyListeners();
    }
  }

  /// Para la generación en curso (si está streamando).
  Future<void> stop() async {
    if (!_busy) return;
    await _engine.stop();
  }

  /// Limpia el historial visible y el contexto del engine.
  Future<void> clear() async {
    await _engine.resetConversation();
    _messages.clear();
    _busy = false;
    notifyListeners();
  }
}
