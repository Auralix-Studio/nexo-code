# Changelog

All notable changes to Nexo will be documented in this file.

## [Sin publicar]

### Docentes — mejoras
- Nueva pestaña **Resumen** por curso: promedio, aprobados/desaprobados/sin nota, asistencia promedio, distribución de notas y **alumnos en riesgo** (desaprobados o con asistencia < 70 %)
- **Registrar y corregir notas** en SIGMA desde la ficha del alumno, con confirmación previa (ver docs/evaluacion-endpoints-docente.md §11)
- **Exportar lista del curso en PDF** (código, alumno, nota final, asistencia)
- Ordenar alumnos por nombre, nota o asistencia, y filtro "Solo en riesgo"
- Asistencia del día: resumen de presentes/faltas/justificados y navegación día a día
- Inicio docente: marca la clase **en curso**, la **siguiente** y las que ya terminaron
- Deslizar para actualizar en las listas del curso

### Docentes — correcciones
- Iniciales de alumnos aparecían como "?" (SIGMA solo manda el nombre completo)
- El conteo de alumnos mostraba 0 cuando SIGMA no envía `matriculados`
- Al tocar un alumno desde la pestaña Notas se abría su asistencia
- Error al cargar la asistencia del alumno dejaba el indicador de carga para siempre
- Estados de asistencia desconocidos se mostraban como "Justificada"
- La caché sin conexión perdía las notas por evaluación del alumno
- Las clases se ordenaban como texto ("10:00" antes que "8:00") y los días enviados como nombre no aparecían
- Tarjetas de curso se desbordaban en pantallas angostas
- Texto fijo sin traducir en la ficha del alumno; etiqueta de búsqueda en quechua decía "docente" en vez de "alumno"

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
