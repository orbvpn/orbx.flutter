import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load local properties
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

// Get Flutter version info
val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.orbvpn.orbx"
    compileSdk = 36
    ndkVersion = "27.0.12077973"  // ✅ UPDATED to match plugin requirements

    compileOptions {
        // ✅ RE-ENABLED core library desugaring (required by flutter_local_notifications)
        isCoreLibraryDesugaringEnabled = true
        
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.orbvpn.orbx"
        minSdk = 26  // Keep at 26 to minimize desugaring issues
        targetSdk = 36
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for release builds
            // For now, using debug signing
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Core library desugaring (REQUIRED by flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // WireGuard for Android (Kotlin DSL syntax)
    implementation("com.wireguard.android:tunnel:1.0.20230427")
    
    // OkHttp for network requests
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    
    // Kotlin coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}