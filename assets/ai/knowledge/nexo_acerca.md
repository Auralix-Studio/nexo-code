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
- **Variantes:** Lumen Ligero (~290 MB, ideal para teléfonos modestos)
  y Lumen Estándar (~529 MB, mejor calidad de respuesta para hardware
  moderno). El usuario elige cuál descargar.
- **Ejecución:** 100% on-device. La inferencia corre en la CPU/GPU del
  teléfono usando un motor de modelos de lenguaje pequeños. No hay
  llamadas a APIs externas, ni a OpenAI, ni a Google, ni a nadie.
- **Conocimiento:** la data en vivo del estudiante (horario, cuotas,
  notas, perfil) + archivos de texto bundled con info pública de UPLA
  (sedes, carreras, asignaturas, trámites, este archivo).
- **Corte de conocimiento general:** principios de 2025. Eventos
  posteriores los desconoce.
- **Limitaciones:** puede equivocarse — los modelos chicos no son
  perfectos. No puede navegar internet, no puede modificar datos en
  SIGMA, no contacta a profesores.

## Cómo reportar bugs
- GitHub: https://github.com/Alexito-Hub/nexo/issues
- Incluir: pasos, screenshot, dispositivo, versión de la app
  (visible en Perfil → Acerca).

## Versión
La versión actual de la app está en Perfil → Acerca de Nexo.
