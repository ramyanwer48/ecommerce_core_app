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
    // الحل الجذري المعماري:
    // جلب الحرف الخاص بهارد المشروع (مثلاً D) وحرف هارد المكتبة (مثلاً C)
    val rootDrive = rootProject.rootDir.absolutePath.substringBefore(":")
    val projectDrive = project.projectDir.absolutePath.substringBefore(":")

    // لا ندمج مسارات البناء إلا إذا كانا على نفس الهارد، لتجنب خطأ Different roots
    if (rootDrive.equals(projectDrive, ignoreCase = true)) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}