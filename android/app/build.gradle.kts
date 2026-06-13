plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

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
        applicationId = "pe.upla.nexo"
        // MediaPipe LLM Inference (Lumen vía flutter_gemma) requiere Android 7.0+.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Excluimos x86_64 del APK universal. Solo lo necesitan emuladores
        // y agregaba ~80 MB de native libs (incluyendo el LLM engine duplicado).
        // Si en el futuro hay que dar build de emulador, generarlo aparte
        // con `flutter build apk --target-platform android-x64`.
        // ndk {
        //     abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        // }
    }

    // flutter_gemma empaqueta toda la pila MediaPipe (vision, image-gen,
    // embeddings, RAG, vector store, LiteRT, …) aunque Lumen solo usa
    // LLM Inference. Cada .so excluido aquí baja ~10-20 MB del APK.
    //
    // Verificado: el código Dart solo consume `InferenceModel`,
    // `InferenceChat`, `Message.text`, `TextResponse`. No hay vision,
    // ni image gen, ni embeddings, ni vector store, ni LiteRT.
    //
    // Si en el futuro Lumen agrega alguna de esas features, retirar la
    // exclusión correspondiente — el `System.loadLibrary` fallaría con
    // UnsatisfiedLinkError si la lib se necesita en runtime.
    packaging {
        jniLibs {
            excludes += setOf(
                "**/libmediapipe_tasks_vision_jni.so",
                "**/libmediapipe_tasks_vision_image_generator_jni.so",
                "**/libimagegenerator_gpu.so",
                "**/libgecko_embedding_model_jni.so",
                "**/libgemma_embedding_model_jni.so",
                "**/libtext_chunker_jni.so",
                "**/libsqlite_vector_store_jni.so",
            )
        }
    }

    buildTypes {
        release {
            // Firmamos con la debug key por ahora (mismo comportamiento que
            // tenía antes). Cuando salgamos a Play Store o firma oficial,
            // reemplazar por signingConfigs.create("release") con keystore.
            signingConfig = signingConfigs.getByName("debug")

            // R8 minify + resource shrinking. Las reglas para preservar
            // MediaPipe/Protobuf/TFLite viven en proguard-rules.pro.
            // Sin esto, `proguardFiles` se cargaba pero R8 nunca corría
            // (el default de AGP es isMinifyEnabled=false).
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
