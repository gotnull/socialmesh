plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream
import com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension

// The FlutterFire plugins pin the Firebase Android SDK through the BoM version
// declared by firebase_core. Reading the same property keeps this module's
// Firebase artifacts on that BoM instead of carrying a second version pin.
val firebaseSdkVersion = project(":firebase_core").properties["FirebaseSDKVersion"] as String

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.gotnull.socialmesh"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    externalNativeBuild {
        cmake {
            version = "3.22.1"
            path = file("src/main/jni/CMakeLists.txt")
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.gotnull.socialmesh"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
        externalNativeBuild {
            cmake {
                cFlags("-O2 -fPIC -std=gnu11")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Native (raster thread, Impeller, JNI) crashes only reach
            // Crashlytics with the NDK integration, and only symbolicate when
            // the unstripped libraries are uploaded after the build.
            configure<CrashlyticsExtension> {
                nativeSymbolUploadEnabled = true
            }
        }
    }
}

// The Crashlytics plugin does not run the symbol upload on its own; chain it
// to every release build so `flutter build appbundle --release` ships symbols.
tasks.matching { it.name == "bundleRelease" || it.name == "assembleRelease" }.configureEach {
    finalizedBy("uploadCrashlyticsSymbolFileRelease")
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:$firebaseSdkVersion"))
    // Native crash capture (SIGSEGV / SIGABRT in libflutter, JNI). The Dart
    // plugin alone only reports Dart and Java exceptions.
    implementation("com.google.firebase:firebase-crashlytics-ndk")
    // Firebase Messaging for custom FCM service
    implementation("com.google.firebase:firebase-messaging:23.4.0")
    // Edge-to-edge support (Android 15 / SDK 35 requirement)
    implementation("androidx.activity:activity-ktx:1.10.1")
}
