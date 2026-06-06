import 'dart:convert';

import 'package:nexo/core/errors.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/data/api_client.dart';
import 'package:nexo/domain/models.dart';

/// Repositorio que mapea endpoints SIGMA → modelos de dominio.
class SigmaRepository {
  SigmaRepository(this._api);
  final ApiClient _api;

  // ===== Auth =====

  Future<LoginResult> login(String usuarioId, String password) async {
    final clave = base64.encode(utf8.encode(password));
    final res = await _api.post<LoginResult>(
      'Login/SesionV1',
      authorize: false,
      body: {
        'usuarioId': usuarioId,
        'clave': clave,
        'nomSys': AppConfig.nomSys,
      },
      decode: (raw) => _safeDecode(
        raw: raw,
        modelName: 'LoginResult',
        fromJson: LoginResult.fromJson,
      ),
    );
    if (!res.success || res.data == null) {
      throw Exception(res.mensaje ?? 'No se pudo iniciar sesión.');
    }
    _api.setToken(res.data!.token);
    return res.data!;
  }

  // ===== Perfil =====

  Future<StudentProfile> infoEstudiante() async {
    final res = await _api.get<StudentProfile>(
      'Estudiante/MostrarInfoEstudiante',
      decode: (raw) => _safeDecode(
        raw: raw,
        modelName: 'StudentProfile',
        fromJson: StudentProfile.fromJson,
      ),
    );
    return res.data!;
  }

  Future<UserInfo?> datosEntidad() async {
    final res = await _api.get<UserInfo>(
      'Login/GetDatosEntidad',
      decode: (raw) => _safeDecode(
        raw: raw,
        modelName: 'UserInfo',
        fromJson: UserInfo.fromJson,
      ),
    );
    return res.data;
  }

  // ===== Periodos =====

  Future<List<Periodo>> periodosEstudiante() async {
    final res = await _api.get<List<Periodo>>(
      'Recursos/ListarPeriodosEstudiante',
      decode: (raw) => _safeDecodeList(
        raw: raw,
        modelName: 'Periodo',
        fromJson: Periodo.fromJson,
      ),
    );
    return res.data ?? const [];
  }

  // ===== Horario =====

  /// `*/*` = periodo activo según el bundle de SIGMA.
  Future<List<ClaseHorario>> horario({
    String anio = '*',
    String periodo = '*',
  }) async {
    final res = await _api.get<List<ClaseHorario>>(
      'Intranet/ListarHorariosEstudianteIntranet/$anio/$periodo',
      decode: (raw) => _safeDecodeList(
        raw: raw,
        modelName: 'ClaseHorario',
        fromJson: ClaseHorario.fromJson,
      ),
    );
    return res.data ?? const [];
  }

  // ===== Notas =====

  Future<List<NotaAsignatura>> notasPeriodo(int anio, int periodo) async {
    final res = await _api.get<List<NotaAsignatura>>(
      'Intranet/ListarNotasEstudianteIntranet/$anio/$periodo',
      decode: (raw) => _safeDecodeList(
        raw: raw,
        modelName: 'NotaAsignatura',
        fromJson: NotaAsignatura.fromJson,
      ),
    );
    return res.data ?? const [];
  }

  Future<NotasResumen?> notasResumen(String pesId, String nivel) async {
    final res = await _api.get<NotasResumen>(
      'Estudiante/MostrarNotasResumen/$pesId/$nivel',
      decode: (raw) => _safeDecode(
        raw: raw,
        modelName: 'NotasResumen',
        fromJson: NotasResumen.fromJson,
      ),
    );
    return res.data;
  }

  Future<List<PromedioPeriodo>> promediosResumen() async {
    final res = await _api.get<List<PromedioPeriodo>>(
      'Estudiante/ListarPromediosResumen',
      decode: (raw) => _safeDecodeList(
        raw: raw,
        modelName: 'PromedioPeriodo',
        fromJson: PromedioPeriodo.fromJson,
      ),
    );
    return res.data ?? const [];
  }

  // ===== Pagos =====

  Future<List<Cuota>> cuotasPendientes(
      {String tipDI = AppConfig.tipDI}) async {
    final res = await _api.get<List<Cuota>>(
      'Estudiante/ListarCoutasNoVencidas',
      query: {'TipDI': tipDI},
      decode: (raw) => _safeDecodeList(
        raw: raw,
        modelName: 'Cuota',
        fromJson: Cuota.fromJson,
      ),
    );
    return res.data ?? const [];
  }

  /// Cuotas registradas en intranet (incluye vencidas con mora).
  Future<List<Cuota>> cuotasIntranet({String tipDI = AppConfig.tipDI}) async {
    final res = await _api.get<List<Cuota>>(
      'Estudiante/ListarCoutasIntranet',
      query: {'TipDI': tipDI},
      decode: (raw) => _safeDecodeList(
        raw: raw,
        modelName: 'Cuota',
        fromJson: Cuota.fromJson,
      ),
    );
    return res.data ?? const [];
  }

  Future<List<Tasa>> tasas({String tipDI = AppConfig.tipDI}) async {
    final res = await _api.get<List<Tasa>>(
      'Estudiante/ListarTasaTotal',
      query: {'TipDI': tipDI},
      decode: (raw) => _safeDecodeList(
        raw: raw,
        modelName: 'Tasa',
        fromJson: Tasa.fromJson,
      ),
    );
    return res.data ?? const [];
  }

  // ===== Recursos institucionales =====

  /// Banners / anuncios institucionales (carrusel del Home oficial).
  Future<List<Publicacion>> publicaciones() async {
    final res = await _api.get<List<Publicacion>>(
      'Recursos/ListarPublicaciones',
      decode: (raw) => _safeDecodeList(
        raw: raw,
        modelName: 'Publicacion',
        fromJson: Publicacion.fromJson,
      ),
    );
    return res.data ?? const [];
  }

  /// Credencial Wi-Fi institucional del alumno.
  Future<WifiCredencial?> wifiCredencial() async {
    final res = await _api.get<WifiCredencial>(
      'Recursos/ObtenerWifiUsuario',
      decode: (raw) {
        try {
          if (raw is Map) {
            return WifiCredencial.fromJson(raw.cast<String, dynamic>());
          }
          return const WifiCredencial(usuario: '', contrasena: '');
        } catch (e) {
          throw DataParsingException(
            model: 'WifiCredencial',
            rawData: raw,
            innerError: e,
          );
        }
      },
    );
    return res.data;
  }

  /// Conteo de notas (aprobados/desaprobados/pendientes) del periodo.
  Future<ConteoNotas?> conteoNotas(int anio, int periodo) async {
    final res = await _api.get<ConteoNotas>(
      'Estudiante/MostrarConteoNotas/$anio/$periodo',
      decode: (raw) {
        try {
          if (raw is Map) {
            return ConteoNotas.fromJson(raw.cast<String, dynamic>());
          }
          return const ConteoNotas(
              aprobados: 0, desaprobados: 0, pendientes: 0, total: 0);
        } catch (e) {
          throw DataParsingException(
            model: 'ConteoNotas',
            rawData: raw,
            innerError: e,
          );
        }
      },
    );
    return res.data;
  }

  /// Cambiar contraseña del usuario autenticado (`Login/ChangePassword`).
  /// Body shape best-effort — verificar con captura real al primer uso.
  Future<bool> changePassword(String actual, String nueva) async {
    final res = await _api.post<bool>(
      'Login/ChangePassword',
      body: {
        'claveActual': base64.encode(utf8.encode(actual)),
        'claveNueva': base64.encode(utf8.encode(nueva)),
        'nomSys': AppConfig.nomSys,
      },
      decode: (_) => true,
    );
    if (!res.success) {
      throw Exception(res.mensaje ?? 'No se pudo cambiar la contraseña.');
    }
    return true;
  }

  Future<List<PagoHistorico>> historicoPagos(
      {String tipDI = AppConfig.tipDI}) async {
    final res = await _api.get<List<PagoHistorico>>(
      'Estudiante/ListarHistorico',
      query: {'TipDI': tipDI},
      decode: (raw) => _safeDecodeList(
        raw: raw,
        modelName: 'PagoHistorico',
        fromJson: PagoHistorico.fromJson,
      ),
    );
    return res.data ?? const [];
  }

  T _safeDecode<T>({
    required Object? raw,
    required String modelName,
    required T Function(Map<String, dynamic> json) fromJson,
  }) {
    if (raw == null) {
      throw DataParsingException(
        model: modelName,
        rawData: raw,
        innerError: 'data nulo',
      );
    }
    try {
      final jsonMap = (raw as Map).cast<String, dynamic>();
      return fromJson(jsonMap);
    } catch (e) {
      throw DataParsingException(
        model: modelName,
        rawData: raw,
        innerError: e,
      );
    }
  }

  List<T> _safeDecodeList<T>({
    required Object? raw,
    required String modelName,
    required T Function(Map<String, dynamic> json) fromJson,
  }) {
    // SIGMA suele responder `data: null` cuando el alumno no tiene registros
    // del recurso (p. ej. sin cuotas pendientes). No es un error, es "lista
    // vacía". Antes esto cascaba como DataParsingException y pintaba la
    // pantalla en rojo. También aceptamos `data: ""` (algunos endpoints).
    if (raw == null) return const [];
    if (raw is String && raw.trim().isEmpty) return const [];
    try {
      final list = raw as List;
      return list.map((e) {
        try {
          return fromJson((e as Map).cast<String, dynamic>());
        } catch (inner) {
          throw DataParsingException(
            model: modelName,
            rawData: e,
            innerError: inner,
          );
        }
      }).toList();
    } catch (e) {
      if (e is DataParsingException) rethrow;
      throw DataParsingException(
        model: '${modelName}List',
        rawData: raw,
        innerError: e,
      );
    }
  }
}
