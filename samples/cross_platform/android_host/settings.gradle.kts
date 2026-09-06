pluginManagement {
    val toolchain = java.util.Properties().apply {
        file("../../../config/android_toolchain.env").inputStream().use { load(it) }
    }
    plugins {
        id("com.android.application") version toolchain.getProperty("ANDROID_AGP_VERSION")
        id("org.jetbrains.kotlin.android") version toolchain.getProperty("ANDROID_KOTLIN_VERSION")
    }
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

val toolchain = java.util.Properties().apply {
    file("../../../config/android_toolchain.env").inputStream().use { load(it) }
}
check(gradle.gradleVersion == toolchain.getProperty("ANDROID_GRADLE_VERSION")) {
    "Gradle wrapper must match config/android_toolchain.env"
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "android_host"
include(":app")
