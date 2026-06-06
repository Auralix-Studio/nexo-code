import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

class DataMappers {
  /// Attempts to extract a field from a JSON object using multiple possible keys.
  /// Handles type safety and returns fallback if not found.
  static T? tryField<T>(Map<String, dynamic> json, List<String> keys, [T? fallback]) {
    for (final key in keys) {
      if (json.containsKey(key)) {
        final val = json[key];
        if (val is T) {
          return val;
        }
        // Fallbacks for conversion
        if (T == String) {
          return val?.toString() as T?;
        }
        if (T == double && val is num) {
          return val.toDouble() as T?;
        }
        if (T == int && val is num) {
          return val.toInt() as T?;
        }
        if (T == bool) {
          if (val is String) {
            final lower = val.toLowerCase();
            if (lower == 'true' || lower == '1') return true as T;
            if (lower == 'false' || lower == '0') return false as T;
          }
          if (val is num) {
            return (val != 0) as T;
          }
        }
      }
    }
    return fallback;
  }

  /// Maps SIGMA profile JSON directly to unified Student model.
  static Student sigmaProfileToStudent(Map<String, dynamic> raw) {
    // Sigma profile might be represented by StudentProfile model
    final profile = StudentProfile.fromJson(raw);
    return Student.fromSigmaProfile(profile);
  }

  /// Maps INTRANET profile JSON directly to unified Student model.
  static Student intranetProfileToStudent(Map<String, dynamic> raw) {
    return Student.fromIntranetProfile(raw);
  }

  /// Maps SIGMA teacher JSON directly to unified Teacher model.
  static Teacher sigmaDocenteToTeacher(Map<String, dynamic> rawInfo, List<Map<String, dynamic>> rawCursos) {
    final info = DocenteInfo.fromJson(rawInfo);
    final cursos = rawCursos.map((c) => DocenteAsignatura.fromJson(c)).toList();
    return Teacher.fromSigmaDocente(info, cursos);
  }
}
