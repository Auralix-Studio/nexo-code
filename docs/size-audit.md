# Auditoría de tamaño — 2026-09-30

## Diagnóstico

Medición de los artefactos locales v1.7.1 en `dist/`, antes de la limpieza.
MB decimales (1 MB = 1 000 000 bytes); no confundir descarga, contenido
descomprimido y almacenamiento ocupado después de instalar y usar la app.

| Artefacto | Descarga (MB) |
| --- | ---: |
| Android universal | 66,88 |
| Android ARM64 | 23,93 |
| Android ARMv7 | 21,79 |
| Android x86_64 | 25,33 |
| Instalador Windows x64 | 18,47 |
| ZIP Windows x64 | 18,30 |

El universal contiene 64,66 MB de bibliotecas nativas: ARM64 21,80 MB,
ARMv7 19,65 MB y x86_64 23,20 MB. Su tamaño se explica principalmente por
incluir tres arquitecturas. El APK ARM64 existente es un 64,2 % menor;
esta diferencia **ya existía**, no es ahorro producido por esta revisión.

Los assets Flutter del universal suman 0,90 MB sin comprimir y 0,51 MB
comprimidos. Reducir imágenes o quitar pantallas no es la prioridad.
Android ya activa R8, reducción de recursos y reducción de iconos
(MaterialIcons ocupa 25 156 bytes en el APK inspeccionado).

El ZIP Windows contiene 41,88 MB sin comprimir, incluyendo el runtime de
Microsoft. En la carpeta Release, los principales componentes son Flutter
(18,51 MB), código compilado (10,50 MB), PDFium (4,75 MB) y SQLite (1,67 MB).
PDFium y SQLite respaldan funciones existentes; no se retiraron.

## Cambios

- Retiradas dependencias directas sin referencias en el código ni las pruebas:
  `cupertino_icons`, `flutter_svg` y `open_filex`.
- Retiradas sus dependencias transitivas exclusivas: `vector_graphics`,
  `vector_graphics_codec` y `vector_graphics_compiler`.
- Corregidos comentarios de Gradle que afirmaban excluir x86_64 y conservar
  bibliotecas de IA, aunque no correspondían a la configuración actual.
- Añadido `scripts/measure_size.ps1`, de solo lectura, para auditar archivos
  finales por arquitectura, assets y componentes más grandes.

La limpieza evita empaquetar la fuente Cupertino sin uso (257 628 bytes
sin comprimir en los artefactos anteriores) y registrar el plugin OpenFilex.
No se atribuye todo el peso de los paquetes Dart retirados al ejecutable:
el compilador ya puede eliminar código no utilizado.

## Distribución

Los dos pipelines ya generan APKs por arquitectura. Para dispositivos ARM64,
ofrecer el archivo `-arm64.apk`; conservar el universal para cuando no se
conozca la arquitectura y las variantes ARMv7/x86_64 para sus dispositivos.
No se cambió el sitio de descargas ni se publicó una versión.

No hay evidencia de que una reescritura o quitar funciones sea necesaria
para resolver el peso de descarga observado.

## Repetir la medición

```powershell
./scripts/measure_size.ps1 | Select-Object Artifact, MB, UnpackedBytes
./scripts/measure_size.ps1 | ConvertTo-Json -Depth 6
flutter build apk --release --split-per-abi --target-platform android-arm64
./scripts/measure_size.ps1 -ArtifactDir build/app/outputs/flutter-apk
flutter build windows --release
flutter analyze --no-pub
flutter test --no-pub
```

Comparar builds de la misma revisión, SDK, arquitectura y configuración
para atribuir ahorros con precisión. Los archivos `dist/` anteriores se
conservaron y no representan los cambios nuevos hasta volver a empaquetar.

## Alcance de rendimiento

El código ya cuenta con caché local, deduplicación de solicitudes en vuelo,
supresión de actualizaciones repetidas de widgets/notificaciones y un límite
de decodificación de imagen para el avatar. Esto no certifica tiempos ni RAM.
Para afirmar mejoras en fluidez, consumo de memoria o arranque hace falta
medir en modo profile en dispositivos representativos, con la misma cuenta,
datos y condiciones de red. Las pruebas automatizadas no sustituyen esa
medición. No se aplicaron cambios especulativos al comportamiento de la app.

## Validación

- `flutter analyze --no-pub`: sin problemas.
- `flutter test --no-pub`: 158 pruebas correctas.
- Android ARM64 split compiló correctamente: 23 820 423 bytes (23,82 MB),
  frente a 23 929 698 bytes del APK anterior: 109 275 bytes menos (0,46 %).
  El ZIP interno contiene únicamente bibliotecas ARM64 y ya no incluye la
  fuente Cupertino. Comparación contra el artefacto local anterior, no contra
  un segundo build de control de la misma revisión.
- Script de medición: sintaxis y suma de componentes comprobadas contra
  el tamaño descomprimido de los APK y ZIP existentes.
- Windows release compiló correctamente. La carpeta Release pasó de
  39 845 133 a 39 615 153 bytes (unos 0,23 MB menos frente al artefacto local
  anterior). La fuente Cupertino ya no se incluye. No es la medida del
  instalador ni una comparación controlada entre dos builds nuevos.
- Fue necesario regenerar la caché CMake, que todavía apuntaba a la antigua
  ubicación del proyecto, y los assets que retenían fuentes retiradas.
  Los respaldos locales quedan en `build/size-audit-windows-before` y
  `build/size-audit-assets-before`.
- La compilación Android requiere regenerar el registro de plugins para
  release; no omitir `pub` inmediatamente después de cambiar dependencias.
  Un build con `--target-platform android-arm64` sin `--split-per-abi` todavía
  incluyó SQLite/JNI de otras ABI (27,45 MB): usar el comando split de arriba
  para medir un APK de una sola arquitectura.
