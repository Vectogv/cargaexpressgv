import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Llave de producción: android/key.properties (fuera de git). Sin ella el
// release se firma con la llave de pruebas, para que compile en cualquier equipo.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "co.cargaexpress.app"

    // Se fuerza la compilación con Android SDK 36
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "co.cargaexpress.app"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Dos apps del mismo código: `flutter build apk --flavor cliente|conductor`.
    flavorDimensions += "app"
    productFlavors {
        create("cliente") {
            dimension = "app"
            applicationId = "co.cargaexpress.app"
            manifestPlaceholders["appName"] = "CargaExpress"
        }
        create("conductor") {
            dimension = "app"
            applicationId = "co.cargaexpress.conductor"
            manifestPlaceholders["appName"] = "CargaExpress Conductor"
        }
    }

    signingConfigs {
        if (keyProps.isNotEmpty()) {
            create("release") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // Sin subir el mapping de R8 al compilar (no hay credenciales en
            // este equipo); los reportes llegan igual, sin desofuscar.
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                mappingFileUploadEnabled = false
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}