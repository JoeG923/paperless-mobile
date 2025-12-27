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
        tasks.matching { it.name.contains("AndroidTest", ignoreCase = true) }.configureEach {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
