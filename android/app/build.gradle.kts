plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningEnv = mapOf(
    "KEY_ALIAS" to System.getenv("KEY_ALIAS"),
    "KEY_PASSWORD" to System.getenv("KEY_PASSWORD"),
    "STORE_PASSWORD" to System.getenv("STORE_PASSWORD"),
)
val missingReleaseSigningEnv = releaseSigningEnv.filterValues { it.isNullOrBlank() }.keys

android {
    namespace = "com.shopaflow.shopaflow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.shopaflow.pos"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 9
        versionName = "1.0.8"
        
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = releaseSigningEnv["KEY_ALIAS"] ?: ""
            keyPassword = releaseSigningEnv["KEY_PASSWORD"] ?: ""
            storeFile = file("upload-keystore.jks")
            storePassword = releaseSigningEnv["STORE_PASSWORD"] ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

gradle.taskGraph.whenReady {
    val requestedReleaseBuild = allTasks.any { task ->
        task.name.contains("Release", ignoreCase = true)
    }
    if (requestedReleaseBuild && missingReleaseSigningEnv.isNotEmpty()) {
        throw GradleException(
            "Missing release signing environment variables: ${missingReleaseSigningEnv.joinToString(", ")}. " +
                "Set KEY_ALIAS, KEY_PASSWORD, and STORE_PASSWORD before building a release."
        )
    }
}
