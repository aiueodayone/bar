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
// また compileSdk が 33 に固定されており、permission_handler_android などが
// 引き込む androidx 系ライブラリ(compileSdk 34 以上を要求)と衝突するため、
// アプリ本体と同じ compileSdk に合わせて上書きする。
//
// flutter_native_splash も同種の問題を起こす: dev_dependencies に入れた
// つもりでも、ネイティブAndroidコードを持つ Flutter プラグインは Flutter の
// ビルドシステム上 dev/通常の区別なくアプリのビルドに組み込まれてしまう。
// このプラグイン自身は compileSdk 31 のままで、androidx 系ライブラリが
// 要求する compileSdk 34 以上と衝突するため、同じ理由で上書きする。
subprojects {
    if (project.name == "vosk_flutter") {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
                ?.let { android ->
                    if (android.namespace == null) {
                        android.namespace = "org.vosk.vosk_flutter"
                    }
                    android.compileSdk = 36
                }
        }
    }
    if (project.name == "flutter_native_splash") {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
                ?.let { android -> android.compileSdk = 36 }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
