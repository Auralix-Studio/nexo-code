# Política de Privacidad

## 1. Responsable y contacto

El responsable del desarrollo de Nexo y del tratamiento de los datos personales que realiza su servidor es Auralix Studio (en adelante, «el Desarrollador»), con domicilio en Huancayo, Perú.

- Correo electrónico: alessandrovillogas@outlook.es
- WhatsApp: +51 907 924 307 (sección Soporte de la aplicación)

## 2. Marco normativo

Esta Política se rige por la **Ley N.º 29733, Ley de Protección de Datos Personales**, y su Reglamento, aprobado por **Decreto Supremo N.º 016-2024-JUS**, así como por las demás normas peruanas aplicables. Los términos «dato personal», «tratamiento», «titular» y «encargado» se entienden en el sentido que les da esa normativa.

## 3. Cómo funciona Nexo

La aplicación se comunica **solo con la API de Nexo** (https://api.nexo.aurx.pro), un servidor propio del Desarrollador. La API inicia sesión en los sistemas de la UPLA (SIGMA, Intranet y Centro de Idiomas) **en tu nombre**, consulta tu información y te la devuelve ordenada. La aplicación ya no se conecta directamente con esos sistemas.

- **Tu contraseña nunca se guarda en el servidor.** Se usa una sola vez para iniciar sesión en la UPLA y se descarta.
- Lo que el servidor sí conserva son las **sesiones que la universidad emite** al iniciar sesión (token de SIGMA, cookies de la Intranet y token del Centro de Idiomas), **cifradas con AES-256-GCM**, para atender tus siguientes consultas sin pedirte la clave otra vez. Se eliminan al cerrar sesión.
- La aplicación guarda tus credenciales **solo en tu dispositivo**, en su almacenamiento seguro, para volver a iniciar sesión cuando la sesión de la universidad vence.

## 4. Datos que se tratan

**a) Credenciales y sesión.** Código de usuario y contraseña (solo en tránsito hacia la UPLA; nunca se almacenan en el servidor), las sesiones de la universidad cifradas y los tokens de acceso de Nexo.

**b) Identidad.** Código, nombres y apellidos, y la dirección de la fotografía institucional que publica la UPLA. La fotografía se descarga directamente desde los servidores de la universidad.

**c) Datos académicos.** Notas, horario, avance curricular, periodos, matrícula y cursos de idiomas, según lo que la UPLA ponga a disposición de cada cuenta.

**d) Datos económicos.** Cuotas, pagos, deudas, tasas e historial de pagos.

**e) Credencial de Wi-Fi institucional.** Se lee de SIGMA solo cuando la pides y se te muestra; **nunca se guarda** ni se registra en el servidor.

**f) Datos del módulo docente.** Si eres docente: tus secciones, las listas de estudiantes de esas secciones (nombres, código, fotografía institucional) y las notas y asistencias que registras.

**g) Datos de funciones opcionales.** Los accesos al directorio que conceden los administradores, los datos del apoderado (DNI y PIN protegido) y su consentimiento, lo que decidas compartir con integraciones y los permisos que apruebes (ver sección 7).

**h) Datos de seguridad y técnicos.** Dirección IP, fecha y hora de las peticiones, versión de la aplicación, el identificador de notificaciones del dispositivo (si tienes los avisos de notas activos) y el registro de auditoría de acciones sensibles (inicio de sesión, registros docentes, consultas al directorio, cambios de consentimiento, aceptación de estos documentos).

**i) Preferencias y uso local.** Tema, idioma, formato de hora, configuración de notificaciones y del inicio, borradores de asistencia y avisos descartados. Se guardan solo en tu dispositivo.

Nexo no solicita datos sensibles adicionales, no accede a tu ubicación, contactos, cámara ni micrófono, y no elabora perfiles con fines comerciales.

## 5. Finalidades

Los datos se tratan únicamente para:

- Iniciar y mantener tu sesión en los servicios de la UPLA a través de la API de Nexo.
- Mostrarte tu información académica y administrativa de forma organizada, también sin conexión.
- Programar en tu dispositivo recordatorios y notificaciones locales de clases y pagos, y mostrar widgets de pantalla de inicio.
- En el módulo docente, permitir al docente consultar y registrar la asistencia y las notas de sus secciones.
- Prestar las funciones opcionales que tú o un administrador activen.
- Proteger el servicio: limitar abusos, detectar accesos indebidos y poder demostrar quién accedió a qué.
- Comprobar si existe una versión nueva de la aplicación y atender tus consultas a soporte.

## 6. Base del tratamiento

El tratamiento se realiza con tu consentimiento, que otorgas al aceptar esta Política, y porque es necesario para prestarte el servicio que solicitas. En el módulo docente, los datos de los estudiantes se tratan dentro de la relación académica que la universidad ya habilita al docente en SIGMA, y para las mismas finalidades. Las funciones opcionales requieren un consentimiento propio.

Puedes retirar tu consentimiento en cualquier momento cerrando sesión y dejando de usar la aplicación, o desactivando cada función opcional.

## 7. Funciones opcionales

- **Directorio de estudiantes.** Solo lo ven las cuentas a las que un administrador concede acceso. Cada ficha consultada queda registrada con el código de quien la abrió.
- **Acceso de apoderados.** Un padre, madre o tutor puede ver la información del estudiante con su DNI y un PIN, únicamente con el consentimiento correspondiente, que puede revocarse.
- **Calendario (.ics).** Si lo activas, se crea un enlace privado con tu horario para suscribirte desde cualquier aplicación de calendario. Solo se guarda una huella del enlace; puedes renovarlo o desactivarlo.
- **«Conectar con Nexo».** Una aplicación de terceros puede pedirte acceso mediante un código; solo recibe los permisos que apruebes (perfil, horario) y puedes revocarlo cuando quieras. El tratamiento que haga esa aplicación se rige por su propia política.
- **Avisos de notas.** Cuando un docente registra una nota tuya desde Nexo, el servidor te envía una notificación con el curso, la evaluación y la nota. El servidor **no revisa tus notas periódicamente** ni inicia sesión en tu nombre para buscarlas; las notas registradas fuera de Nexo las detecta la aplicación al abrirse. Para enviarte el aviso, el servidor guarda el identificador de notificaciones de tu dispositivo, que se borra al cerrar sesión. Es opcional: puedes desactivarlo en Ajustes → «Notificaciones de notas».

## 8. Destinatarios, encargados y transferencias

Nexo no vende, alquila ni cede tus datos personales, no muestra publicidad y no incorpora herramientas de analítica ni de seguimiento de terceros. Solo intervienen:

- **Servicios de la UPLA** (SIGMA, Intranet, Centro de Idiomas y el servidor de fotografías): reciben tus credenciales y consultas a través de la API de Nexo para devolverte tu propia información. El tratamiento que realizan se rige por las políticas de la universidad.
- **Microsoft Azure** (Microsoft Corporation), como encargado: aloja la API de Nexo en Azure Container Apps, en la región **Chile Central**.
- **MongoDB Atlas** (MongoDB, Inc.), como encargado: base de datos en la nube donde se guardan la cuenta, las sesiones cifradas, el registro de auditoría y los datos de las funciones opcionales.
- **Google Firebase** (Google LLC), como encargado: **Firebase Cloud Messaging** entrega los avisos de notas a tu dispositivo; recibe el identificador de notificaciones y el contenido del aviso (curso, evaluación y nota). Se prevé usar también Firebase App Check para comprobar que solo la aplicación oficial llama a la API.
- **GitHub** (Microsoft Corporation): recibe una consulta técnica para comprobar si hay una versión nueva. No se le envía información académica ni credenciales.
- **WhatsApp o tu proveedor de correo**, solo si decides contactar a soporte, y únicamente con la información que tú envíes.

Como estos proveedores tienen servidores fuera del Perú (por ejemplo, en Chile y en Estados Unidos), el uso de Nexo implica un **flujo transfronterizo** de datos personales, que se realiza conforme a la Ley N.º 29733 y su Reglamento y al que consientes al aceptar esta Política.

## 9. Almacenamiento y conservación

- **En el servidor:** las sesiones de la universidad se guardan cifradas y se eliminan al cerrar sesión o cuando vencen. Tu información académica y económica se consulta a la UPLA y se mantiene temporalmente en la memoria del servidor (de minutos a unas horas según el dato, como máximo un día) para responder más rápido y no sobrecargar a la universidad; se borra al cerrar sesión y no se guarda en la base de datos, salvo lo que decidas compartir con funciones opcionales. Para los avisos de notas se guarda el identificador de notificaciones del dispositivo hasta que cierres sesión o desactives los avisos. Se conserva tu registro básico (código y nombres), las secciones del docente para validar su acceso, el registro de auditoría y la constancia de aceptación de estos documentos durante el tiempo necesario para fines de seguridad y para acreditar el cumplimiento legal.
- **En el dispositivo:** las credenciales y los datos de sesión se guardan en el almacenamiento seguro del sistema operativo (Keychain, Keystore o el equivalente en Windows). En la versión web, la sesión se mantiene solo en memoria. La información académica se guarda en una base de datos local, sin cifrado adicional al que ofrezca el sistema operativo. Los borradores de asistencia se conservan como máximo dos días o hasta que se registran.
- **Cerrar sesión elimina** las sesiones de la universidad en el servidor y, en el dispositivo, las credenciales, la información en caché y los borradores. Desinstalar la aplicación elimina todos sus datos locales.

## 10. Seguridad

- Todas las comunicaciones usan conexiones cifradas (HTTPS/TLS).
- Las sesiones de la universidad se cifran en el servidor con AES-256-GCM y las contraseñas nunca se almacenan.
- La API limita la cantidad de peticiones para frenar abusos y registra en un registro de auditoría las acciones sensibles.
- Se prevé exigir Firebase App Check para que solo la aplicación oficial pueda llamar a la API.

La seguridad depende también del bloqueo de pantalla, las actualizaciones del sistema y el cuidado del usuario. Ninguna medida es infalible.

## 11. Derechos del titular

Conforme a la Ley N.º 29733, puedes ejercer tus derechos de información, acceso, rectificación, cancelación y oposición, y los demás que reconozca la normativa vigente.

- Puedes consultar tus datos en la aplicación, actualizarlos en los sistemas de la UPLA, eliminar tus sesiones del servidor y los datos locales cerrando sesión, y desactivar cada función opcional.
- Para cualquier solicitud, incluida la eliminación de lo que el servidor conserve sobre ti, escribe a alessandrovillogas@outlook.es. Se responderá dentro de los plazos establecidos por la normativa.
- Si consideras que tus derechos no han sido atendidos, puedes presentar una reclamación ante la **Autoridad Nacional de Protección de Datos Personales** del Ministerio de Justicia y Derechos Humanos.

La rectificación de información académica (por ejemplo, una nota) solo puede hacerla la universidad en sus sistemas oficiales.

## 12. Menores de edad

Nexo está dirigida a estudiantes y docentes universitarios. El tratamiento de datos de menores de edad se sujeta a las reglas especiales de la Ley N.º 29733 y su Reglamento; los menores de catorce años no deben usar la aplicación sin la autorización de sus padres o tutores.

## 13. Deber de confidencialidad

El docente, y cualquier persona con acceso al directorio o como apoderado, que acceda a datos de estudiantes a través de Nexo está obligado a guardar confidencialidad sobre ellos y a usarlos solo para la finalidad autorizada, conforme al artículo 17 de la Ley N.º 29733. Está prohibido capturar, difundir o compartir dichos datos con terceros.

## 14. Cambios en esta Política

Si cambia de forma relevante el modo en que se tratan los datos, se actualizará esta Política y se indicará su nueva versión y fecha. La versión vigente se publica en la API de Nexo, así que la aplicación la detecta sin necesidad de actualizarse, te muestra un resumen de los cambios y te solicita una nueva aceptación antes de continuar.
