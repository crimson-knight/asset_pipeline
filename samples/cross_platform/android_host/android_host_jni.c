/* Compatibility build path. Runtime ownership belongs to AssetPipeline core,
 * not this showcase; generated applications compile the canonical source. */
#include "../../../src/ui/native/android_host_jni.c"

/* Only the showcase entrypoint exports this Crystal test fixture. External
 * Amber app fixtures still use the same host shim without requiring it. */
extern void *crystal_android_text_fixture_collections(void *env) __attribute__((weak));
JNIEXPORT jobject JNICALL
Java_dev_assetpipeline_androidhost_AndroidTextContractTest_collectionsNative(JNIEnv *env, jobject test) {
    (void)test;
    if (!crystal_android_text_fixture_collections) return NULL;
    int registration = ap_enter_crystal();
    if (registration < 0) return NULL;
    jobject result = (jobject)crystal_android_text_fixture_collections(env);
    ap_leave_crystal(registration);
    return result;
}

extern uint64_t crystal_android_failure_fixture_register(int kind) __attribute__((weak));
extern void crystal_android_failure_fixture_unregister(uint64_t id) __attribute__((weak));
extern int crystal_android_failure_fixture_render_probe(void *env, void *context) __attribute__((weak));
extern int crystal_android_java_failure_render_probe(void *env, void *context, int kind) __attribute__((weak));
extern int crystal_android_semantics_render_probe(void *env, void *context) __attribute__((weak));

JNIEXPORT jint JNICALL
Java_dev_assetpipeline_androidhost_AndroidSemanticsTest_renderProbeNative(JNIEnv *env, jobject test, jobject context) {
    (void)test;
    if (!crystal_android_semantics_render_probe) return -1;
    int registration = ap_enter_crystal();
    if (registration < 0) return -1;
    int result = crystal_android_semantics_render_probe(env, context);
    ap_leave_crystal(registration);
    return result;
}

JNIEXPORT jint JNICALL
Java_dev_assetpipeline_androidhost_AndroidJavaFailureBoundaryTest_renderProbeNative(JNIEnv *env, jobject test, jobject context, jint kind) {
    (void)test;
    if (!crystal_android_java_failure_render_probe) return -1;
    int registration = ap_enter_crystal();
    if (registration < 0) return -1;
    int result = crystal_android_java_failure_render_probe(env, context, kind);
    ap_leave_crystal(registration);
    /* Keep the original Java Throwable pending for the JVM to deliver. */
    return result;
}

JNIEXPORT jlong JNICALL
Java_dev_assetpipeline_androidhost_AndroidFailureBoundaryTest_registerFailureNative(JNIEnv *env, jobject test, jint kind) {
    (void)env; (void)test;
    if (!crystal_android_failure_fixture_register) return 0;
    int registration = ap_enter_crystal();
    if (registration < 0) return 0;
    uint64_t result = crystal_android_failure_fixture_register(kind);
    ap_leave_crystal(registration);
    return (jlong)result;
}

JNIEXPORT void JNICALL
Java_dev_assetpipeline_androidhost_AndroidFailureBoundaryTest_unregisterFailureNative(JNIEnv *env, jobject test, jlong id) {
    (void)env; (void)test;
    if (!crystal_android_failure_fixture_unregister) return;
    int registration = ap_enter_crystal();
    if (registration < 0) return;
    crystal_android_failure_fixture_unregister((uint64_t)id);
    ap_leave_crystal(registration);
}

JNIEXPORT jint JNICALL
Java_dev_assetpipeline_androidhost_AndroidFailureBoundaryTest_renderProbeNative(JNIEnv *env, jobject test, jobject context) {
    (void)test;
    if (!crystal_android_failure_fixture_render_probe) return -1;
    int registration = ap_enter_crystal();
    if (registration < 0) return -1;
    int result = crystal_android_failure_fixture_render_probe(env, context);
    ap_leave_crystal(registration);
    return result;
}
