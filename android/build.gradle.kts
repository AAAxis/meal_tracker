buildscript {
    repositories {
        google()  // Firebase requires this
        mavenCentral()
    }

    dependencies {
        // Use double quotes for Kotlin DSL
        classpath("com.google.gms:google-services:4.3.15") // Firebase Services plugin
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // Add JitPack repository for additional dependencies
        maven { url = uri("https://jitpack.io") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
