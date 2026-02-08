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

// Suppress deprecation/unchecked warnings from third-party plugin subprojects only.
// The :app project is excluded so that warnings in our own code remain visible.
// Uses doFirst to override AGP's late-applied -Xlint flags at execution time.
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            tasks.withType<JavaCompile>().configureEach {
                doFirst {
                    options.compilerArgs = options.compilerArgs
                        .filter { !it.startsWith("-Xlint") }
                        .toMutableList()
                        .apply { add("-Xlint:none") }
                }
            }
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    suppressWarnings.set(true)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
