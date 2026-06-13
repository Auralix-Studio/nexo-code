import 'dart:async';

import 'package:flutter/foundation.dart';

import 'context_builder.dart';
import 'lumen_engine.dart';

enum ChatRole { user, lumen }

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

/// Cómo terminó un turno — usado para decidir qué texto deja la burbuja
/// de Lumen y qué cleanup hace el motor.
enum _SendOutcome { ok, cancelled, timeout, garbage, error }

/// Historial + orquestación de envíos al [LumenEngine].
///
/// Modo single-shot: cada [send] limpia el chat del engine, arma el
/// prompt con [LumenContextBuilder] y stream-ea la respuesta.
///
/// Resiliencia (motivada por reportes "no responde / se cuelga"):
/// - **Per-token timeout**: si MediaPipe no emite ni un token en 20s,
///   abortamos. Cubre el caso de la sesión interna del modelo que se
///   detiene sin error y dejaba el `await for` esperando para siempre.
/// - **Total timeout**: 90s de generación tope por turno.
/// - **Stop inmediato**: `stop()` completa el [Completer] compartido →
///   el `send()` activo entra en cleanup sin esperar al stream.
/// - **`_busy` siempre se libera**: ya sea por éxito, error, timeout o
///   cancel. El input nunca queda permanentemente deshabilitado.
class LumenChatSession extends ChangeNotifier {
  LumenChatSession(this._engine, {LumenContextBuilder? contextBuilder})
      : _contextBuilder = contextBuilder;

  static const Duration _perTokenTimeout = Duration(seconds: 20);
  static const Duration _totalTimeout = Duration(seconds: 90);
  // Tras N tokens consecutivos sin caracteres reales, asumimos mode
  // collapse y cortamos. Con el sampling greedy unificado esto debería
  // dispararse rara vez, pero queda como safety net.
  static const int _garbageThreshold = 25;

  final LumenEngine _engine;
  final LumenContextBuilder? _contextBuilder;
  final List<ChatMessage> _messages = [];
  bool _busy = false;
  Completer<_SendOutcome>? _activeOutcome;
  StreamSubscription<String>? _activeSub;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isBusy => _busy;

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
      await _engine.resetConversation();
    } catch (e) {
      debugPrint('[LumenChatSession] resetConversation falló: $e');
    }

    String prompt;
    if (_contextBuilder != null) {
      try {
        prompt = await _contextBuilder.buildPrompt(
          modelId: _engine.activeModelId,
          userQuery: trimmed,
          history: _recentHistory(),
          toolMode: _engine.toolsEnabled,
        );
      } catch (e) {
        debugPrint('[LumenChatSession] buildPrompt falló: $e');
        prompt = trimmed;
      }
    } else {
      prompt = trimmed;
    }

    final outcome = Completer<_SendOutcome>();
    _activeOutcome = outcome;
    Object? errorPayload;
    var consecutiveGarbage = 0;

    void resolve(_SendOutcome o, [Object? err]) {
      if (outcome.isCompleted) return;
      errorPayload = err;
      outcome.complete(o);
    }

    // Watchdog total. El per-token timeout va en el `.timeout()` del stream.
    final totalTimer = Timer(_totalTimeout, () => resolve(_SendOutcome.timeout));

    try {
      _activeSub = _engine
          .respond(prompt)
          .timeout(_perTokenTimeout, onTimeout: (sink) {
            resolve(_SendOutcome.timeout);
            sink.close();
          })
          .listen(
        (token) {
          pending.text += token;
          notifyListeners();
          if (_isGarbageToken(token)) {
            consecutiveGarbage++;
            if (consecutiveGarbage >= _garbageThreshold) {
              resolve(_SendOutcome.garbage);
            }
          } else {
            consecutiveGarbage = 0;
          }
        },
        onError: (e) => resolve(_SendOutcome.error, e),
        onDone: () => resolve(_SendOutcome.ok),
        cancelOnError: true,
      );

      final result = await outcome.future;

      // Cleanup del stream + motor. Si nos cortamos por timeout/cancel,
      // pedirle al engine que pare la generación interna libera RAM.
      totalTimer.cancel();
      await _activeSub?.cancel();
      _activeSub = null;
      if (result != _SendOutcome.ok) {
        try { await _engine.stop(); } catch (_) {}
      }

      _applyOutcome(pending, result, errorPayload);
    } catch (e) {
      // Excepción inesperada en el setup del stream — sin esto antes
      // _busy se quedaba en true.
      pending.text = pending.text.isEmpty
          ? 'Lumen no pudo responder: $e'
          : '${pending.text}\n\n[interrumpido: $e]';
    } finally {
      totalTimer.cancel();
      await _activeSub?.cancel();
      _activeSub = null;
      _activeOutcome = null;
      pending.isStreaming = false;
      _busy = false;
      notifyListeners();
    }
  }

  void _applyOutcome(ChatMessage pending, _SendOutcome outcome, Object? err) {
    final cleanPending = pending.text.trim();
    switch (outcome) {
      case _SendOutcome.ok:
        // Si el modelo terminó sin emitir nada, no dejar la burbuja vacía.
        if (cleanPending.isEmpty) {
          pending.text =
              '(Lumen no produjo una respuesta. Probá reformular la pregunta.)';
        }
      case _SendOutcome.cancelled:
        pending.text = cleanPending.isEmpty
            ? '(Cancelado por el usuario.)'
            : '$cleanPending\n\n[cancelado]';
      case _SendOutcome.timeout:
        pending.text = cleanPending.isEmpty
            ? '(Lumen dejó de responder. Esto pasa cuando el modelo se '
                'queda sin memoria — cerrá apps en background o cambiá a '
                'Lumen Ligero desde Configuración.)'
            : '$cleanPending\n\n[respuesta interrumpida por timeout]';
      case _SendOutcome.garbage:
        pending.text = cleanPending.isEmpty
            ? '(El modelo no pudo generar una respuesta coherente. Probá '
                'reformular o cambiar a Lumen Estándar si estás en Ligero.)'
            : '$cleanPending\n\n[respuesta interrumpida]';
      case _SendOutcome.error:
        pending.text = cleanPending.isEmpty
            ? 'Lumen falló: ${err ?? 'error desconocido'}'
            : '$cleanPending\n\n[interrumpido: $err]';
    }
  }

  /// Para la generación en curso. A diferencia del comportamiento anterior
  /// (que solo llamaba a engine.stop() y dejaba `_busy` activo hasta que
  /// el stream se dignase a terminar), ahora completa el Completer del
  /// send() activo — el cleanup corre inmediato.
  Future<void> stop() async {
    if (!_busy) return;
    final outcome = _activeOutcome;
    if (outcome != null && !outcome.isCompleted) {
      outcome.complete(_SendOutcome.cancelled);
    }
    try { await _engine.stop(); } catch (_) {}
  }

  /// Últimos turnos de la conversación para la memoria multi-turno.
  /// Excluye los 2 mensajes recién agregados (la pregunta actual + el pending
  /// de Lumen), los vacíos y los placeholders de sistema de Lumen (que van
  /// entre paréntesis: "(Cancelado…)", "(Lumen no produjo…)").
  List<LumenTurn> _recentHistory({int maxTurns = 3}) {
    final prior = _messages.length > 2
        ? _messages.sublist(0, _messages.length - 2)
        : const <ChatMessage>[];
    final tail = prior.length > maxTurns * 2
        ? prior.sublist(prior.length - maxTurns * 2)
        : prior;
    return [
      for (final m in tail)
        if (m.text.trim().isNotEmpty &&
            !(m.role == ChatRole.lumen && m.text.trimLeft().startsWith('(')))
          (fromUser: m.role == ChatRole.user, text: m.text),
    ];
  }

  static bool _isGarbageToken(String token) {
    if (token.isEmpty) return true;
    final stripped = token.replaceAll(RegExp(r'[\s\*\-_#`>]'), '');
    return stripped.isEmpty;
  }

  Future<void> clear() async {
    await stop();
    await _engine.resetConversation();
    _messages.clear();
    _busy = false;
    notifyListeners();
  }
}
