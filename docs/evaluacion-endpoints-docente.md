# Evaluación de endpoints — módulo docente

> Revisión técnica · octubre 2026. Fuente autoritativa: el **frontend de
> producción de SIGMA** (`https://sigma.upla.edu.pe`, bundle `assets/index-*.js`),
> que es el cliente oficial y define cómo se llaman realmente los endpoints.
> No se autenticó ninguna cuenta contra SIGMA para esta evaluación.

## Resumen ejecutivo

El módulo docente de Nexo **no puede funcionar** contra el backend real en su
estado actual. El controlador correcto en SIGMA es **`Docente/`**, pero toda la
app lo llama como **`Teacher/`**. Como el path no existe, cada petición docente
devuelve 404 / HTML, por lo que notas, asistencia, asignaturas y horario del
docente fallan de forma silenciosa (caen al caché vacío).

Además del prefijo, hay **divergencias de parámetros y de forma de respuesta**
en asistencia y horario que requieren un pequeño refactor del modelo.

Severidad y estado tras este cambio:

| # | Problema | Severidad | Estado |
|---|---|---|---|
| 1 | Prefijo `Teacher/` → debe ser `Docente/` (todos los endpoints) | 🔴 Bloqueante | ✅ Corregido |
| 2 | `GetAsignaturaDocenteV1` sin params → `GetAsignaturaDocente?modo=` | 🔴 Bloqueante | ✅ Corregido |
| 3 | Horario docente: `Schedule/getListaHorario` no existe | 🔴 Bloqueante | ✅ Corregido (adaptador que aplana `horario[]`) |
| 4 | `GetAsistencia` params `{cleAuto,codigoAlumno}` → `{plan,codSaltem,asignID}` | 🟠 Alto | ✅ Corregido (lectura) + modelo lleva plan/nrc |
| 5 | **Escritura de notas y asistencia con forma de API imaginada** | 🔴 Bloqueante | ⛔ Bloqueado a propósito (ver §9) |
| 6 | Fuente del "info docente" propio sin confirmar | 🟡 Medio | Documentado |

> Las **lecturas** (asignaturas, estudiantes, notas, asistencia, horario) quedan
> alineadas al contrato real. Las **escrituras** (registrar notas / asistencia)
> **no** se pueden implementar correctamente solo con el frontend: necesitan
> catálogos numéricos que solo devuelve el backend con una sesión real (§9).

## 0. Hallazgos verificados con cuenta real (octubre 2026)

Capturas en `prototype-ts/responses/docente/` y `docente_full/` (y
`prototype-ts/DOCENTE_API.md`). Lo que corrigen respecto a lo que suponía la app:

- **El roster NO sale de `ListarEstudianteComple`** (devuelve `[]` siempre). La
  lista real de alumnos sale de **`NotasEstudianteResumenV1?tipoCalificacion={tipoCalif}&cleAuto={id}`**,
  con `nombreCompleto`, `codigo`, `notaFinal`, `asistencia` y `matriculaAsignaturaId`.
  → la app ahora carga el roster desde ahí.
- **El info del docente NO sale de `GetInfoDocenteV1`** (es admin, 400 sin `filtro`).
  Sale de **`Login/GetDatosEntidad`** (`codigo`, `nombres`, `apellidos`,
  `isDocente`, `dependencia.facultad/cargo`). → corregido.
- `GetAsignaturaDocente` trae `tipoCalif` (p. ej. **12**), `plan`, `id`, `nrc`,
  `ciclo`, `carrera`, `sede`; **no** trae `codigo` ni `periodo` (el periodo va
  dentro del nombre, "… (2026-2)"). → modelo ajustado (code←nrc, periodo←nombre,
  +`tipoCalif`).
- Catálogo de **estado de asistencia**: `1`=Presente, `2`=Falta, `3`=Justificado.
  → mapeo de la UI corregido.
- Catálogos de notas: `getTipoUnidadesV2` → `tipo_unidad_id` (121…126);
  `getTipoNota` → `tipo_nota_id` (11=EV, 12=DE, 13=PR). Disponibles para escritura.

---

## Contrato real (extraído del cliente oficial de SIGMA)

Todas las rutas cuelgan de `https://sigma.upla.edu.pe/api`. `autorizacion:!0`
significa que van con `Authorization: Bearer <token>`.

### Asignaturas del docente

```
GET Docente/GetAsignaturaDocente?modo=Notas         // lista para registrar/ver notas
GET Docente/GetAsignaturaDocente?modo=Asistencia     // lista para asistencia
```

- El dashboard docente llama `GetAsignaturaDocente("Asistencia")` y
  `GetAsignaturaDocente("Notas")`.
- Cada asignatura trae, entre otros: `plan`, `id` (= *codSaltem* de la sección),
  `nrc` (= *asignID*) y un arreglo `horario` con los bloques de clase.
- `GetAsignaturaDocenteV1?filtro=...` **existe, pero es del módulo administrativo**
  (buscar docentes por filtro), no es la lista del propio docente.

### Horario del docente

- **No hay un endpoint dedicado.** El frontend construye el horario del docente
  a partir del arreglo `horario` de cada asignatura de `GetAsignaturaDocente`.
- `Schedule/getListaHorario` **no existe** en SIGMA. (La ruta real para el
  horario del *alumno* es `Horario/getListaHorario?id=&nivel=`, otra cosa.)

### Estudiantes de la sección

```
GET Docente/ListarEstudianteComple?codSaltem={id}
```

### Notas

```
GET  Docente/NotasEstudianteResumen?tipoCalificacion={t}&cleAuto={e}
GET  Docente/NotasEstudianteResumenV1?tipoCalificacion={t}&cleAuto={e}
POST Docente/InsertarNotas        body: { ... }
POST Docente/UpdateNota           body: { ... }
GET  Asignatura/getTipoNota?tipoUnidad={t}                 // ✅ la app ya lo llama bien
GET  Asignatura/getTipoUnidadesV2?tipoCalif=&cursal=&asi_id=&cle_auto=
```

### Asistencia

```
GET  Docente/GetAsistencia?plan={plan}&codSaltem={id}&asignID={nrc}
POST Docente/InsertaRegistroAsistencia          body: [ ... ]
POST Docente/ActualizarRegistroAsistencia       body: [ ... ]
GET  Docente/GetHora
```

La respuesta de `GetAsistencia` es una **lista de alumnos**, cada uno con:
`codigo`, `observacion` (p. ej. "Suspensión"), `matricula_asignatura_id`, y un
`detalle[]` de marcas con `fecha_asistencia` y `estado`. El guardado manda un
arreglo de `{ codigo, estado, matriculaAsignaturaId }`.

### Marcación del propio docente (no implementado en Nexo)

```
GET  Docente/getAsistenciaDocente
POST Docente/InsertaRegistroAsistenciaDocente?codigo={}
GET  Docente/getAsistenciaDiaria?fechaInicio=&fechaFin=&pagina=
GET  Docente/getHistorialMarcacion?fechaInicio=&fechaFin=&pagina=
```

---

## App actual vs. real (archivo `lib/data/teacher_repository.dart`)

| Método app | Lo que enviaba | Lo correcto |
|---|---|---|
| `infoDocente()` | `GET Teacher/GetInfoDocenteV1` | `GET Docente/GetInfoDocenteV1` (ver nota 6) |
| `asignaturas()` | `GET Teacher/GetAsignaturaDocenteV1` (sin params) | `GET Docente/GetAsignaturaDocente?modo=Notas` |
| `getHorario()` | `GET Schedule/getListaHorario` | derivar de `GetAsignaturaDocente` → `horario[]` |
| `estudiantesSeccion()` | `GET Teacher/ListarEstudianteComple?codSaltem=` | `GET Docente/ListarEstudianteComple?codSaltem=` |
| `notasResumen()` | `GET Teacher/NotasEstudianteResumenV1?...` | `GET Docente/NotasEstudianteResumenV1?...` |
| `updateNota()` | `POST Teacher/UpdateNota` | `POST Docente/UpdateNota` |
| `updateEvaluacion()` | `POST Teacher/InsertarNotas` | `POST Docente/InsertarNotas` |
| `asistenciaAlumno()` | `GET Teacher/GetAsistencia?cleAuto=&codigoAlumno=` | `GET Docente/GetAsistencia?plan=&codSaltem=&asignID=` |
| `asistenciaDelDia()` | `GET Teacher/GetAsistencia?cleAuto=` | idem (filtrar el `detalle` por fecha en cliente) |
| `guardarAsistenciaDelDia()` | `POST Teacher/InsertaRegistroAsistencia` | `POST Docente/InsertaRegistroAsistencia` (revisar body) |
| `_getTipoNota()` | `GET Asignatura/getTipoNota?tipoUnidad=` | ✅ correcto |

---

## Trabajo restante (recomendado, en orden)

1. **Modelo de sección** (`TeacherSubject`): además de `id`/`cleAuto`, exponer
   `plan`, `codSaltem` y `nrc` (asignID) y el arreglo `horario`, que son los que
   piden `GetAsistencia` y la derivación de horario.
2. **Horario docente**: eliminar `getHorario()` por endpoint y construir la lista
   de clases a partir de `asignaturas()` (`modo=Asistencia`), mapeando cada
   bloque de `horario[]` a `ScheduleClass`. Verificar los nombres crudos de los
   campos del bloque contra una respuesta real.
3. **Asistencia**: ajustar `asistenciaAlumno` / `asistenciaDelDia` para enviar
   `{plan, codSaltem, asignID}` y parsear la respuesta real
   (`codigo` + `detalle[].fecha_asistencia/estado` + `matricula_asignatura_id`).
   Ajustar el guardado al arreglo `{codigo, estado, matriculaAsignaturaId}`.
4. **Verificación con cuenta real**: correr la app con una cuenta docente y
   confirmar los nombres exactos de campos de respuesta (notas y asistencia),
   que son lo único que no se puede fijar solo leyendo el frontend.

> Nota legal: esto es paridad con lo que SIGMA ya expone al propio docente con su
> token. El acceso ampliado (ver datos del alumno fuera de la relación académica)
> sigue sujeto al plan de `plan-backend-docentes.md` y a consentimiento.

## 9. Escrituras: forma real y por qué están bloqueadas

El frontend revela la forma exacta de los POST, y confirma que la app las enviaba
con una estructura inventada. Las formas reales son:

**`Docente/InsertarNotas` / `Docente/UpdateNota`**
```json
{ "Notas": [ {
    "matricula_asignatura_id": <id del alumno en la sección>,
    "tipo_unidad_id": <unidadId>,
    "tipo_nota_id": <idTipoNota>,
    "nota_id": <sólo UpdateNota>,
    "nota": <valor>
} ] }
```

**`Docente/InsertaRegistroAsistencia`**
```json
{ "fecha_asistencia": "YYYY-MM-DD H:M:S",
  "asistencia": [ {
    "matricula_asignatura_id": <id>,
    "estado_asist_id": <id NUMÉRICO de estado>,
    "cod_cursal": <cod_cursal del alumno>,
    "tipo_unidad_id": <unidadId>
} ] }
```

**Por qué no se implementan a ciegas:** requieren ids que no aparecen en el
frontend y solo llegan en respuestas reales:
- `matricula_asignatura_id` y `cod_cursal`: vienen en la respuesta de `GetAsistencia`.
- `tipo_unidad_id`: de `Asignatura/getTipoUnidadesV2?tipoCalif=&cursal=&asi_id=&cle_auto=`.
- `tipo_nota_id`: de `Asignatura/getTipoNota?tipoUnidad=` (campo `idTipoNota`).
- `estado_asist_id`: **catálogo numérico de estados** (presente=?, tardanza=?,
  falta=?, suspensión=4…). No es P/T/F. Sin este catálogo, cualquier envío
  registraría asistencia con el estado equivocado.

Enviar una forma adivinada podría **registrar notas o asistencia incorrectas**
(corrupción de datos), así que:
- El guardado de asistencia (`guardarAsistenciaDelDia`) lanza un error 501 claro
  y la pestaña de asistencia es **de solo lectura** con un aviso en la app.
- El guardado de notas conserva el prefijo corregido pero su *body* sigue sin
  alinear; fallará en el servidor hasta completar el mapeo. No se cambió a una
  forma adivinada por el mismo motivo.

**Para desbloquear (una sola verificación con cuenta real):** capturar una
respuesta de `GetAsistencia` y de `getTipoUnidadesV2`/`getTipoNota`, y el catálogo
de estados. Con eso se completan ambas escrituras con certeza.

## 10. Mejoras de UI incluidas en este cambio

- Buscador de alumnos (por nombre o código) en las pestañas **Alumnos** y
  **Notas** del detalle del curso, con contador de resultados.
- Pestaña **Asistencia** rediseñada como vista de solo lectura: muestra el estado
  registrado por alumno para la fecha elegida, con contador y aviso honesto de
  que el registro desde la app llegará pronto (en vez de un botón que siempre
  fallaba).
- Modelo `TeacherSubject` ahora expone `plan`, `codSaltem` y `nrc`; `TeacherStudent`
  expone `matriculaAsignaturaId` y `observacion` (persistidos en caché), dejando
  todo listo para completar las escrituras cuando se tenga el catálogo.
