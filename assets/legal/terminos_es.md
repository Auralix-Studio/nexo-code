# Términos y Condiciones de Uso

## 1. Objeto y aceptación

Estos Términos y Condiciones regulan el uso de la aplicación Nexo (en adelante, «Nexo» o «la aplicación») y de la API de Nexo que la hace funcionar, desarrolladas por Auralix Studio (en adelante, «el Desarrollador»), en sus versiones para Android, iOS, Windows y web.

Al pulsar «Aceptar y continuar», el usuario declara haber leído, comprendido y aceptado estos Términos, la Política de Privacidad y la Política de Cookies. Si no está de acuerdo, debe abstenerse de usar Nexo. Si el usuario tiene una sesión iniciada, su aceptación queda registrada en el servidor de Nexo con la versión aceptada y la fecha, como constancia.

## 2. Naturaleza del servicio

Nexo es una aplicación independiente y no oficial que muestra de forma organizada la información académica y administrativa que la Universidad Peruana Los Andes (UPLA) pone a disposición de cada usuario en sus propios sistemas (SIGMA, Intranet y Centro de Idiomas).

- La aplicación se comunica **solo con la API de Nexo** (api.nexo.aurx.pro), un servidor propio del Desarrollador alojado en Microsoft Azure. Es esa API la que inicia sesión en los sistemas de la UPLA **en nombre del usuario** y con sus credenciales, consulta su información y se la devuelve ordenada.
- Nexo **no está afiliada, patrocinada ni respaldada por la UPLA**. Los nombres y signos de la universidad se mencionan solo para identificar los servicios con los que Nexo se comunica.
- La información oficial es exclusivamente la que figura en los sistemas de la UPLA. Ante cualquier diferencia, prevalece la información institucional.
- Nexo depende de la disponibilidad de los servicios de la UPLA y de sus proveedores en la nube, que pueden cambiar o interrumpirse sin previo aviso y sin que ello genere responsabilidad para el Desarrollador.

## 3. Cuenta y credenciales

- Nexo se usa con las credenciales institucionales del propio usuario. El usuario es el único responsable de su custodia y de toda actividad realizada con ellas.
- La contraseña se envía cifrada a la API de Nexo, que la usa **una sola vez** para iniciar sesión en la UPLA y **nunca la guarda en el servidor**. Para volver a entrar cuando la sesión de la universidad vence, la aplicación conserva las credenciales únicamente en el almacenamiento seguro del dispositivo.
- Está prohibido ingresar con credenciales de otra persona, aun con su autorización. El acceso no autorizado a sistemas informáticos puede constituir delito conforme a la **Ley N.º 30096, Ley de Delitos Informáticos**, y sus modificatorias.
- Si el usuario sospecha que sus credenciales fueron comprometidas, debe cambiarlas de inmediato en los canales oficiales de la UPLA y cerrar sesión en Nexo.

## 4. Uso permitido y uso indebido

El usuario se compromete a usar Nexo de buena fe, para fines personales y académicos, y conforme a los reglamentos de la universidad y a la legislación peruana. Queda prohibido, entre otros:

- Acceder o intentar acceder a información de terceros que no le corresponda.
- Realizar consultas masivas o automatizadas, o cualquier acción que pueda sobrecargar o afectar la API de Nexo o los servicios de la UPLA. La API limita la cantidad de peticiones y puede bloquear temporalmente a quien exceda esos límites.
- Alterar, falsificar o registrar información académica que no corresponda a la realidad.
- Copiar, difundir, publicar o comercializar datos personales obtenidos a través de la aplicación.
- Modificar, descompilar o redistribuir versiones alteradas de Nexo, o llamar a la API desde programas no autorizados, para eludir sus medidas de seguridad.

El incumplimiento de estas reglas es de exclusiva responsabilidad del usuario y puede dar lugar a la suspensión del acceso.

## 5. Módulo docente

Las funciones para docentes permiten consultar y registrar asistencia y notas de las secciones a su cargo, del mismo modo que lo permite SIGMA al propio docente.

- Toda operación de registro o corrección la ejecuta la API de Nexo en SIGMA con la sesión del propio docente, después de que este la revisa y confirma, y queda en el registro de auditoría. El docente es el **único responsable** del contenido que registra y debe verificarlo en SIGMA.
- La API solo permite al docente alcanzar **sus propias secciones**: cada consulta se comprueba contra la lista de secciones que SIGMA le asigna.
- Los datos de los estudiantes a los que accede el docente son confidenciales. Solo pueden usarse con fines académicos y dentro de la relación docente, y está prohibido divulgarlos, capturarlos o compartirlos con terceros. Este deber de confidencialidad se mantiene incluso después de terminada dicha relación, conforme a la **Ley N.º 29733, Ley de Protección de Datos Personales**.
- Los indicadores que calcula Nexo (por ejemplo, alumnos en riesgo o clases sin asistencia) son una ayuda de gestión y no sustituyen los registros ni las decisiones oficiales.

## 6. Funciones opcionales

Algunas funciones solo se activan si el usuario o un administrador las habilita, y pueden desactivarse en cualquier momento:

- **Directorio de estudiantes:** solo para cuentas a las que un administrador de Nexo concede acceso. Cada consulta queda registrada y el acceso puede revocarse.
- **Acceso de apoderados:** un padre, madre o tutor puede ver información del estudiante con su DNI y un PIN, solo cuando existe el consentimiento correspondiente.
- **Integraciones:** el estudiante puede compartir su perfil y su horario mediante un enlace de calendario (.ics) o mediante «Conectar con Nexo», que da a una aplicación de terceros acceso limitado a los permisos que el estudiante aprueba (perfil, horario). El estudiante puede revocar cada acceso o dejar de compartir cuando quiera. El uso que la aplicación de terceros haga de esos datos se rige por sus propias condiciones.
- **Avisos de notas:** cuando un docente registra una nota desde Nexo, el estudiante recibe una notificación con el curso, la evaluación y la nota, entregada por Firebase Cloud Messaging. Es opcional y puede desactivarse en Ajustes → «Notificaciones de notas». Las notas registradas fuera de Nexo se muestran al abrir la aplicación; Nexo no garantiza avisar de todas las notas ni en un plazo determinado.

## 7. Exclusión y limitación de responsabilidad

Nexo se ofrece «tal cual» y «según disponibilidad», de forma gratuita y sin garantías de ningún tipo. En la máxima medida permitida por la legislación peruana, el Desarrollador **no se hace responsable** de:

- El mal uso de la aplicación, de las credenciales o de la información obtenida a través de ella, por parte del usuario o de terceros.
- Las decisiones académicas, económicas o de cualquier otra índole que se tomen con base en la información mostrada.
- Los errores, omisiones, demoras o cambios en la información que proviene de los sistemas de la UPLA.
- La pérdida de información almacenada en el dispositivo por desinstalación, cierre de sesión, fallas del equipo o del sistema operativo.
- Los daños derivados de dispositivos comprometidos, redes inseguras o del acceso de terceros al equipo del usuario.
- La interrupción, suspensión o finalización del servicio, incluida la de la API de Nexo o la de sus proveedores en la nube.

Nada de lo anterior excluye la responsabilidad que, conforme al artículo 1328 del Código Civil, no puede excluirse ni limitarse por pacto, ni los derechos irrenunciables que la ley reconoce al usuario.

## 8. Indemnidad

El usuario responde frente al Desarrollador y frente a terceros por los daños que cause el uso de Nexo en contravención de estos Términos o de la ley, y se obliga a mantener indemne al Desarrollador ante cualquier reclamo derivado de dicho uso.

## 9. Propiedad intelectual

El código, el diseño, los textos y los elementos gráficos propios de Nexo son de titularidad de sus desarrolladores y están protegidos por el **Decreto Legislativo N.º 822, Ley sobre el Derecho de Autor**. Los nombres, logotipos y marcas de la UPLA y de terceros pertenecen a sus respectivos titulares.

## 10. Actualizaciones

Nexo consulta periódicamente el sitio del proyecto (nexo.aurx.pro) y, como respaldo, su repositorio público en GitHub para comprobar si hay una versión nueva. La instalación de actualizaciones requiere la acción del usuario o de la tienda de aplicaciones correspondiente.

## 11. Modificaciones

El Desarrollador puede modificar estos Términos. La versión vigente se publica en la API de Nexo, por lo que la aplicación la detecta al abrirse o al volver a usarse, sin necesidad de actualizarla. Cuando un cambio sea relevante, la aplicación mostrará un resumen de lo que cambió y solicitará una nueva aceptación antes de continuar. La versión y su fecha de vigencia figuran en cada documento.

## 12. Ley aplicable y jurisdicción

Estos Términos se rigen por las leyes de la República del Perú. Cualquier controversia se someterá a los jueces y tribunales competentes del Perú, sin perjuicio de los derechos que la **Ley N.º 29571, Código de Protección y Defensa del Consumidor**, reconoce al usuario.

## 13. Contacto

Para consultas sobre estos Términos, el usuario puede escribir a alessandrovillogas@outlook.es o usar la sección Soporte de la aplicación.
