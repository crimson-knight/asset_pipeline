import java.util.Properties
import java.awt.image.BufferedImage
import javax.imageio.ImageIO

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val crystalBridgeBuildScript = rootProject.file("build_crystal_lib.sh")
val nativeAssetRoot = rootProject.projectDir
// Procedural test data, not application artwork. Real PNG/JPEG resources let
// instrumentation prove decoder/density bounds without checked-in binaries.
val generateImageFixtures by tasks.registering {
    val fixtureDirectory = rootProject.layout.buildDirectory.dir("image-fixtures")
    outputs.dir(fixtureDirectory)
    doLast {
        val directory = fixtureDirectory.get().asFile.apply { mkdirs() }
        for ((name, size) in mapOf("contrast" to (80 to 40), "too_many_pixels" to (1025 to 1025), "too_wide" to (4097 to 1), "density_limit" to (768 to 768))) {
            val bitmap = BufferedImage(size.first, size.second, BufferedImage.TYPE_INT_RGB)
            for (y in 0 until size.second) for (x in 0 until size.first) bitmap.setRGB(x, y, if (x < size.first / 2) 0xff0000 else 0x0000ff)
            check(ImageIO.write(bitmap, "png", directory.resolve("$name.png")))
            if (name == "contrast") check(ImageIO.write(bitmap, "jpeg", directory.resolve("contrast.jpg")))
        }
    }
}
val generatedImages = layout.buildDirectory.dir("generated/assetPipelineImages")
val compileImages by tasks.registering(Exec::class) {
    dependsOn(generateImageFixtures)
    group = "build"
    description = "Compile the explicit application image catalog into Android resources."
    commandLine("crystal", "run", rootProject.file("../../../scripts/compile_android_assets.cr").absolutePath,
        "--", nativeAssetRoot.absolutePath, "config/android_assets.yml", generatedImages.get().asFile.absolutePath)
    // Sources may be any explicitly declared project-relative files. Don't use
    // an incomplete directory glob as an incremental cache dependency list.
    outputs.dir(generatedImages)
    outputs.upToDateWhen { false }
}
val toolchain = Properties().apply {
    rootProject.file("../../../config/android_toolchain.env").inputStream().use { load(it) }
}

val buildCrystalBridge by tasks.registering(Exec::class) {
    group = "build"
    description = "Build the Crystal-backed Android renderer bridge for the host app."

    workingDir = rootProject.projectDir
    commandLine("bash", crystalBridgeBuildScript.absolutePath)
}

android {
    namespace = "dev.assetpipeline.androidhost"
    compileSdk = toolchain.getProperty("ANDROID_COMPILE_SDK").toInt()
    buildToolsVersion = toolchain.getProperty("ANDROID_BUILD_TOOLS_VERSION")
    ndkVersion = toolchain.getProperty("ANDROID_NDK_VERSION")

    defaultConfig {
        applicationId = "dev.assetpipeline.androidhost"
        minSdk = toolchain.getProperty("ANDROID_MIN_SDK").toInt()
        targetSdk = toolchain.getProperty("ANDROID_TARGET_SDK").toInt()
        versionCode = 1
        versionName = "0.1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables.useSupportLibrary = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            ndk.debugSymbolLevel = "FULL"
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.toVersion(toolchain.getProperty("ANDROID_JAVA_VERSION"))
        targetCompatibility = JavaVersion.toVersion(toolchain.getProperty("ANDROID_JAVA_VERSION"))
    }

    kotlinOptions {
        jvmTarget = toolchain.getProperty("ANDROID_JAVA_VERSION")
    }

    buildFeatures {
        viewBinding = true
    }

    sourceSets.getByName("main").java.srcDir(rootProject.file("../../../android/runtime/src/main/java"))
    sourceSets.getByName("main").res.srcDir(rootProject.file("../../../android/runtime/src/main/res"))
    sourceSets.getByName("main").res.srcDir(generatedImages.map { it.dir("res") })
    sourceSets.getByName("test").java.srcDir(rootProject.file("../../../android/runtime/src/test/java"))
    sourceSets.getByName("androidTest").java.srcDir(rootProject.file("../../../android/runtime/src/androidTest/java"))

    providers.gradleProperty("externalAndroidTestSource").orNull?.let { source ->
        sourceSets.getByName("androidTest").java.srcDir(source)
    }
    // Only the explicit local TLS proof may add its ephemeral CA to debug APKs.
    // The release source set never sees this manifest or certificate.
    providers.gradleProperty("networkTestResources").orNull?.let { source ->
        val fixture = file(source)
        require(fixture.resolve("AndroidManifest.xml").isFile)
        require(fixture.resolve("res/raw/ap_test_ca.pem").isFile)
        sourceSets.getByName("debug").manifest.srcFile(fixture.resolve("AndroidManifest.xml"))
        sourceSets.getByName("debug").res.srcDir(fixture.resolve("res"))
    }
    providers.gradleProperty("notificationTestResources").orNull?.let { source ->
        require(!providers.gradleProperty("networkTestResources").isPresent) { "Notification and TLS debug fixtures are separate proof lanes" }
        val fixture = file(source)
        require(fixture.resolve("AndroidManifest.xml").isFile)
        require(fixture.resolve("res/xml/ap_notification_channels.xml").isFile)
        sourceSets.getByName("debug").manifest.srcFile(fixture.resolve("AndroidManifest.xml"))
        sourceSets.getByName("debug").res.srcDir(fixture.resolve("res"))
    }
}

tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn(buildCrystalBridge, compileImages)
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.activity:activity-ktx:1.10.0")
    implementation("com.google.android.material:material:1.12.0")

    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:core:1.6.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
}
apply(from = rootProject.file("../../../android/runtime/dependencies.gradle.kts"))
