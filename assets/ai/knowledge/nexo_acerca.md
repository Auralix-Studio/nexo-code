# Sobre Nexo

## Qué es
Nexo es un cliente multiplataforma (Android, iOS, Web, Windows, macOS,
Linux) para estudiantes y docentes de la Universidad Peruana Los Andes.
Reimagina la experiencia de SIGMA: horario, notas, cuotas, pagos,
constancias, integración con Microsoft Teams (Educación).

## Quién lo hizo
Alessandro Villogas Gaspar — estudiante de Ingeniería de Sistemas y
Computación de UPLA (código U01025B, sede Huancayo).
Proyecto personal, no oficial de la universidad.

## Stack técnico
- **Framework:** Flutter (Dart).
- **Arquitectura por capas:** core / data / domain / shared / features.
- **Integraciones paralelas:** SIGMA (JWT), Intranet (cookie PHP),
  Microsoft Graph Education (OAuth2 Device Code).
- **Estado:** AppStore con AsyncValue (sin librerías de terceros).
- **DI manual** en `main.dart`, sin frameworks de inyección.

## Sistema híbrido (SIGMA + Intranet)
Nexo cruza dos APIs distintas: SIGMA expone datos académicos
principales; Intranet complementa con datos de pagos detallados, ranking
promocional y malla curricular. El patrón "Resolver" decide qué fuente
usar para cada dato según disponibilidad y frescura.

## Privacidad
- Credenciales se guardan localmente (SharedPreferences).
- Todo lo que ves en la app vive en el dispositivo (sqlite local).
- Nexo no envía telemetría ni analytics a servidores propios.
- Lumen (este asistente) corre 100% on-device, sin llamadas a APIs
  externas.

## Lumen (este asistente)
- Modelo: **Gemma 3 1B IT** (~529 MB, int4 quantizado QAT por Google).
- Motor: **flutter_gemma + MediaPipe LLM Inference**.
- Conocimiento: tu data en vivo (horario, cuotas, notas, perfil) +
  archivos markdown bundled (UPLA general, carreras, asignaturas,
  trámites, este archivo).
- Conocimiento general: hasta el corte del entrenamiento del modelo
  Gemma (~marzo 2025). Eventos posteriores los desconoce.
- Limitaciones: puede equivocarse. No puede navegar internet, no
  puede modificar tus datos en SIGMA, no contacta a profesores.

## Cómo reportar bugs
- GitHub: https://github.com/Alexito-Hub/nexo/issues
- Incluir: pasos, screenshot, dispositivo, versión de la app
  (visible en Perfil → Acerca).

## Versión
La versión actual de la app está en Perfil → Acerca de Nexo.
