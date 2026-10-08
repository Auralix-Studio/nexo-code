# Instalador de Windows

`installer/build_installer.ps1` genera un EXE gráfico x64 con el ZIP como
recurso PE. No ejecuta CMD en el equipo del usuario. El auxiliar
`nexo_setup_helper.exe` inicia PowerShell con `CREATE_NO_WINDOW`, comprueba
su salida y utiliza comandos codificados y rutas literales.

El paquete incluye únicamente los ejecutables, DLL, recursos de Flutter y
runtime de Visual C++. Excluye cachés de desarrollo y paquetes MSIX previos.
`-ZipOutFile` genera el mismo contenido para uso portable; `-ZipOnly` omite
el EXE. GitHub Actions y el script de publicación local usan este generador.

La extracción usa una carpeta única en `%LOCALAPPDATA%\Nexo\_stage`.
La instalación prepara y valida una copia antes de renombrar `bin` a
`bin.previous`. Si falla la sustitución, restaura la anterior. La siguiente
instalación puede recuperar una interrupción entre renombres. Se solicita
el cierre normal de la instancia instalada; no se fuerza su terminación.

SQLite usa `%LOCALAPPDATA%\Nexo\data`. El primer arranque intenta migrar
los cachés anteriores bajo `bin` o `bin.previous` mediante `VACUUM INTO`.
La desinstalación conserva datos salvo que se seleccione borrarlos; esa opción
elimina el secreto de sesión mediante su API, preferencias y base SQLite.
La limpieza de binarios se ejecuta sin consola después de terminar la app.

El actualizador acepta solo `nexo-vX.Y.Z-setup-x64.exe` del release esperado.
Verifica SHA-256 después de descargar y antes de ejecutar. Usa el digest de
la API de GitHub o el manifiesto SHA256SUMS del mismo release por HTTPS.
Si falta el digest, no ejecuta el paquete. Los hashes no sustituyen una firma
de editor ni protegen frente a un compromiso del repositorio de publicaciones.

Para firmar el EXE, configurar `NEXO_SIGN_CERT_SHA1` con un certificado de firma
de código ya instalado y con clave privada accesible al proceso de compilación.
El generador aplica Authenticode con timestamp; un fallo de firma aborta la
publicación. Sin certificado produce un EXE sin firma y lo advierte. No se
promete evitar advertencias de SmartScreen o de todos los antivirus.

Antes de publicar, el flujo local (incluido `-SkipBuild`) y GitHub Actions
ejecutan `scripts/scan_windows_release.ps1` sobre el EXE y el ZIP. Una detección,
un error del escáner o la ausencia de Defender interrumpe la publicación de
Windows. El análisis no agrega exclusiones ni cambia la configuración de
Defender; `-DisableRemediation` conserva los archivos analizados para revisión.
Un resultado limpio solo representa ese análisis, no garantiza futuros
veredictos de Defender ni de otros antivirus.

La versión 1.7.1 fue detectada localmente como `Trojan:Win32/Sabsik.EN.D!ml`.
El EXE sin firma tiene SHA-256
`e48e93b1fb5382a245f4d54d48f37acc678ca578ce1a17c54ad95bf03df5da8b`.
El ZIP pasó el análisis y su hash coincide con el recurso incrustado en el EXE.
Esto no confirma un falso positivo. El binario original debe revisarse mediante
el [portal de Microsoft Security Intelligence](https://www.microsoft.com/en-us/wdsi/filesubmission)
como desarrollador de software; no se debe desactivar el antivirus ni presentar
una firma de editor como solución garantizada a una detección.

La ventana nativa de Flutter permanece oculta durante el arranque.
`WindowsStartup.prepare` termina de configurar tamaño, tema y posición antes
de `runApp`; se muestra una sola vez después del primer frame rasterizado.
Este flujo también cubre el desinstalador y el error de carga de preferencias.

Validación de paquete sin instalarlo:

```powershell
./scripts/verify_windows_bundle.ps1 -Installer dist/nexo-v1.6.6-setup-x64.exe -Zip dist/nexo-v1.6.6-windows-x64.zip
```

Las pruebas Dart cubren copia interrumpida, paquete incompleto, recuperación,
filtro de arquitectura, rutas y alteraciones de igual tamaño. Probar además
instalación, actualización y desinstalación en una VM Windows limpia antes de
publicar: las pruebas locales no sustituyen esa comprobación completa.
