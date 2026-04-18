#include <jni.h>

extern void crystal_init(void);
extern void *crystal_android_host_render_slug(void *env, void *context, const char *slug);

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    (void)vm;
    (void)reserved;
    crystal_init();
    return JNI_VERSION_1_6;
}

JNIEXPORT jobject JNICALL
Java_dev_assetpipeline_androidhost_CrystalBridge_renderStudy(JNIEnv *env, jobject thiz, jobject context, jstring slug) {
    (void)thiz;

    if (!context || !slug) {
        return NULL;
    }

    const char *slug_utf8 = (*env)->GetStringUTFChars(env, slug, NULL);
    void *global_ref = crystal_android_host_render_slug(env, context, slug_utf8);
    (*env)->ReleaseStringUTFChars(env, slug, slug_utf8);

    if (!global_ref) {
        return NULL;
    }

    return (*env)->NewLocalRef(env, (jobject)global_ref);
}
