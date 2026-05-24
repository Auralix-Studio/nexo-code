# Nexo · UPLA

Cliente multiplataforma (Android, iOS, Web, Windows, macOS, Linux) para
estudiantes UPLA. Consume el API real de SIGMA mediante peticiones HTTP
propias — sin SDK ni cliente de terceros para autenticación o sesión.

## Plataformas soportadas
- Android · iOS · Web · Windows · macOS · Linux (un solo código)

## Stack
- **Flutter** (Material 3, sin paquetes de estado de terceros)
- `package:http` — únicamente como transporte HTTP base
- `package:shared_preferences` — persistencia local del token

## Arquitectura
```
lib/
├── core/             Config, errores, storage
├── data/             ApiClient, SigmaRepository, Session
├── domain/           Modelos puros
└── ui/
    ├── theme.dart
    ├── screens/      LoginScreen · HomeScreen
    └── widgets/      TodayClassesWidget · PendingPaymentsWidget · …
```

- `ApiClient` — HTTP propio con manejo manual de tokens, headers y errores tipados.
- `SigmaRepository` — mapea endpoints SIGMA → modelos.
- `SessionService` — auth + persistencia + estado reactivo (`ChangeNotifier`).

## Cómo correr

### Web (rápido para iterar)
```sh
flutter run -d chrome
```
> ⚠ El backend de SIGMA puede bloquear CORS para Web. Si pasa, ejecuta
> Chrome con CORS desactivado solo para desarrollo:
> `chrome --disable-web-security --user-data-dir=/tmp/chrome-dev`.
> En móvil/escritorio no hay esa restricción.

### Escritorio Windows
```sh
flutter run -d windows
```

### Android
```sh
flutter run -d android
```

## Widgets de pantalla principal

- **Hoy** — clases del día actual, ordenadas por hora, con estado *en curso* /
  *pasada* y aula. Calculado en cliente desde el horario completo.
- **Pagos pendientes** — cuotas no vencidas + total, ordenadas por fecha,
  con etiquetas *VENCIDA*, *VENCE HOY*, *Mañana* o *En N días*.

## Endpoints SIGMA consumidos

Ver [`../prototype-ts/API.md`](../prototype-ts/API.md) — documentación
generada a partir de respuestas reales.

| Endpoint | Para |
|---|---|
| `POST /Login/SesionV1` | Auth (clave en base64) |
| `GET /Estudiante/MostrarInfoEstudiante` | Perfil |
| `GET /Intranet/ListarHorariosEstudianteIntranet/*/*` | Horario |
| `GET /Estudiante/ListarCoutasNoVencidas?TipDI=12` | Deudas |
| `GET /Estudiante/MostrarNotasResumen/{plan}/{nivel}` | Promedios/créditos |

## Tests
```sh
flutter test
```
