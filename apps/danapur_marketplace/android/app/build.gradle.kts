plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
val signingPath = System.getenv("DANAPUR_KEYSTORE_PATH")
val hasUploadKey = !signingPath.isNullOrBlank()
android {
    namespace = "in.danapur.bazaar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = "in.danapur.bazaar"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(signingPath!!)
                storePassword = requireNotNull(System.getenv("DANAPUR_KEYSTORE_PASSWORD"))
                keyAlias = requireNotNull(System.getenv("DANAPUR_KEY_ALIAS"))
                keyPassword = requireNotNull(System.getenv("DANAPUR_KEY_PASSWORD"))
            }
        }
    }
    buildTypes {
        release {
            // Debug-signed release APKs are for installation/testing, NOT Play Store publication.
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "upload" else "debug")
        }
    }
}
flutter { source = "../.." }
