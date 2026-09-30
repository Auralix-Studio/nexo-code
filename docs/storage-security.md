# Almacenamiento y aislamiento de sesiones

## Decisión: SQLite para la caché, almacén del sistema para secretos

SQL organiza datos en tablas y permite consultas y transacciones. NoSQL agrupa
modelos como documentos, clave-valor y grafos; su conveniencia depende de las
consultas y garantías que necesita la aplicación. Ninguna elección protege por
sí misma una contraseña ni cancela peticiones de una cuenta anterior.

Nexo conserva SQLite: es una aplicación cliente con caché local de información
académica, sin un servidor propio que necesite una base distribuida. SQLite no
requiere desplegar un servicio adicional y permite cambiar el propietario de la
caché y eliminar sus filas en una transacción.

Referencias: [usos de SQLite](https://www.sqlite.org/whentouse.html) y
[flutter_secure_storage 10.3.4](https://pub.dev/packages/flutter_secure_storage/versions/10.3.4).

## Separación de responsabilidades

- **SQLite:** datos académicos de la cuenta activa. `cache_owner` identifica al
  propietario; cambiar de cuenta elimina la caché anterior transaccionalmente.
  Al salir se eliminan también los datos y el propietario. La base académica no
  está cifrada; el aislamiento entre cuentas de Nexo no equivale a cifrado del disco.
- **SharedPreferences:** ajustes visuales y preferencias no secretas. Se conserva
  una pequeña caché de resúmenes, eliminada al salir y al migrar datos antiguos.
- **Almacén seguro nativo:** contraseña reutilizable, token, perfil de sesión y
  cookies de intranet en un único registro, mediante `flutter_secure_storage`.
  Las escrituras se serializan para que un guardado anterior no deshaga un logout.
- **Web:** secretos exclusivamente en memoria. Recargar/cerrar la aplicación
  requiere iniciar sesión de nuevo. No se persisten contraseñas en LocalStorage.

SIGMA e Intranet todavía requieren la contraseña para reautenticar. Por eso se
protege en el almacén del sistema: sustituirla por un hash impediría ese flujo.
No hay una clave de cifrado incorporada al código ni retorno a texto plano si
el almacén seguro falla.

## Migraciones

El primer arranque migra los secretos antiguos de preferencias al almacén
seguro. Elimina sus copias en preferencias y la caché sin propietario. Si el
almacén falla, no conserva esas copias inseguras; puede requerirse iniciar sesión
nuevamente cuando el almacén esté disponible.

SQLite pasa de versión 2 a 3. Se reconstruyen las tablas de caché, incluidas las
bases vacías creadas por el defecto anterior. Solo se descartan datos descargables
de la universidad, no registros originales del servidor.

## Peticiones concurrentes

`SessionScope` conserva la generación de sesión de cada operación asíncrona,
incluidos reintentos, fuentes alternativas y precargas. Al salir o iniciar otra
sesión se invalida la generación. Los clientes comprueban esa generación antes
de enviar peticiones y después de recibir respuestas; AppStore comprueba antes
de modificar estado o persistir datos. Una petición de A nunca debe reintentarse
con el token de B. Los callbacks y cookies de Intranet también se descartan.

La composición en `main.dart` comparte el mismo scope entre todos los clientes,
el store y la caché. Las nuevas operaciones asíncronas deben mantener ese scope
y comprobarlo antes de efectos secundarios después de un `await`.

## Escrituras docentes

HTTP 200 no significa guardado confirmado. Notas, evaluaciones y asistencia
exigen `success` afirmativo en la respuesta. Una respuesta rechazada, vacía,
malformada o sin confirmación produce error en la interfaz.

## Compilación y comprobaciones

- Android: copias de seguridad desactivadas para evitar restaurar secretos sin
  sus claves del dispositivo.
- Linux: requiere `libsecret-1-dev` al compilar, `libsecret-1-0` y un servicio de
  keyring al ejecutar. El workflow instala la dependencia de compilación.
- macOS: usa Keychain sin data-protection keychain, evitando exigir Keychain
  Sharing para distribuir la aplicación de escritorio.

Pruebas locales, sin acceder a UPLA:

```sh
flutter test test/security_regression_test.dart test/cache_account_test.dart
flutter test
flutter analyze --no-pub
```

Las pruebas usan un almacén simulado; validar Keychain/Keystore/almacén Windows
en dispositivos reales sigue siendo parte de la validación de cada plataforma.
