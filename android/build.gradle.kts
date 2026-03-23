plugins {
    id("com.android.application") apply false
    id("org.jetbrains.kotlin.android") apply false
    id("dev.flutter.flutter-gradle-plugin") apply false
}
 

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Plugin de Google Services para Firebase
        classpath("com.google.gms:google-services:4.4.2")
    }
}


allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // Opcional: silenciar advertencias sobre opciones obsoletas de javac
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
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


