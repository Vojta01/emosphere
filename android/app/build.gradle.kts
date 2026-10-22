plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing — CI passes the keystore and its passwords through
// environment variables (see .github/workflows/android-build.yml). Local
// builds without the variables fall back to the debug key so that
// `flutter build apk` keeps working out of the box.
val releaseSigningEnv: Map<String, String> = listOf(
    "KEYSTORE_PATH", "KEYSTORE_PASSWORD", "KEY_ALIAS", "KEY_PASSWORD",
).associateWith { System.getenv(it) ?: "" }
val hasReleaseSigning = releaseSigningEnv.values.all { it.isNotBlank() }

android {
    namespace = "com.emosphere"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.emosphere"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseSigningEnv.getValue("KEYSTORE_PATH"))
                storePassword = releaseSigningEnv.getValue("KEYSTORE_PASSWORD")
                keyAlias = releaseSigningEnv.getValue("KEY_ALIAS")
                keyPassword = releaseSigningEnv.getValue("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Release-signed when the CI secrets are present; debug key only
            // for local builds without secrets (updates across such builds
            // are not installable over each other).
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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
