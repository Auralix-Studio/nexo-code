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
/// Es lo que la UI escucha (extends [ChangeNotifier]). El engine se inyecta
/// para poder testear con un fake. El historial vive en memoria: si el user
/// cierra la app, se pierde (decisión consciente de v1; sqlite en v2).
///
/// El [contextBuilder] genera el system preamble (KB + datos del estudiante)
/// que se concatena al primer mensaje del usuario. Si es null, la sesión
/// envía sin contexto (útil para tests).
class LumenChatSession extends ChangeNotifier {
  LumenChatSession(this._engine, {LumenContextBuilder? contextBuilder})
      : _contextBuilder = contextBuilder;

  final LumenEngine _engine;
  final LumenContextBuilder? _contextBuilder;
  final List<ChatMessage> _messages = [];
  bool _busy = false;
  bool _preambleSent = false;

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

    // Construir el payload real para el modelo. Para el primer turno
    // preponemos el system preamble — la burbuja del user sigue mostrando
    // solo `trimmed`, pero el modelo recibe el contexto completo.
    String payload = trimmed;
    if (!_preambleSent && _contextBuilder != null) {
      try {
        final preamble =
            await _contextBuilder.buildPreamble(modelId: _engine.activeModelId);
        payload = '$preamble$trimmed';
        _preambleSent = true;
      } catch (e) {
        // Si falla armar el preamble, mandamos sin contexto y seguimos.
        debugPrint('Lumen: no se pudo armar el preamble: $e');
      }
    }

    try {
      // Detector de runaway: si el modelo entra en mode collapse
      // (caso conocido: `**\n\n**\n\n**` infinito sin texto real), corta
      // el stream para que el user no vea spinner eterno. Heurística:
      // contamos tokens consecutivos que solo aportan whitespace/markdown
      // vacío. Si pasamos el umbral, paramos.
      const garbageThreshold = 25;
      var consecutiveGarbage = 0;

      await for (final token in _engine.respond(payload)) {
        pending.text += token;
        notifyListeners();

        if (_isGarbageToken(token)) {
          consecutiveGarbage++;
          if (consecutiveGarbage >= garbageThreshold) {
            await _engine.stop();
            pending.text = pending.text.trim().isEmpty
                ? '(El modelo no pudo generar una respuesta coherente. '
                    'Probá reformular tu pregunta o cambiar a Lumen Estándar '
                    'si estás en Ligero.)'
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

  /// Limpia el historial visible y el contexto del engine. El preamble
  /// volverá a inyectarse en el próximo turno.
  Future<void> clear() async {
    await _engine.resetConversation();
    _messages.clear();
    _busy = false;
    _preambleSent = false;
    notifyListeners();
  }
}
