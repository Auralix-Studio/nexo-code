# Revisión preliminar de cumplimiento de Nexo

Fecha: 26 de septiembre de 2026. Alcance: revisión estática de código, textos,
recursos y configuración, con consultas a fuentes oficiales. Sin pruebas sobre
cuentas reales, certificación legal, auditoría completa WCAG ni revisión de las
fichas efectivamente publicadas en las tiendas. Se asume uso principal en Perú.

## Resultado

No existe evidencia suficiente para afirmar que se cumplen todas las normas.
El usuario indica que no existe permiso oficial de la universidad. Los avisos de
independencia son apropiados, pero no acreditan permiso para integrar servicios,
usar marcas o tratar datos de otras personas. Tampoco la ausencia de permiso
permite concluir automáticamente que todo uso es ilícito: debe revisarse el
alcance de los derechos, contratos, condiciones de servicio y bases aplicables.

## Hallazgos y criterios para resolverlos

| Prioridad | Hallazgo verificable | Corrección o evidencia necesaria |
| --- | --- | --- |
| Alta | `app_es.arb` declara independencia y falta de respaldo; los clientes acceden a SIGMA, Intranet e Idiomas y existen operaciones docentes de escritura. | Acreditar las condiciones que permiten esas integraciones y operaciones. El acceso válido de una cuenta no demuestra autorización para distribuir un cliente de terceros. Definir expresamente el alcance antes de ampliar funciones docentes. No se obtuvo un documento de autorización ni unas condiciones de API aplicables en esta revisión. |
| Alta | `termsItemPrivacyBody` afirma que las peticiones van directamente a UPLA y que no se envía información a terceros; el actualizador consulta GitHub y hay enlaces a WhatsApp y correo. | Explicar separadamente credenciales/datos académicos, conexiones de actualización y datos que el usuario comparte al contactar soporte. Una consulta a GitHub expone al menos datos de conexión; no se encontró aquí evidencia de envío de notas o contraseñas a GitHub. |
| Alta | Los términos informan que la caché académica no tiene cifrado adicional; el módulo docente consulta datos de alumnos y permite cambios. | Inventariar campos, destinatarios, conservación, acceso, borrado y base aplicable por finalidad. Identificar al responsable y un canal para derechos. Determinar con asesoría el alcance de obligaciones peruanas y de la tienda; no asumir que guardar datos localmente las elimina. |
| Alta | Se distribuye `Super Mindset.ttf` mediante `pubspec.yaml`; también existen archivos Hypero en el repositorio. No se hallaron archivos de licencia en la búsqueda realizada. | Documentar origen, autor y permiso de redistribución/uso de fuentes, iconos y demás recursos. No equivale a afirmar que carecen de licencia: falta evidencia en el proyecto. Mantener avisos de dependencias y un acceso visible a sus licencias. |
| Media | `Skeleton` inicia `repeat()` sin consultar reducción de movimiento; `Reveal` anima siempre. Festividades y saludo sí contienen controles de `disableAnimations`. | Aplicar una política de movimiento compartida que respete preferencias del sistema y cambios en ejecución, detenga controladores decorativos y muestre el contenido sin transición. Evaluar pausa/ocultación de movimiento continuo, teclado, foco, semántica y contraste. Esto no certifica WCAG. |
| Media | El instalador dice «directorio de instalación oficial» y el paquete MSIX se llama «Nexo - UPLA». | Sustituir la primera expresión por «carpeta de instalación de Nexo». Revisar si nombre, iconos, capturas y descripción pueden sugerir aval institucional. No cambiar a ciegas la identidad MSIX registrada. |
| Media | `AppConfig` duplica versión/build de `pubspec.yaml`; MSIX declara 1.6.4.0 frente a 1.6.6+15. Contactos y dominios se repiten en distintos archivos. | Generar metadatos desde una sola fuente; centralizar contactos y endpoints por servicio. Validar los destinos HTTPS autorizados, evitando que configuración arbitraria pueda redirigir credenciales. |
| Media | `photoUrlFor` construye una URL con el prefijo fijo `037000`; hay texto español dentro de localizaciones quechua y en documentos PDF. | Validar el contrato del identificador de foto, preferir URL suministrada por el servicio cuando exista y mostrar avatar neutro si falta. Localizar textos y revisar traducciones humanas de avisos legales. No inventar reglas académicas ni completar datos ausentes con cifras de ejemplo. |

## Qué significa evitar hardcodeados

No consiste en eliminar constantes de diseño o protocolos. Los colores,
espaciados y tiempos deben vivir en tokens; los textos en localizaciones; los
metadatos en una fuente de versión; y los datos académicos deben proceder del
servicio, de una caché identificada o de cálculos documentados. Una fecha de
versión de términos debe ser histórica y estable, no generada con la fecha de
cada ejecución. Las reglas académicas requieren una fuente verificable.

## Orden de trabajo recomendado

1. Aclarar permisos y alcance docente; completar el inventario de datos y recursos.
2. Redactar una política precisa y coherente en cada idioma, con responsable,
   finalidades, destinatarios, conservación, derechos y contacto verificables.
   Versionarla y solicitar nueva aceptación cuando corresponda.
3. Corregir movimiento reducido y centralizar configuración sin abrir destinos
   de credenciales a cambios arbitrarios.
4. Verificar licencias y metadatos del paquete; contrastar las declaraciones de
   privacidad y permisos de cada tienda con el comportamiento real.
5. Probar accesibilidad y borrado con casos concretos. Someter el alcance legal
   restante a revisión profesional antes de afirmar cumplimiento.

## Fuentes oficiales consultadas

- [Reglamento de la Ley 29733, DS 016-2024-JUS](https://www.gob.pe/institucion/smv/normas-legales/6426760-016-2024-jus): marco peruano de protección de datos; las obligaciones concretas dependen del tratamiento y del rol real.
- [Indecopi: registro y protección de marcas](https://www.gob.pe/institucion/indecopi/pages/333-registrar-la-marca-de-producto-o-servicio-de-tu-negocio-en-indecopi): protección del uso de signos; no demuestra el estado registral de UPLA o Nexo.
- [Microsoft Store Policies](https://learn.microsoft.com/en-us/windows/apps/publish/store-policies): privacidad (10.5), seguridad y derechos sobre contenido y metadatos (11.2). Aplican a distribución en esa tienda; no constituyen aprobación del instalador independiente.
- [W3C, WCAG 2.2, 2.2.2](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide): pausa, parada u ocultación de determinado contenido en movimiento automático, con excepciones.
- [W3C, WCAG 2.2, 2.3.3](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html): animación por interacción, nivel AAA. Referencia técnica; no se presenta como obligación legal universal para esta app nativa.

No se han validado todos los mercados, condiciones de Google Play/App Store,
autorizaciones de activos, contratos universitarios o registro de bancos de
datos. Este documento registra hallazgos y pendientes, no un certificado.
