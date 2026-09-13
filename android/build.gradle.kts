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

// vosk_flutter (0.3.48) はまだ古い Android Gradle Plugin 向けのビルドスクリプトのままで、
// namespace を宣言していない(AndroidManifest.xml の package 属性のみ)。
// 新しい AGP はこれを許容しないため、ここで補ってやる必要がある。
subprojects {
    if (project.name == "vosk_flutter") {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
                ?.takeIf { it.namespace == null }
                ?.namespace = "org.vosk.vosk_flutter"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
