import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
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

android {
    namespace = "pe.upla.nexo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Requerido por flutter_local_notifications (APIs de fecha/hora).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Identidad pública de la app, en el dominio de Auralix Studio: un
        // "pe.upla.*" se leía como app oficial de la universidad. El
        // `namespace` (paquete del código Kotlin) se queda como está; no es
        // visible para el usuario ni cambia la identidad del APK.
        // Cambió junto con la clave de firma propia (octubre 2026): quien tenga
        // una versión anterior debe desinstalarla una vez.
        applicationId = "com.auralix.nexo"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // El universal incluye todas las ABI solicitadas por Flutter.
        // Distribuir los APK --split-per-abi para reducir la descarga sin
        // excluir dispositivos compatibles; conservar el universal de respaldo.
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

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
