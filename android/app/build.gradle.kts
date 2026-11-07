import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material is injected by CI as a decoded keystore plus a
// key.properties file. Locally (no key.properties) we fall back to debug
// signing so `flutter run --release` keeps working.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) {
        f.inputStream().use { load(it) }
    }
}

android {
    namespace = "app.derafsh.drf"
    // libbox AAR dependencies (androidx.core 1.17+) require compileSdk 36
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "app.derafsh.drf"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Optional ABI filter (used by CI for the small arm64-only APK).
        // Set drf.abi=arm64-v8a in gradle.properties (per-invocation, daemon-safe)
        // or DRF_ABI in the environment. Filters ALL native libs.
        val drfAbiList = (project.findProperty("drf.abi") as String?
            ?: System.getenv("DRF_ABI"))
            ?.split(',')
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
        if (!drfAbiList.isNullOrEmpty()) {
            ndk { abiFilters += drfAbiList }
        }
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("drfRelease") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties.isNotEmpty()) {
                signingConfigs.getByName("drfRelease")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // sing-box libbox (built in CI with gomobile from SagerNet/sing-box v1.14.4)
    implementation(files("libs/libbox.aar"))
}
