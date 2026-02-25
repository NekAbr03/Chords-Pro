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
// Удалено evaluationDependsOn для стабильности IDE


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    configurations.all {
        resolutionStrategy {
            eachDependency {
                if (requested.group == "org.jetbrains.kotlin") {
                    useVersion("2.2.10")
                }
            }
        }
    }
    // Инъекция compileSdk для старых плагинов, которые не обновлены под AGP 9.0
    val androidPluginIds = listOf("com.android.application", "com.android.library")
    androidPluginIds.forEach { pluginId ->
        plugins.withId(pluginId) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            if (android.compileSdkVersion == null) {
                android.compileSdkVersion(35)
            }
        }
    }
}
