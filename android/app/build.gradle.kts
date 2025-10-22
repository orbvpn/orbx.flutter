plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.orbvpn.orbx"
    compileSdk = 35  // Use 35 instead of 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17  // Changed from 1.8
        targetCompatibility = JavaVersion.VERSION_17  // Changed from 1.8
    }

    kotlinOptions {
        jvmTarget = "17"  // Changed from 1.8
    }

    defaultConfig {
        applicationId = "com.orbvpn.orbx"
        minSdk = 24  // Set explicit minimum
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.wireguard.android:tunnel:1.0.20230427")
}