package pe.upla.nexo

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/**
 * Instala el APK que descargó UpdateService (Dart) por el canal
 * `nexo/updater`.
 *
 * Dart ya comprobó el SHA-256 contra version.json; aquí se comprueba lo que
 * Dart no puede ver: que el archivo sea esta misma app, más nueva, y firmada
 * con la misma clave. Sin esto, un version.json alterado podría hacer que el
 * usuario instalara otra app con un toque, porque Android solo exige la misma
 * firma cuando el paquete coincide.
 */
class ApkInstaller(private val activity: Activity) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canInstall" -> result.success(canInstall())
            "openInstallSettings" -> {
                openInstallSettings()
                result.success(null)
            }
            "install" -> {
                val path = call.argument<String>("path")
                result.success(if (path == null) "invalid_file" else install(File(path)))
            }
            else -> result.notImplemented()
        }
    }

    /** Si Android ya autorizó a Nexo a instalar apps desconocidas. */
    private fun canInstall(): Boolean =
        BuildConfig.DIRECT_DIST &&
            (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                activity.packageManager.canRequestPackageInstalls())

    /** Abre el ajuste de «instalar apps desconocidas» de Nexo. */
    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        activity.startActivity(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${activity.packageName}"),
            )
        )
    }

    private fun install(file: File): String {
        if (!BuildConfig.DIRECT_DIST) return "unsupported"
        // Solo lo que dejó el actualizador, en la carpeta que comparte el
        // FileProvider: nada de rutas arbitrarias desde Dart.
        val updates = File(activity.filesDir, "updates").canonicalFile
        val apk = file.canonicalFile
        if (apk.parentFile != updates || !apk.isFile) return "invalid_file"

        val pm = activity.packageManager
        val archive = archiveInfo(pm, apk) ?: return "invalid_file"
        val installed = pm.getPackageInfo(activity.packageName, signatureFlags())
        if (archive.packageName != activity.packageName) return "wrong_package"
        if (PackageInfoCompat.getLongVersionCode(archive) <=
            PackageInfoCompat.getLongVersionCode(installed)
        ) {
            return "not_newer"
        }
        val expected = signers(installed)
        if (expected.isEmpty() || signers(archive) != expected) return "wrong_signature"
        if (!canInstall()) return "needs_permission"

        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", apk)
        activity.startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        return "started"
    }

    private fun archiveInfo(pm: PackageManager, apk: File): PackageInfo? {
        val info = pm.getPackageArchiveInfo(apk.path, signatureFlags())
        // Algunas versiones de Android no devuelven signingInfo para un APK
        // suelto; el flag antiguo sí trae las firmas.
        if (info != null && signers(info).isEmpty()) {
            @Suppress("DEPRECATION")
            return pm.getPackageArchiveInfo(apk.path, PackageManager.GET_SIGNATURES)
        }
        return info
    }

    @Suppress("DEPRECATION")
    private fun signatureFlags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }

    /** SHA-256 de cada certificado con que está firmado el contenido. */
    @Suppress("DEPRECATION")
    private fun signers(info: PackageInfo): Set<String> {
        val signatures =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && info.signingInfo != null) {
                info.signingInfo!!.apkContentsSigners
            } else {
                info.signatures
            } ?: return emptySet()
        val sha = MessageDigest.getInstance("SHA-256")
        return signatures.map { sig ->
            sha.digest(sig.toByteArray()).joinToString("") { "%02x".format(it) }
        }.toSet()
    }
}
