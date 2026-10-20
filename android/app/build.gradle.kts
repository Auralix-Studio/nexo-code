import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Claves de firma para Play Store. Viven en android/key.properties, que NO se
// versiona: es un secreto. Sin ese archivo la release se firma con la clave de
// depuración, que sirve para probar en local pero Google Play rechaza.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

// Build para tiendas: `--dart-define=STORE_BUILD=true`, el mismo flag que lee
// Dart (StoreBuild.isStore). Flutter le pasa los dart-define a Gradle en
// base64. Sin él se arma el APK de distribución directa (GitHub), que se
// actualiza solo; con él, el de Google Play, que no puede instalar APKs.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.mapNotNull { runCatching { String(Base64.getDecoder().decode(it)) }.getOrNull() }
        ?.mapNotNull { entry ->
            entry.split("=", limit = 2).takeIf { it.size == 2 }?.let { it[0] to it[1] }
        }
        ?.toMap()
        ?: emptyMap()
val isStoreBuild = dartDefines["STORE_BUILD"] == "true"

// Último dígito del versionCode según el APK. Ver `versionCode` abajo.
val abiDigit = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 4)

android {
    namespace = "com.auralix.nexo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Requerido por flutter_local_notifications (APIs de fecha/hora).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identidad de Auralix Studio, compartida con el namespace y las
        // clases Kotlin, incluidos los proveedores de widgets.
        applicationId = "com.auralix.nexo"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // 100000 + build * 10 + dígito de ABI (0 universal). Así todos los
        // APK de una versión quedan por encima de todos los de la anterior:
        // con el esquema de Flutter (abi * 1000 + build) el universal de la
        // 24 valía menos que el ARM64 de la 23 y Android lo rechazaba como
        // «versión anterior». El 100000 deja atrás todo lo ya publicado
        // (hasta 4024, el x86_64 de la 1.9.0).
        versionCode = 100000 + flutter.versionCode * 10
        versionName = flutter.versionName

        buildConfigField("boolean", "DIRECT_DIST", (!isStoreBuild).toString())
    }

    buildFeatures {
        buildConfig = true
    }

    // Bibliotecas nativas comprimidas dentro del APK. Sin comprimir Android
    // las carga sin extraerlas, pero la descarga pesa el doble (24,8 MB contra
    // ~12 MB el ARM64, medido en la 1.9.0). Para un APK que se baja por datos
    // móviles conviene comprimir; a cambio, instalada ocupa ~10 MB más.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    // Distribución directa: permiso para instalar el APK descargado, el
    // FileProvider que se lo pasa al instalador y la revisión diaria. Fuera
    // del manifiesto principal para que un build de tienda nunca los lleve,
    // aunque alguien olvide el flag: Play rechaza REQUEST_INSTALL_PACKAGES.
    if (!isStoreBuild) {
        for (type in listOf("debug", "profile", "release")) {
            sourceSets.getByName(type).manifest.srcFile("src/direct/AndroidManifest.xml")
        }
    }



    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Reducir codigo y recursos Android en las compilaciones release.
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Después del plugin de Flutter, que numera los APK por ABI como
// abi * 1000 + build: aquí se reemplaza por el esquema de defaultConfig.
@Suppress("DEPRECATION")
android.applicationVariants.configureEach {
    val base = versionCode
    outputs.configureEach {
        val apk = this as com.android.build.gradle.api.ApkVariantOutput
        val abi = apk.getFilter(com.android.build.VariantOutput.FilterType.ABI)
        apk.versionCodeOverride = base + (abiDigit[abi] ?: 0)
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // FileProvider, para pasarle el APK descargado al instalador. Ya llega por
    // los plugins; se declara porque el código propio lo usa directamente.
    implementation("androidx.core:core:1.13.1")
}
