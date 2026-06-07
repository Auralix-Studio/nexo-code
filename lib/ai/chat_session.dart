import 'package:flutter/foundation.dart';

import 'context_builder.dart';
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
/// **Modo single-shot por turno (v1.2).** Cada [send] limpia el chat del
/// engine antes de enviar, construye un prompt fresco con la data
/// relevante para ESA query (via [LumenContextBuilder]) y stream-ea la
/// respuesta. Sin historial multi-turno del lado del modelo — la lista
/// `_messages` que ve la UI es solo cosmética.
///
/// Trade-off: el modelo no recuerda el turno anterior. A cambio: cada
/// respuesta tiene exactamente el contexto que necesita, cero
/// contaminación entre temas, y el budget de tokens nunca se infla.
class LumenChatSession extends ChangeNotifier {
  LumenChatSession(this._engine, {LumenContextBuilder? contextBuilder})
      : _contextBuilder = contextBuilder;

  final LumenEngine _engine;
  final LumenContextBuilder? _contextBuilder;
  final List<ChatMessage> _messages = [];
  bool _busy = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isBusy => _busy;

  /// Envía [text] del usuario. Encola un mensaje vacío de Lumen y lo va
  /// rellenando con cada token del stream. Tira [StateError] si ya hay
  /// un envío en curso.
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

    // Single-shot: limpiar chat anterior y construir prompt fresco
    // específico para esta query.
    try {
      await _engine.resetConversation();
    } catch (e) {
      debugPrint('Lumen: resetConversation falló: $e');
    }

    String prompt;
    if (_contextBuilder != null) {
      try {
        prompt = await _contextBuilder.buildPrompt(
          modelId: _engine.activeModelId,
          userQuery: trimmed,
        );
      } catch (e) {
        debugPrint('Lumen: no se pudo armar el prompt: $e');
        prompt = trimmed;
      }
    } else {
      prompt = trimmed;
    }

    // Detector de runaway: si el modelo entra en mode collapse
    // (`**\n\n**\n\n**` infinito), cortamos.
    const garbageThreshold = 25;
    var consecutiveGarbage = 0;

    try {
      await for (final token in _engine.respond(prompt)) {
        pending.text += token;
        notifyListeners();

        if (_isGarbageToken(token)) {
          consecutiveGarbage++;
          if (consecutiveGarbage >= garbageThreshold) {
            await _engine.stop();
            pending.text = pending.text.trim().isEmpty
                ? '(El modelo no pudo generar una respuesta coherente. '
                    'Probá reformular tu pregunta o cambiar a Lumen '
                    'Estándar si estás en Ligero.)'
                : '${pending.text.trim()}\n\n[respuesta interrumpida]';
            break;
          }
        } else {
          consecutiveGarbage = 0;
        }
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

  /// `true` si [token] solo aporta whitespace o marcadores markdown sin
  /// contenido real. Usado para detectar mode collapse del modelo.
  static bool _isGarbageToken(String token) {
    if (token.isEmpty) return true;
    final stripped = token.replaceAll(RegExp(r'[\s\*\-_#`>]'), '');
    return stripped.isEmpty;
  }

  /// Limpia el historial visible y el contexto del engine.
  Future<void> clear() async {
    await _engine.resetConversation();
    _messages.clear();
    _busy = false;
    notifyListeners();
  }
}
