#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include "../../src/ui/native/android_jni_guard.h"

static jthrowable pending;
static int calls;
static int fail_lookup;
static jobject object = (jobject)(uintptr_t)16;
static jclass expected_type = (jclass)(uintptr_t)32;
static jthrowable original = (jthrowable)(uintptr_t)48;
static jmethodID method = (jmethodID)(uintptr_t)64;
static jboolean check(JNIEnv *env) { (void)env; return pending != NULL; }
static jthrowable occurred(JNIEnv *env) { (void)env; return pending; }
static void clear(JNIEnv *env) { (void)env; pending = NULL; }
static jint throw_existing(JNIEnv *env, jthrowable error) { (void)env; pending = error; return 0; }
static void delete_local(JNIEnv *env, jobject value) { (void)env; (void)value; }
static jclass find(JNIEnv *env, const char *name) {
    (void)env; (void)name; assert(!pending); calls++;
    if (fail_lookup) { pending = (jthrowable)(uintptr_t)96; return NULL; }
    return expected_type;
}
static jint throw_new(JNIEnv *env, jclass type, const char *message) {
    (void)env; assert(!pending && type == expected_type && message); calls++;
    pending = (jthrowable)(uintptr_t)112; return 0;
}
static jboolean instance(JNIEnv *env, jobject value, jclass type) {
    (void)env; assert(!pending); return value == original && type == expected_type;
}
static jint throwing_int(JNIEnv *env, jobject value, jmethodID id, va_list args) {
    (void)env; (void)args; assert(!pending && value == object && id == method);
    calls++; pending = original; return 99; // Invalid result must not escape.
}

int main(void) {
    const struct JNINativeInterface table = {
        .ExceptionCheck = check, .ExceptionOccurred = occurred,
        .ExceptionClear = clear, .Throw = throw_existing, .ThrowNew = throw_new, .DeleteLocalRef = delete_local,
        .FindClass = find, .IsInstanceOf = instance, .CallIntMethodV = throwing_int,
    };
    JNIEnv env = &table;
    assert(ap_jni_CallIntMethod(&env, object, method) == 0);
    assert(pending == original && calls == 1);

    // No non-cleanup entry may touch the deliberately absent raw function
    // pointer while an exception is pending, even with invalid arguments.
    assert(!ap_jni_FindClass(&env, NULL));
    assert(!ap_jni_GetObjectClass(&env, NULL));
    assert(!ap_jni_GetMethodID(&env, NULL, NULL, NULL));
    assert(!ap_jni_GetStaticMethodID(&env, NULL, NULL, NULL));
    assert(!ap_jni_GetFieldID(&env, NULL, NULL, NULL));
    assert(!ap_jni_GetStaticFieldID(&env, NULL, NULL, NULL));
    assert(!ap_jni_GetStaticIntField(&env, NULL, NULL));
    assert(!ap_jni_GetStaticObjectField(&env, NULL, NULL));
    assert(!ap_jni_GetFloatField(&env, NULL, NULL));
    assert(!ap_jni_IsInstanceOf(&env, NULL, NULL));
    assert(!ap_jni_NewGlobalRef(&env, NULL));
    assert(!ap_jni_NewByteArray(&env, -1));
    assert(!ap_jni_NewStringUTF(&env, NULL));
    assert(!ap_jni_NewString(&env, NULL, -1));
    assert(!ap_jni_GetStringLength(&env, NULL));
    assert(!ap_jni_GetStringChars(&env, NULL, NULL));
    assert(!ap_jni_NewObjectArray(&env, -1, NULL, NULL));
    assert(!ap_jni_GetArrayLength(&env, NULL));
    assert(!ap_jni_GetObjectArrayElement(&env, NULL, -1));
    assert(ap_jni_PushLocalFrame(&env, 8) == JNI_ERR);
    assert(!ap_jni_NewObject(&env, NULL, NULL));
    assert(!ap_jni_CallObjectMethod(&env, NULL, NULL));
    assert(!ap_jni_CallIntMethod(&env, NULL, NULL));
    assert(!ap_jni_CallBooleanMethod(&env, NULL, NULL));
    assert(!ap_jni_CallStaticObjectMethod(&env, NULL, NULL));
    assert(!ap_jni_CallStaticIntMethod(&env, NULL, NULL));
    assert(!ap_jni_CallStaticBooleanMethod(&env, NULL, NULL));
    ap_jni_CallVoidMethod(&env, NULL, NULL);
    ap_jni_CallStaticVoidMethod(&env, NULL, NULL);
    ap_jni_SetByteArrayRegion(&env, NULL, -1, -1, NULL);
    ap_jni_SetObjectArrayElement(&env, NULL, -1, NULL);
    assert(pending == original && calls == 1);

    assert(ap_jni_clear_expected(&env, "expected"));
    assert(!pending && calls == 2);
    jthrowable other = (jthrowable)(uintptr_t)80;
    pending = other;
    assert(!ap_jni_clear_expected(&env, "expected"));
    assert(pending == other && calls == 3);
    fail_lookup = 1;
    assert(!ap_jni_clear_expected(&env, "lookup-failed"));
    assert(pending == other && calls == 4);
    fail_lookup = 0;
    pending = NULL;
    assert(!ap_jni_GetObjectClass(&env, NULL));
    assert(pending == (jthrowable)(uintptr_t)112 && calls == 6);
    puts("PASS: 31 JNI guard entrypoints, invalid throwing result rejected, pending Throwable preserved and typed fallback enforced");
    return 0;
}
