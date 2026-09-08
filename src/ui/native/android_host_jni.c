#include <jni.h>
#include <android/log.h>
#include <stdint.h>
#include <stdlib.h>
#include "android_text_bridge.h"

static JavaVM *ap_host_vm = NULL;

#define AP_ANDROID_LOG_TAG "AssetPipelineNative"
#define AP_ANDROID_LOGI(...) __android_log_print(ANDROID_LOG_INFO, AP_ANDROID_LOG_TAG, __VA_ARGS__)
#define AP_ANDROID_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, AP_ANDROID_LOG_TAG, __VA_ARGS__)

void android_host_log_crystal_error(const unsigned char *message) {
    __android_log_print(
        ANDROID_LOG_ERROR,
        AP_ANDROID_LOG_TAG,
        "Crystal application error: %s",
        message ? (const char *)message : "unknown error"
    );
}

extern void crystal_init(void);
extern int crystal_runtime_initialization_count(void);
extern int crystal_runtime_is_ready(void);
extern int crystal_android_runtime_probe(void);
extern void crystal_gc_allow_thread_registration(void);
extern int crystal_gc_register_thread(void);
extern int crystal_gc_unregister_thread(void);
extern void *crystal_android_host_render_slug_bytes(void *env, void *context, const uint8_t *slug, int32_t byte_len);
extern void crystal_android_host_teardown(void);
extern int crystal_android_host_callback_count(void);
extern int crystal_android_host_lifecycle(int event);
extern int crystal_android_host_tick_interval(void);
extern int crystal_android_host_tick(void);
extern int crystal_android_host_viewport(double width, double height, double top, double bottom, double left, double right, double density);
extern int crystal_android_host_sheet_transition(int dismissed);
extern int crystal_android_host_navigation_back(int commit);
extern int crystal_android_service_complete(uint64_t id, int status, unsigned char *data, int size);
extern int crystal_android_service_pending_count(void);
extern void jni_set_java_vm(void *vm);
extern int jni_live_global_ref_count(void);
extern int crystal_android_host_callback_void(unsigned long long tag);
extern int crystal_android_host_callback_string(unsigned long long tag, unsigned char *value, int32_t byte_len);
extern int crystal_android_host_callback_bool(unsigned long long tag, int value);
extern int crystal_android_host_callback_float(unsigned long long tag, double value);
extern int crystal_android_host_callback_int(unsigned long long tag, int value);

static int ap_enter_crystal(void) {
    int registration = crystal_gc_register_thread();
    if (registration < 0) {
        AP_ANDROID_LOGE("Cannot enter Crystal (100 = runtime not initialized): %d", -registration);
    }
    return registration;
}

static void ap_leave_crystal(int registration) {
    if (registration > 0) {
        int status = crystal_gc_unregister_thread();
        if (status < 0) {
            AP_ANDROID_LOGE("Boehm thread unregistration failed with status %d", -status);
        }
    }
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    (void)reserved;
    jni_set_java_vm(vm);
    ap_host_vm = vm;
    AP_ANDROID_LOGI("JNI_OnLoad: starting Crystal runtime");
    crystal_init();
    if (!crystal_runtime_is_ready()) {
        AP_ANDROID_LOGE("JNI_OnLoad: Crystal runtime initialization failed");
        return JNI_ERR;
    }
    int runtime_probe = crystal_android_runtime_probe();
    if (runtime_probe != 42) {
        AP_ANDROID_LOGE("JNI_OnLoad: embedded runtime probe returned %d", runtime_probe);
        return JNI_ERR;
    }
    crystal_gc_allow_thread_registration();
    AP_ANDROID_LOGI("JNI_OnLoad: Crystal runtime ready (probe=%d)", runtime_probe);
    return JNI_VERSION_1_6;
}

/* Byte arrays carry real UTF-8 (including NUL/supplementary characters), never
 * JNI modified UTF-8. Only an already-attached host thread may submit work. */
static JNIEnv *ap_host_env(void) {
    JNIEnv *env = NULL;
    if (!ap_host_vm || (*ap_host_vm)->GetEnv(ap_host_vm, (void **)&env, JNI_VERSION_1_6) != JNI_OK) return NULL;
    return env;
}

static int ap_submit_key_value(const char *method_name, int key_limit, int value_limit, uint64_t id, int operation,
                               const unsigned char *key, int key_size, const unsigned char *value, int value_size) {
    JNIEnv *env = ap_host_env();
    if (!env || key_size < 0 || key_size > key_limit || value_size < 0 || value_size > value_limit) return 0;
    if ((*env)->PushLocalFrame(env, 4) != JNI_OK) return 0;
    int accepted = 0;
    jclass cls = (*env)->FindClass(env, "dev/assetpipeline/androidhost/CrystalServices");
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = (*env)->GetStaticMethodID(env, cls, method_name, "(JI[B[B)Z");
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    jbyteArray key_bytes = (*env)->NewByteArray(env, key_size);
    if (!key_bytes || (*env)->ExceptionCheck(env)) goto done;
    jbyteArray value_bytes = (*env)->NewByteArray(env, value_size);
    if (!value_bytes || (*env)->ExceptionCheck(env)) goto done;
    if (key_size) (*env)->SetByteArrayRegion(env, key_bytes, 0, key_size, (const jbyte *)key);
    if ((*env)->ExceptionCheck(env)) goto done;
    if (value_size) (*env)->SetByteArrayRegion(env, value_bytes, 0, value_size, (const jbyte *)value);
    if ((*env)->ExceptionCheck(env)) goto done;
    accepted = (*env)->CallStaticBooleanMethod(env, cls, method, (jlong)id, (jint)operation, key_bytes, value_bytes) == JNI_TRUE;
done:
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
        AP_ANDROID_LOGE("Android key-value submission bridge failed");
        accepted = 0;
    }
    (*env)->PopLocalFrame(env, NULL);
    return accepted;
}

int android_host_storage_submit(uint64_t id, int operation, const unsigned char *key, int key_size,
                                const unsigned char *value, int value_size) {
    return ap_submit_key_value("submitStorage", 512, 1048576, id, operation, key, key_size, value, value_size);
}

int android_host_secrets_submit(uint64_t id, int operation, const unsigned char *key, int key_size,
                                const unsigned char *value, int value_size) {
    return ap_submit_key_value("submitSecrets", 512, 65536, id, operation, key, key_size, value, value_size);
}

int android_host_files_submit(uint64_t id, int operation, const unsigned char *path, int path_size,
                              const unsigned char *data, int data_size) {
    return ap_submit_key_value("submitFiles", 1024, 1048576, id, operation, path, path_size, data, data_size);
}

static int ap_submit_packet(const char *method_name, int limit, uint64_t id, const unsigned char *packet, int size) {
    JNIEnv *env = ap_host_env();
    if (!env || size < 0 || size > limit || (*env)->PushLocalFrame(env, 3) != JNI_OK) return 0;
    int accepted = 0;
    jclass cls = (*env)->FindClass(env, "dev/assetpipeline/androidhost/CrystalServices");
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = (*env)->GetStaticMethodID(env, cls, method_name, "(J[B)Z");
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    jbyteArray data = (*env)->NewByteArray(env, size);
    if (!data || (*env)->ExceptionCheck(env)) goto done;
    if (size) (*env)->SetByteArrayRegion(env, data, 0, size, (const jbyte *)packet);
    if ((*env)->ExceptionCheck(env)) goto done;
    accepted = (*env)->CallStaticBooleanMethod(env, cls, method, (jlong)id, data) == JNI_TRUE;
done:
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
        AP_ANDROID_LOGE("Android packet submission bridge failed");
        accepted = 0;
    }
    (*env)->PopLocalFrame(env, NULL);
    return accepted;
}

int android_host_http_submit(uint64_t id, const unsigned char *packet, int size) {
    return ap_submit_packet("submitHttp", 1048576, id, packet, size);
}

int android_host_notifications_submit(uint64_t id, const unsigned char *packet, int size) {
    return ap_submit_packet("submitNotifications", 2194, id, packet, size);
}

int android_host_service_cancel(uint64_t id) {
    JNIEnv *env = ap_host_env();
    if (!env || (*env)->PushLocalFrame(env, 2) != JNI_OK) return 0;
    int success = 0;
    jclass cls = (*env)->FindClass(env, "dev/assetpipeline/androidhost/CrystalServices");
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = (*env)->GetStaticMethodID(env, cls, "cancel", "(J)V");
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    (*env)->CallStaticVoidMethod(env, cls, method, (jlong)id);
    success = !(*env)->ExceptionCheck(env);
done:
    if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
    (*env)->PopLocalFrame(env, NULL);
    return success;
}

int android_host_request_render(void) {
    JNIEnv *env = ap_host_env();
    if (!env || (*env)->PushLocalFrame(env, 2) != JNI_OK) return 0;
    int success = 0;
    jclass cls = (*env)->FindClass(env, "dev/assetpipeline/androidhost/CrystalBridge");
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = (*env)->GetStaticMethodID(env, cls, "requestRender", "()V");
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    (*env)->CallStaticVoidMethod(env, cls, method);
    success = !(*env)->ExceptionCheck(env);
done:
    if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
    (*env)->PopLocalFrame(env, NULL);
    return success;
}

/* The extracted bundle's path into buffer: its length, 0 for no bundle, -1 on failure or a small buffer. */
int android_host_bundled_assets_dir(unsigned char *buffer, int capacity) {
    JNIEnv *env = ap_host_env();
    if (!env || !buffer || capacity <= 0 || (*env)->PushLocalFrame(env, 3) != JNI_OK) return -1;
    int length = -1;
    jclass cls = (*env)->FindClass(env, "dev/assetpipeline/androidhost/BundledAssets");
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = (*env)->GetStaticMethodID(env, cls, "directoryBytes", "()[B");
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    jbyteArray bytes = (jbyteArray)(*env)->CallStaticObjectMethod(env, cls, method);
    if ((*env)->ExceptionCheck(env)) goto done;
    if (!bytes) { length = 0; goto done; }
    jsize size = (*env)->GetArrayLength(env, bytes);
    if (size > capacity) goto done;
    (*env)->GetByteArrayRegion(env, bytes, 0, size, (jbyte *)buffer);
    if ((*env)->ExceptionCheck(env)) goto done;
    length = (int)size;
done:
    if ((*env)->ExceptionCheck(env)) { (*env)->ExceptionClear(env); length = -1; }
    (*env)->PopLocalFrame(env, NULL);
    return length;
}

/* A private directory (1 files, 2 cache) into buffer: its length, 0 when unknown, -1 on failure or a small buffer. */
int android_host_app_directory(int kind, unsigned char *buffer, int capacity) {
    JNIEnv *env = ap_host_env();
    if (!env || !buffer || capacity <= 0 || (*env)->PushLocalFrame(env, 3) != JNI_OK) return -1;
    int length = -1;
    jclass cls = (*env)->FindClass(env, "dev/assetpipeline/androidhost/AppDirectories");
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = (*env)->GetStaticMethodID(env, cls, "pathBytes", "(I)[B");
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    jbyteArray bytes = (jbyteArray)(*env)->CallStaticObjectMethod(env, cls, method, (jint)kind);
    if ((*env)->ExceptionCheck(env)) goto done;
    if (!bytes) { length = 0; goto done; }
    jsize size = (*env)->GetArrayLength(env, bytes);
    if (size > capacity) goto done;
    (*env)->GetByteArrayRegion(env, bytes, 0, size, (jbyte *)buffer);
    if ((*env)->ExceptionCheck(env)) goto done;
    length = (int)size;
done:
    if ((*env)->ExceptionCheck(env)) { (*env)->ExceptionClear(env); length = -1; }
    (*env)->PopLocalFrame(env, NULL);
    return length;
}

/* Photo picker pulls: PhotoPicker's static methods, on the main looper. */
static jclass ap_photo_class(JNIEnv *env) { return (*env)->FindClass(env, "dev/assetpipeline/androidhost/PhotoPicker"); }

static int ap_photo_call_int(const char *name, const char *signature, int a, int b, int c, int argc) {
    JNIEnv *env = ap_host_env();
    if (!env || (*env)->PushLocalFrame(env, 2) != JNI_OK) return -1;
    int result = -1;
    jclass cls = ap_photo_class(env);
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = (*env)->GetStaticMethodID(env, cls, name, signature);
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    if (argc == 0) result = (int)(*env)->CallStaticIntMethod(env, cls, method);
    else if (argc == 1) result = (int)(*env)->CallStaticIntMethod(env, cls, method, (jint)a);
    else result = (int)(*env)->CallStaticIntMethod(env, cls, method, (jint)a, (jint)b, (jint)c);
    if ((*env)->ExceptionCheck(env)) result = -1;
done:
    if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
    (*env)->PopLocalFrame(env, NULL);
    return result;
}

static int ap_photo_call_bool(const char *name, const char *signature, int a, int b, int c, int argc) {
    JNIEnv *env = ap_host_env();
    if (!env || (*env)->PushLocalFrame(env, 2) != JNI_OK) return 0;
    int result = 0;
    jclass cls = ap_photo_class(env);
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = (*env)->GetStaticMethodID(env, cls, name, signature);
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    jboolean value = argc == 1 ? (*env)->CallStaticBooleanMethod(env, cls, method, (jint)a)
                               : (*env)->CallStaticBooleanMethod(env, cls, method, (jint)a, (jint)b, (jint)c);
    result = (!(*env)->ExceptionCheck(env) && value == JNI_TRUE) ? 1 : 0;
done:
    if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
    (*env)->PopLocalFrame(env, NULL);
    return result;
}

/* A byte array from a static method into buffer: its length, 0 for null, -1 on failure or a small buffer. */
static int ap_photo_call_bytes(const char *name, unsigned char *buffer, int capacity) {
    JNIEnv *env = ap_host_env();
    if (!env || !buffer || capacity <= 0 || (*env)->PushLocalFrame(env, 3) != JNI_OK) return -1;
    int length = -1;
    jclass cls = ap_photo_class(env);
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = (*env)->GetStaticMethodID(env, cls, name, "()[B");
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    jbyteArray bytes = (jbyteArray)(*env)->CallStaticObjectMethod(env, cls, method);
    if ((*env)->ExceptionCheck(env)) goto done;
    if (!bytes) { length = 0; goto done; }
    jsize size = (*env)->GetArrayLength(env, bytes);
    if (size > capacity) goto done;
    (*env)->GetByteArrayRegion(env, bytes, 0, size, (jbyte *)buffer);
    if ((*env)->ExceptionCheck(env)) goto done;
    length = (int)size;
done:
    if ((*env)->ExceptionCheck(env)) { (*env)->ExceptionClear(env); length = -1; }
    (*env)->PopLocalFrame(env, NULL);
    return length;
}

int android_host_photo_available(int source) { return ap_photo_call_bool("available", "(I)Z", source, 0, 0, 1); }
int android_host_photo_begin(int source, int max_dimension, int quality) { return ap_photo_call_bool("begin", "(III)Z", source, max_dimension, quality, 3); }
int android_host_photo_state(void) { return ap_photo_call_int("state", "()I", 0, 0, 0, 0); }
int android_host_photo_dimension(int which) { return ap_photo_call_int(which == 0 ? "width" : "height", "()I", 0, 0, 0, 0); }
void android_host_photo_reset(void) {
    JNIEnv *env = ap_host_env();
    if (!env || (*env)->PushLocalFrame(env, 2) != JNI_OK) return;
    jclass cls = ap_photo_class(env);
    if (cls && !(*env)->ExceptionCheck(env)) {
        jmethodID method = (*env)->GetStaticMethodID(env, cls, "reset", "()V");
        if (method && !(*env)->ExceptionCheck(env)) (*env)->CallStaticVoidMethod(env, cls, method);
    }
    if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
    (*env)->PopLocalFrame(env, NULL);
}
/* The encoded photo's size while ready: its length, 0 when none, -1 on failure. */
int android_host_photo_byte_count(void) {
    JNIEnv *env = ap_host_env();
    if (!env || (*env)->PushLocalFrame(env, 3) != JNI_OK) return -1;
    int length = -1;
    jclass cls = ap_photo_class(env);
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = (*env)->GetStaticMethodID(env, cls, "bytes", "()[B");
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    jbyteArray bytes = (jbyteArray)(*env)->CallStaticObjectMethod(env, cls, method);
    if ((*env)->ExceptionCheck(env)) goto done;
    length = bytes ? (int)(*env)->GetArrayLength(env, bytes) : 0;
done:
    if ((*env)->ExceptionCheck(env)) { (*env)->ExceptionClear(env); length = -1; }
    (*env)->PopLocalFrame(env, NULL);
    return length;
}
int android_host_photo_copy_bytes(unsigned char *buffer, int capacity) { return ap_photo_call_bytes("bytes", buffer, capacity); }
int android_host_photo_error(unsigned char *buffer, int capacity) { return ap_photo_call_bytes("errorBytes", buffer, capacity); }

/* Registers a font file under a family name through FontAssets; 1 on success. */
int android_host_font_register(const unsigned char *family, int family_size, const unsigned char *path, int path_size) {
    JNIEnv *env = ap_host_env();
    if (!env || !family || family_size <= 0 || !path || path_size <= 0 || (*env)->PushLocalFrame(env, 4) != JNI_OK) return 0;
    int success = 0;
    jclass cls = (*env)->FindClass(env, "dev/assetpipeline/androidhost/FontAssets");
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = (*env)->GetStaticMethodID(env, cls, "register", "([B[B)Z");
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    jbyteArray family_bytes = (*env)->NewByteArray(env, family_size);
    if (!family_bytes || (*env)->ExceptionCheck(env)) goto done;
    (*env)->SetByteArrayRegion(env, family_bytes, 0, family_size, (const jbyte *)family);
    jbyteArray path_bytes = (*env)->NewByteArray(env, path_size);
    if (!path_bytes || (*env)->ExceptionCheck(env)) goto done;
    (*env)->SetByteArrayRegion(env, path_bytes, 0, path_size, (const jbyte *)path);
    if ((*env)->ExceptionCheck(env)) goto done;
    success = (*env)->CallStaticBooleanMethod(env, cls, method, family_bytes, path_bytes) == JNI_TRUE;
done:
    if ((*env)->ExceptionCheck(env)) { (*env)->ExceptionClear(env); success = 0; }
    (*env)->PopLocalFrame(env, NULL);
    return success;
}

JNIEXPORT jboolean JNICALL
Java_dev_assetpipeline_androidhost_CrystalServices_completeNative(JNIEnv *env, jclass clazz,
                                                                  jlong id, jint status, jbyteArray data) {
    (void)clazz;
    if (!data) return JNI_FALSE;
    jsize size = (*env)->GetArrayLength(env, data);
    if (size < 0 || size > 1048576) return JNI_FALSE;
    unsigned char *bytes = size ? malloc((size_t)size) : NULL;
    if (size && !bytes) return JNI_FALSE;
    if (size) (*env)->GetByteArrayRegion(env, data, 0, size, (jbyte *)bytes);
    if ((*env)->ExceptionCheck(env)) { free(bytes); return JNI_FALSE; }
    int registration = ap_enter_crystal();
    if (registration < 0) { free(bytes); return JNI_FALSE; }
    int success = crystal_android_service_complete((uint64_t)id, (int)status, bytes, (int)size);
    ap_leave_crystal(registration);
    free(bytes);
    return success ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jint JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_servicePendingCountNative(JNIEnv *env, jclass clazz) {
    (void)env; (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) return -1;
    int count = crystal_android_service_pending_count();
    ap_leave_crystal(registration);
    return count;
}

JNIEXPORT jint JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_debugInitializeAgainNative(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    crystal_init();
    return crystal_runtime_initialization_count();
}

JNIEXPORT void JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_teardownNative(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) {
        return;
    }
    crystal_android_host_teardown();
    ap_leave_crystal(registration);
}

JNIEXPORT jboolean JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_lifecycleNative(JNIEnv *env, jclass clazz, jint event) {
    (void)env;
    (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) return JNI_FALSE;
    int success = crystal_android_host_lifecycle((int)event);
    ap_leave_crystal(registration);
    return success ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jint JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_tickIntervalNative(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) return 0;
    int interval = crystal_android_host_tick_interval();
    ap_leave_crystal(registration);
    return interval < 0 ? 0 : (jint)interval;
}

JNIEXPORT jboolean JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_tickNative(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) return JNI_FALSE;
    int success = crystal_android_host_tick();
    ap_leave_crystal(registration);
    return success ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jint JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_viewportNative(JNIEnv *env, jclass clazz, jdouble width, jdouble height,
                                                                jdouble top, jdouble bottom, jdouble left, jdouble right, jdouble density) {
    (void)env;
    (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) return -1;
    int result = crystal_android_host_viewport((double)width, (double)height, (double)top, (double)bottom,
                                               (double)left, (double)right, (double)density);
    ap_leave_crystal(registration);
    return (jint)result;
}

JNIEXPORT jint JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_completeSheetTransitionNative(JNIEnv *env, jclass clazz, jboolean dismissed) {
    (void)env;
    (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) return -1;
    int result = crystal_android_host_sheet_transition(dismissed ? 1 : 0);
    ap_leave_crystal(registration);
    return result;
}

JNIEXPORT jint JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_debugLiveGlobalRefCountNative(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    return (jint)jni_live_global_ref_count();
}

JNIEXPORT jint JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_debugCallbackCountNative(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) {
        return -1;
    }
    int count = crystal_android_host_callback_count();
    ap_leave_crystal(registration);
    return (jint)count;
}

JNIEXPORT jobject JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_renderStudyNative(JNIEnv *env, jobject thiz, jobject context, jstring slug) {
    (void)thiz;

    AP_ANDROID_LOGI("renderStudy: entered JNI bridge");

    if (!context || !slug) {
        return NULL;
    }

    int32_t byte_len = 0;
    uint8_t *slug_utf8 = ap_string_copy_utf8(env, slug, &byte_len);
    if (!slug_utf8) {
        return NULL;
    }
    int registration = ap_enter_crystal();
    if (registration < 0) {
        free(slug_utf8);
        return NULL;
    }
    void *global_ref = crystal_android_host_render_slug_bytes(env, context, slug_utf8, byte_len);
    ap_leave_crystal(registration);
    free(slug_utf8);

    if (!global_ref) {
        return NULL;
    }

    jobject local_ref = (*env)->NewLocalRef(env, (jobject)global_ref);
    AP_ANDROID_LOGI("renderStudy: returning rendered root");
    return local_ref;
}

JNIEXPORT jint JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_navigationBackNative(JNIEnv *env, jclass clazz, jboolean commit) {
    (void)env;
    (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) return -1;
    int result = crystal_android_host_navigation_back(commit == JNI_TRUE ? 1 : 0);
    ap_leave_crystal(registration);
    return result;
}

JNIEXPORT jboolean JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_dispatchVoidCallbackNative(JNIEnv *env, jclass clazz, jlong callback_id) {
    (void)env;
    (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) {
        return JNI_FALSE;
    }
    int success = crystal_android_host_callback_void((unsigned long long)callback_id);
    ap_leave_crystal(registration);
    return success ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_dispatchStringCallbackNative(JNIEnv *env, jclass clazz, jlong callback_id, jstring value) {
    (void)clazz;

    int registration = ap_enter_crystal();
    if (registration < 0) {
        return JNI_FALSE;
    }
    if (!value) {
        int success = crystal_android_host_callback_string((unsigned long long)callback_id, (unsigned char *)"", 0);
        ap_leave_crystal(registration);
        return success ? JNI_TRUE : JNI_FALSE;
    }

    int32_t byte_len = 0;
    uint8_t *utf8 = ap_string_copy_utf8(env, value, &byte_len);
    int success = 0;
    if (utf8) {
        success = crystal_android_host_callback_string((unsigned long long)callback_id, utf8, byte_len);
        free(utf8);
    }
    ap_leave_crystal(registration);
    return success ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_dispatchBoolCallbackNative(JNIEnv *env, jclass clazz, jlong callback_id, jboolean value) {
    (void)env;
    (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) {
        return JNI_FALSE;
    }
    int success = crystal_android_host_callback_bool((unsigned long long)callback_id, value ? 1 : 0);
    ap_leave_crystal(registration);
    return success ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_dispatchFloatCallbackNative(JNIEnv *env, jclass clazz, jlong callback_id, jdouble value) {
    (void)env;
    (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) {
        return JNI_FALSE;
    }
    int success = crystal_android_host_callback_float((unsigned long long)callback_id, (double)value);
    ap_leave_crystal(registration);
    return success ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_dispatchIntCallbackNative(JNIEnv *env, jclass clazz, jlong callback_id, jint value) {
    (void)env;
    (void)clazz;
    int registration = ap_enter_crystal();
    if (registration < 0) {
        return JNI_FALSE;
    }
    int success = crystal_android_host_callback_int((unsigned long long)callback_id, (int)value);
    ap_leave_crystal(registration);
    return success ? JNI_TRUE : JNI_FALSE;
}
