#ifndef AP_ANDROID_JNI_GUARD_H
#define AP_ANDROID_JNI_GUARD_H
#include <jni.h>
#include <stdarg.h>

/* Do not replace JNIEnv or install a proxy function table. These explicit
 * wrappers keep the VM's original Throwable pending and make subsequent
 * non-cleanup calls no-ops until the Crystal boundary unwinds its own frames.
 * Delete/Release/Pop operations remain direct, as required for error cleanup. */
static inline void ap_jni_throw(JNIEnv *env, const char *type, const char *message) {
    if ((*env)->ExceptionCheck(env)) return;
    jclass cls = (*env)->FindClass(env, type);
    if (!cls) return;
    (*env)->ThrowNew(env, cls, message);
    (*env)->DeleteLocalRef(env, cls);
}

static inline int ap_jni_ready(JNIEnv *env, int valid, const char *operation) {
    if ((*env)->ExceptionCheck(env)) return 0;
    if (!valid) {
        ap_jni_throw(env, "java/lang/IllegalArgumentException", operation);
        return 0;
    }
    return 1;
}

/* Optional lookups may ignore only the documented missing member/class, never
 * a pre-existing exception or a constructor/method/allocation failure. Callers
 * must test for an existing exception BEFORE attempting the optional lookup. */
static inline int ap_jni_clear_expected(JNIEnv *env, const char *type) {
    jthrowable original = (*env)->ExceptionOccurred(env);
    if (!original) return 0;
    (*env)->ExceptionClear(env);
    jclass cls = (*env)->FindClass(env, type);
    int expected = cls && !(*env)->ExceptionCheck(env) && (*env)->IsInstanceOf(env, original, cls);
    if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
    if (!expected) (*env)->Throw(env, original);
    if (cls) (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, original);
    return expected;
}

#define AP_JNI_RESULT(name, type, parameters, valid, arguments, fallback) \
    static inline type ap_jni_##name parameters { \
        if (!ap_jni_ready(env, (valid), "Invalid JNI arguments: " #name)) return (fallback); \
        type result = (*env)->name arguments; \
        return (*env)->ExceptionCheck(env) ? (fallback) : result; \
    }

AP_JNI_RESULT(FindClass, jclass, (JNIEnv *env, const char *name), name != NULL, (env, name), NULL)
AP_JNI_RESULT(GetObjectClass, jclass, (JNIEnv *env, jobject object), object != NULL, (env, object), NULL)
AP_JNI_RESULT(GetMethodID, jmethodID, (JNIEnv *env, jclass cls, const char *name, const char *sig), cls && name && sig, (env, cls, name, sig), NULL)
AP_JNI_RESULT(GetStaticMethodID, jmethodID, (JNIEnv *env, jclass cls, const char *name, const char *sig), cls && name && sig, (env, cls, name, sig), NULL)
AP_JNI_RESULT(GetFieldID, jfieldID, (JNIEnv *env, jclass cls, const char *name, const char *sig), cls && name && sig, (env, cls, name, sig), NULL)
AP_JNI_RESULT(GetStaticFieldID, jfieldID, (JNIEnv *env, jclass cls, const char *name, const char *sig), cls && name && sig, (env, cls, name, sig), NULL)
AP_JNI_RESULT(GetStaticIntField, jint, (JNIEnv *env, jclass cls, jfieldID field), cls && field, (env, cls, field), 0)
AP_JNI_RESULT(GetStaticObjectField, jobject, (JNIEnv *env, jclass cls, jfieldID field), cls && field, (env, cls, field), NULL)
AP_JNI_RESULT(GetFloatField, jfloat, (JNIEnv *env, jobject object, jfieldID field), object && field, (env, object, field), 0)
AP_JNI_RESULT(IsInstanceOf, jboolean, (JNIEnv *env, jobject object, jclass cls), cls != NULL, (env, object, cls), JNI_FALSE)
AP_JNI_RESULT(NewGlobalRef, jobject, (JNIEnv *env, jobject object), object != NULL, (env, object), NULL)
AP_JNI_RESULT(NewByteArray, jbyteArray, (JNIEnv *env, jsize length), length >= 0, (env, length), NULL)
AP_JNI_RESULT(NewStringUTF, jstring, (JNIEnv *env, const char *value), value != NULL, (env, value), NULL)
AP_JNI_RESULT(NewString, jstring, (JNIEnv *env, const jchar *value, jsize length), length >= 0 && (value || !length), (env, value, length), NULL)
AP_JNI_RESULT(GetStringLength, jsize, (JNIEnv *env, jstring value), value != NULL, (env, value), 0)
AP_JNI_RESULT(GetStringChars, const jchar *, (JNIEnv *env, jstring value, jboolean *copy), value != NULL, (env, value, copy), NULL)
AP_JNI_RESULT(NewObjectArray, jobjectArray, (JNIEnv *env, jsize length, jclass cls, jobject initial), length >= 0 && cls, (env, length, cls, initial), NULL)
AP_JNI_RESULT(GetArrayLength, jsize, (JNIEnv *env, jarray array), array != NULL, (env, array), 0)
AP_JNI_RESULT(GetObjectArrayElement, jobject, (JNIEnv *env, jobjectArray array, jsize index), array != NULL, (env, array, index), NULL)
AP_JNI_RESULT(PushLocalFrame, jint, (JNIEnv *env, jint capacity), capacity >= 0, (env, capacity), JNI_ERR)
#undef AP_JNI_RESULT

#define AP_JNI_METHOD(name, type, receiver_type) \
    static inline type ap_jni_##name(JNIEnv *env, receiver_type receiver, jmethodID method, ...) { \
        if (!ap_jni_ready(env, receiver && method, "Invalid JNI arguments: " #name)) return (type)0; \
        va_list args; va_start(args, method); \
        type result = (*env)->name##V(env, receiver, method, args); \
        va_end(args); \
        return (*env)->ExceptionCheck(env) ? (type)0 : result; \
    }
AP_JNI_METHOD(NewObject, jobject, jclass)
AP_JNI_METHOD(CallObjectMethod, jobject, jobject)
AP_JNI_METHOD(CallIntMethod, jint, jobject)
AP_JNI_METHOD(CallBooleanMethod, jboolean, jobject)
AP_JNI_METHOD(CallStaticObjectMethod, jobject, jclass)
AP_JNI_METHOD(CallStaticIntMethod, jint, jclass)
AP_JNI_METHOD(CallStaticBooleanMethod, jboolean, jclass)
#undef AP_JNI_METHOD

#define AP_JNI_VOID_METHOD(name, receiver_type) \
    static inline void ap_jni_##name(JNIEnv *env, receiver_type receiver, jmethodID method, ...) { \
        if (!ap_jni_ready(env, receiver && method, "Invalid JNI arguments: " #name)) return; \
        va_list args; va_start(args, method); \
        (*env)->name##V(env, receiver, method, args); \
        va_end(args); \
    }
AP_JNI_VOID_METHOD(CallVoidMethod, jobject)
AP_JNI_VOID_METHOD(CallStaticVoidMethod, jclass)
#undef AP_JNI_VOID_METHOD

static inline void ap_jni_SetByteArrayRegion(JNIEnv *env, jbyteArray array, jsize start, jsize length, const jbyte *bytes) {
    if (ap_jni_ready(env, array && (bytes || !length), "Invalid JNI byte array"))
        (*env)->SetByteArrayRegion(env, array, start, length, bytes);
}
static inline void ap_jni_SetObjectArrayElement(JNIEnv *env, jobjectArray array, jsize index, jobject value) {
    if (ap_jni_ready(env, array != NULL, "Invalid JNI object array"))
        (*env)->SetObjectArrayElement(env, array, index, value);
}
#endif
