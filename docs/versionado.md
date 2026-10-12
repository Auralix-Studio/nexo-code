# Versionado automático

Las versiones se publican solas al fusionar en `main`
(`.github/workflows/auto-version.yml`). No hay que tocar `pubspec.yaml`,
`config.dart` ni crear tags a mano.

## Cómo se decide la versión

Se leen los commits desde el último tag `vX.Y.Z` (Conventional Commits):

| Commit | Versión |
|---|---|
| `feat!: …`, `fix(x)!: …` o `BREAKING CHANGE:` en el cuerpo | **major** (2.0.0) |
| `feat: …` | **minor** (1.8.0) |
| `fix:`, `perf:`, `refactor:`, `chore:`, `build:`, `revert:` o un mensaje libre | **patch** (1.7.2) |
| Solo `docs:`, `ci:`, `test:`, `style:` | no se publica |

El número de build (`+N`) sube 1 en cada versión.

## Qué hace el workflow

1. Corre `flutter test`. **Si falla, no se publica nada.**
2. Calcula la versión (`scripts/auto_version.py`) y actualiza
   `pubspec.yaml`, `lib/core/config.dart` y `CHANGELOG.md`.
3. Hace commit `chore(release): vX.Y.Z [skip ci]` en `main` y crea el tag.
4. Llama a `release.yml`: compila Android, Windows, Linux, macOS e iOS y
   publica el release en `Auralix-Studio/nexo` con las notas del CHANGELOG.
   El actualizador de la app lo detecta desde ahí.

## Notas del release

- Si `CHANGELOG.md` tiene una sección `## [Sin publicar]`, se usa tal cual y
  solo se le pone número y fecha. Es la forma de escribir notas a mano.
- Si no la tiene, se generan desde los commits (Novedades / Correcciones /
  Otros cambios).

## Forzar una versión

Actions → **Versionado automático** → *Run workflow* → elegir
`patch`, `minor` o `major`.

## Secretos necesarios

| Secreto | Para |
|---|---|
| `ORG_GITHUB_TOKEN` | Publicar el release en `Auralix-Studio/nexo` (ya existía) |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Firmar el APK con la clave de release. Sin ellos se firma con la de depuración y **no se instala encima** de una versión firmada |

Para generar `ANDROID_KEYSTORE_BASE64`: `base64 -w0 nexo-release.jks`
(en Windows: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("nexo-release.jks"))`).

## Ver qué versión saldría

```sh
python3 scripts/auto_version.py next
```

En cada PR a `main`, el workflow **CI** muestra en el resumen la versión
que se publicaría al fusionarlo.
