import 'dart:convert';

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
      decode: (raw) =>
          LoginResult.fromJson((raw as Map).cast<String, dynamic>()),
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
      decode: (raw) =>
          StudentProfile.fromJson((raw as Map).cast<String, dynamic>()),
    );
    return res.data!;
  }

  Future<UserInfo?> datosEntidad() async {
    final res = await _api.get<UserInfo>(
      'Login/GetDatosEntidad',
      decode: (raw) => UserInfo.fromJson((raw as Map).cast<String, dynamic>()),
    );
    return res.data;
  }

  // ===== Periodos =====

  Future<List<Periodo>> periodosEstudiante() async {
    final res = await _api.get<List<Periodo>>(
      'Recursos/ListarPeriodosEstudiante',
      decode: (raw) => (raw as List)
          .map((e) => Periodo.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
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
      decode: (raw) => (raw as List)
          .map((e) =>
              ClaseHorario.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    return res.data ?? const [];
  }

  // ===== Notas =====

  Future<List<NotaAsignatura>> notasPeriodo(int anio, int periodo) async {
    final res = await _api.get<List<NotaAsignatura>>(
      'Intranet/ListarNotasEstudianteIntranet/$anio/$periodo',
      decode: (raw) => (raw as List)
          .map((e) =>
              NotaAsignatura.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    return res.data ?? const [];
  }

  Future<NotasResumen?> notasResumen(String pesId, String nivel) async {
    final res = await _api.get<NotasResumen>(
      'Estudiante/MostrarNotasResumen/$pesId/$nivel',
      decode: (raw) =>
          NotasResumen.fromJson((raw as Map).cast<String, dynamic>()),
    );
    return res.data;
  }

  Future<List<PromedioPeriodo>> promediosResumen() async {
    final res = await _api.get<List<PromedioPeriodo>>(
      'Estudiante/ListarPromediosResumen',
      decode: (raw) => (raw as List)
          .map((e) =>
              PromedioPeriodo.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    return res.data ?? const [];
  }

  // ===== Pagos =====

  Future<List<Cuota>> cuotasPendientes(
      {String tipDI = AppConfig.tipDI}) async {
    final res = await _api.get<List<Cuota>>(
      'Estudiante/ListarCoutasNoVencidas',
      query: {'TipDI': tipDI},
      decode: (raw) => (raw as List)
          .map((e) => Cuota.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    return res.data ?? const [];
  }

  /// Cuotas registradas en intranet (incluye vencidas con mora).
  Future<List<Cuota>> cuotasIntranet({String tipDI = AppConfig.tipDI}) async {
    final res = await _api.get<List<Cuota>>(
      'Estudiante/ListarCoutasIntranet',
      query: {'TipDI': tipDI},
      decode: (raw) => (raw as List)
          .map((e) => Cuota.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    return res.data ?? const [];
  }

  Future<List<Tasa>> tasas({String tipDI = AppConfig.tipDI}) async {
    final res = await _api.get<List<Tasa>>(
      'Estudiante/ListarTasaTotal',
      query: {'TipDI': tipDI},
      decode: (raw) => (raw as List)
          .map((e) => Tasa.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    return res.data ?? const [];
  }

  Future<List<PagoHistorico>> historicoPagos(
      {String tipDI = AppConfig.tipDI}) async {
    final res = await _api.get<List<PagoHistorico>>(
      'Estudiante/ListarHistorico',
      query: {'TipDI': tipDI},
      decode: (raw) => (raw as List)
          .map((e) =>
              PagoHistorico.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    return res.data ?? const [];
  }
}
