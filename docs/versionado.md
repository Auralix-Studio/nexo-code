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

Reproduce en GitHub, sin intervención, lo que hacían a mano
`bump_version.ps1`, `sync_version.ps1`, `build_release.ps1`,
`generate_release_notes.ps1` y `update_site.ps1`:

| Paso | Antes (a mano) | Ahora (automático) |
|---|---|---|
| Tests | — | `flutter test`; si falla, no se publica |
| Subir versión | `bump_version.ps1` + `sync_version.ps1` | `auto_version.py` (pubspec, config.dart, CHANGELOG) |
| Commit y tag | `build_release.ps1 -Publish` | commit `chore(release): vX.Y.Z` + tag en `nexo-code` |
| Compilar | `build_release.ps1` (Android + Windows) | `release.yml`: Android, Windows, Linux, macOS, iOS |
| Verificar Windows | `verify_windows_bundle.ps1`, `scan_windows_release.ps1` | los mismos scripts, en el runner de Windows |
| `SHA256SUMS.txt` | `build_release.ps1` | `release_assets.py sums` (todos los archivos) |
| `RELEASE_NOTES.md`, `release-meta.json` | `generate_release_notes.ps1` | `release_assets.py notes` |
| Release en `Auralix-Studio/nexo` | `gh release create` | se crea **una sola vez con todo** (el actualizador nunca ve un release a medias) |
| Sitio: `CHANGELOG.md` y `changelog.html` | `update_site.ps1 -Push` | `release_assets.py site` + push; Pages lo despliega |
| `version.json` (lo lee el actualizador de la app) | — | `release_assets.py manifest`; va al release y, **ya publicado el release**, al sitio (`nexo.aurx.pro/version.json`) |

Si falla una plataforma secundaria (iOS, macOS, Linux) el release sale
igual; si falta Android o Windows, no se publica.

Los scripts `.ps1` siguen funcionando para publicar a mano si alguna vez
hace falta.

## Notas del release

- Si `CHANGELOG.md` tiene una sección `## [Sin publicar]`, se usa tal cual y
  solo se le pone número y fecha. Es la forma de escribir notas a mano.
- Si no la tiene, se generan desde los commits (Novedades / Correcciones /
  Otros cambios).

## Forzar una versión

Actions → **Versionado automático** → *Run workflow* → elegir
`patch`, `minor` o `major`.

## Secretos necesarios

Se guardan en `nexo-code` → **Settings → Secrets and variables → Actions →
New repository secret**.

### `ORG_GITHUB_TOKEN` (obligatorio)

Permite publicar el release y el changelog del sitio en `Auralix-Studio/nexo`.
El `GITHUB_TOKEN` automático no sirve porque solo tiene acceso a `nexo-code`.

1. GitHub → foto de perfil → **Settings → Developer settings → Personal access
   tokens → Fine-grained tokens → Generate new token**.
2. **Resource owner:** `Auralix-Studio` (si no aparece, un admin de la
   organización debe permitir fine-grained tokens en la organización).
3. **Repository access:** *Only select repositories* → `nexo`.
4. **Permissions → Repository permissions → Contents: Read and write**
   (Metadata: Read se agrega solo).
5. **Expiration:** la que prefieras; al vencer, el release falla con un aviso
   claro y basta con generar otro y reemplazar el secreto.
6. Copia el token y créalo en `nexo-code` como secreto `ORG_GITHUB_TOKEN`.

Si la organización exige aprobación, el token queda *pending* hasta que un
admin lo apruebe en Auralix-Studio → Settings → Personal access tokens.

### Firma Android (opcional, recomendado)

| Secreto | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | el `.jks` en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | contraseña del keystore |
| `ANDROID_KEY_ALIAS` | alias (por defecto `nexo`) |
| `ANDROID_KEY_PASSWORD` | contraseña de la clave |

Sin ellos el APK se firma con la clave de depuración y **no se instala
encima** de una versión firmada. Para generar `ANDROID_KEYSTORE_BASE64`:
`base64 -w0 nexo-release.jks` (en Windows:
`[Convert]::ToBase64String([IO.File]::ReadAllBytes("nexo-release.jks"))`).

### Actualización obligatoria

`scripts/release_policy.json` → `min_build`: las versiones con un build menor
dejaron de funcionar y la app pide actualizar sin dejar cerrar el aviso.
Subirlo solo cuando algo externo rompa las versiones anteriores.

## Si un release falla

Actions → **Release multiplataforma** → *Run workflow* → escribir el tag
(p. ej. `v1.8.0`). Vuelve a compilar y publica sin crear otra versión.
Si solo falló la publicación, en la ejecución fallida basta con
*Re-run failed jobs*.

## Ver qué versión saldría

```sh
python3 scripts/auto_version.py next
```

En cada PR a `main`, el workflow **CI** muestra en el resumen la versión
que se publicaría al fusionarlo.
