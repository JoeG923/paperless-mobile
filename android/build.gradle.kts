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
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion("2.1.0")
            }
            if (requested.group == "net.bytebuddy") {
                // Keep Byte Buddy on a Jetifier-compatible class file target so
                // Android lint model generation for test classpaths does not fail.
                useVersion("1.14.18")
            }
        }
    }
}

subprojects {
    fun configureMinSdk() {
        @Suppress("DEPRECATION")
        val androidExt = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        androidExt?.defaultConfig?.minSdkVersion(24)
    }

    plugins.withId("com.android.application") {
        if (state.executed) {
            configureMinSdk()
        } else {
            afterEvaluate { configureMinSdk() }
        }
    }
    plugins.withId("com.android.library") {
        if (state.executed) {
            configureMinSdk()
        } else {
            afterEvaluate { configureMinSdk() }
        }
    }
}

subprojects {
    if (name != "app") {
        // Don't run instrumentation tests for plugin subprojects, but keep
        // AndroidTest build + lint model tasks enabled (AGP lint depends on them).
        tasks.matching {
            val n = it.name.lowercase()
            (n.startsWith("connected") || n.startsWith("device") || n.contains("manageddevice")) &&
                n.contains("androidtest")
        }.configureEach { enabled = false }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
