allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// The Android SDK installed on this host has only platform android-36 (the
// flutter.compileSdkVersion). Plugins that pin an older compileSdk (jni and
// jni_flutter pin 35) would otherwise fail with "Failed to find target with
// hash string 'android-35'". Lift every Android subproject to the installed
// platform after its own build script evaluated. Reflection keeps this script
// independent of the AGP types on the script classpath.
subprojects {
    val liftCompileSdkToInstalledPlatform: () -> Unit = {
        val androidExtension = extensions.findByName("android")
        if (androidExtension != null) {
            val setter = androidExtension.javaClass.methods.firstOrNull {
                it.name == "setCompileSdk" &&
                    it.parameterTypes.size == 1 &&
                    it.parameterTypes[0] == java.lang.Integer::class.java
            }
            setter?.invoke(androidExtension, 36)
        }
    }
    if (state.executed) {
        // Projects evaluated early (e.g. :app via evaluationDependsOn) cannot
        // register afterEvaluate callbacks any more; adjust them right away.
        liftCompileSdkToInstalledPlatform()
    } else {
        afterEvaluate { liftCompileSdkToInstalledPlatform() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
