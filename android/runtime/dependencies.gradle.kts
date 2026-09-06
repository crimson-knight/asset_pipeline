// Shared by the reference host and every CLI-generated Android application.
dependencies {
    // The shared permission adapter uses lifecycle-owned ActivityResultRegistry.
    add("implementation", "androidx.activity:activity-ktx:1.10.0")
    // 5.5.0 requires compileSdk 37. Pin the 5.3 patch line with this SDK 35 host;
    // upgrade alongside the Android toolchain, never suppress AAR metadata checks.
    add("implementation", "com.squareup.okhttp3:okhttp:5.3.2")
    add("testImplementation", "com.squareup.okhttp3:mockwebserver3:5.3.2")
    add("testImplementation", "com.squareup.okhttp3:okhttp-tls:5.3.2")
}
