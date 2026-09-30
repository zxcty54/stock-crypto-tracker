plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.stockpulse.app"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.stockpulse.app"
        minSdk = 24
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = file("keystore/upload-keystore.jks")
            storePassword = "stockpulse@123"
            keyAlias = "stockpulse-key"
            keyPassword = "stockpulse@123"
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            // Debug mode me bhi release key point karega taaki updates me signature mismatch na aaye
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
