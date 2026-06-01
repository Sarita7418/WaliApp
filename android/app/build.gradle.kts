import java.util.Properties

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")

if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}

plugins {
    id("com.android.application")
    id("kotlin-android")

    // Flutter plugin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aventuraspacenas.wali_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.aventuraspacenas.wali_app"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName


        manifestPlaceholders["MAPBOX_ACCESS_TOKEN"] =
            localProperties.getProperty("MAPBOX_ACCESS_TOKEN")
    }

    buildTypes {
        release {
            // Usa '=' y comillas dobles
            isMinifyEnabled = true
            isShrinkResources = false // Temporalmente en false para evitar errores de recursos
            
            // La sintaxis de proguardFiles cambia en Kotlin DSL
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
