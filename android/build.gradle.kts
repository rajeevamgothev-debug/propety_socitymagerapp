import org.gradle.api.tasks.compile.JavaCompile

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
gradle.projectsEvaluated {
    subprojects {
        tasks.withType<JavaCompile>().configureEach {
            val variantName =
                name
                    .removePrefix("compile")
                    .removeSuffix("JavaWithJavac")

            if (variantName != name) {
                tasks.findByName("javaPreCompile$variantName")?.let {
                    dependsOn(it)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
