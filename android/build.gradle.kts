// Gradle no logra descargar de Maven en esta computadora ("Network is unreachable").
// image_picker pide el plugin de Kotlin 2.3.20, que no está descargado; se fuerza la misma
// versión que ya usa el proyecto (2.2.20, ya en caché). Cuando haya red se puede quitar este bloque.
subprojects {
    buildscript {
        configurations.configureEach {
            resolutionStrategy.eachDependency {
                if (requested.group == "org.jetbrains.kotlin" && requested.name.startsWith("kotlin-gradle-plugin")) {
                    useVersion("2.2.20")
                    because("Usar la versión de Kotlin ya descargada")
                }
            }
        }
    }
}

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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
