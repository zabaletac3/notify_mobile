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

// Fuerza compileSdk 36 en los subproyectos (plugins) que aún declaran uno antiguo.
// Lo necesitan plugins transitivos de appflowy_editor (p. ej. keyboard_height_plugin)
// con el Flutter estable actual (ver docs/decisions.md, fase 0). No cambia el
// compileSdk propio de la app (D17). Debe registrarse antes del evaluationDependsOn.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val cls = androidExt.javaClass
        val intTypes = listOf<Class<*>>(Int::class.java, Int::class.javaObjectType)
        for (setter in listOf("setCompileSdk", "setCompileSdkVersion")) {
            for (type in intTypes) {
                val ok = runCatching {
                    cls.getMethod(setter, type).invoke(androidExt, 36)
                }.isSuccess
                if (ok) return@afterEvaluate
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
