# Changelog

All notable changes to Nexo will be documented in this file.

## [1.10.0] - 2026-10-14

### Tipografía
- **Importa tus propias fuentes**: elige archivos TTF u OTF (también varios estilos de una misma familia, como Regular y Bold) y se aplican a toda la app.
- Las fuentes incluidas ya no se ven engrosadas: los títulos usan el grosor real de la letra en lugar de una negrita artificial.
- Si en la versión anterior elegiste Hypero o Super Mindset, se conserva.

### Actualizaciones
- **Android se actualiza desde la app**: avisa cuando hay una versión nueva (también con la app cerrada, una vez al día) y la instala con un toque, después de comprobar que el archivo es de Nexo y está firmado por Auralix Studio.
- Descargas más livianas: la app baja solo el archivo de tu teléfono, unos 11 MB en la mayoría de equipos.
- La búsqueda de versiones nuevas ya no falla cuando muchas personas usan la misma red, como el Wi-Fi de la universidad.

## [1.9.0] - 2026-10-14

### Tipografía y Diseño
- **Personalización total de fuentes**: posibilidad de cambiar la tipografía en el 100% de la aplicación (Roboto, Sistema nativo, Hypero, Super Mindset o fuentes personalizadas del sistema operativo con vista previa en tiempo real).

### Android y Plataformas
- **Identidad de paquete definitiva**: identificador público actualizado a `com.auralix.nexo` en Android, iOS, Windows, macOS y Linux.

## [1.8.1] - 2026-10-12

### Android
- Nexo para Android va firmado con la clave propia de Auralix Studio.

## [1.8.0] - 2026-10-12

### Cambio rápido de cuenta
- Hasta 5 cuentas guardadas en el dispositivo (almacén seguro del sistema); se cambia con un toque desde Perfil, la barra lateral o Ctrl/Cmd + Shift + A
- El login muestra "Continuar como" con las cuentas guardadas
- "Agregar otra cuenta" conserva la actual; "Cerrar sesión" la olvida del dispositivo
- Si la contraseña cambió en SIGMA, la cuenta queda en la lista y pide la nueva con el usuario ya escrito

### Publicación
- Publicación 100 % automática al fusionar en `main`: versión, tag, compilación de todas las plataformas, verificación de Windows, `SHA256SUMS.txt`, notas con tabla de descargas, release en `Auralix-Studio/nexo` y changelog del sitio (ver docs/versionado.md)

### Docentes
- Inicio reorganizado: saludo, cifras (cursos, alumnos, periodo), agenda de hoy, pendientes y cursos con sus números
- Agenda de hoy con el estado de cada clase y si ya tiene asistencia registrada, con acceso directo a tomarla
- Pendientes: clases de las últimas dos semanas sin asistencia en SIGMA (omite feriados nacionales y se pueden descartar) y alumnos que necesitan atención en todas las secciones (asistencia crítica, cerca del límite o desaprobando)
- Tabla de notas de la sección con la columna de alumnos fija
- Pegar notas desde Excel (por código de alumno o en el orden de la lista), sin adivinar filas ambiguas
- Lo marcado al pasar lista se guarda en el dispositivo y se recupera si la app se cierra o falla el envío
- El horario se arma con las asignaturas ya descargadas: una consulta menos a SIGMA al abrir el inicio
- Nombres de asignaturas legibles y sin paréntesis ("Base de Datos I"); las electivas llevan su etiqueta
- Cabecera del curso y pestaña Cursos en palabras: "Sección A1 · Ciclo 4 · Presencial", horario por día y aula; el NRC queda discreto y copiable
- Foto del docente (SIGMA la guarda en otra carpeta que la de los alumnos)
- Animaciones: cambios de estado con fundido, tarjetas que crecen suave al cargar y cifras que cuentan; todo respeta "reducir movimiento" del sistema

### Correcciones
- "Alumnos: 0" en el inicio docente por rosters vacíos guardados por versiones anteriores
- Métricas del inicio del estudiante otra vez en 2 × 2 en celulares angostos o con letra grande (antes bajaban de a una por fila); la tarjeta se compacta y los montos largos se achican para caber
- Desbordes con letra grande en tomar asistencia, confirmaciones e inicio docente

### Legal
- Términos y Condiciones, Política de Privacidad y Política de Cookies completos, con ley peruana aplicable y límites de responsabilidad, a nombre de Auralix Studio (versión 4: se pide aceptarlos de nuevo)

## [1.7.1] - 2026-09-26

### Correcciones
- Indicadores de sincronización ("Consultado al servidor", "Guardado") eliminados de la UI — ya no aparecen en ninguna pantalla
- Próxima clase en inicio ahora muestra un skeleton animado mientras carga en lugar de espacio en blanco

## [1.7.0] - 2026-09-26

### Mejoras
- Ventana de escritorio abre más grande al iniciar (1100×680 en lugar de 800×480)
- Indicador de sincronización solo visible cuando es relevante (caché, error o cargando) — ya no aparece cuando los datos son frescos del servidor

### Correcciones
- Indicador "Consultado al servidor" ya no se muestra innecesariamente en Horario y Pagos
- Ventana de Windows ya no arranca pequeña en escritorio

## [1.6.8] - 2026-09-26

### Mejoras
- Release inicial publicado en GitHub
