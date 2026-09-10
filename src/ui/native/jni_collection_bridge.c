#include <jni.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "android_text_bridge.h"

static JavaVM *ap_java_vm = NULL;
static _Atomic int32_t ap_live_global_refs = 0;

void jni_track_global_ref_created(void) {
    atomic_fetch_add_explicit(&ap_live_global_refs, 1, memory_order_relaxed);
}

void jni_track_global_ref_deleted(void) {
    atomic_fetch_sub_explicit(&ap_live_global_refs, 1, memory_order_relaxed);
}

void jni_set_java_vm(void *vm_ptr) {
    ap_java_vm = (JavaVM *)vm_ptr;
}

int32_t jni_delete_global_ref_current_thread(void *global_ref) {
    if (!ap_java_vm || !global_ref) {
        return 0;
    }

    JNIEnv *env = NULL;
    int attached_here = 0;
    jint status = (*ap_java_vm)->GetEnv(
        ap_java_vm, (void **)&env, JNI_VERSION_1_6);

    if (status == JNI_EDETACHED) {
        if ((*ap_java_vm)->AttachCurrentThread(ap_java_vm, &env, NULL) != JNI_OK) {
            return 0;
        }
        attached_here = 1;
    } else if (status != JNI_OK || !env) {
        return 0;
    }

    (*env)->DeleteGlobalRef(env, (jobject)global_ref);
    jni_track_global_ref_deleted();

    if (attached_here) {
        (*ap_java_vm)->DetachCurrentThread(ap_java_vm);
    }
    return 1;
}

void *jni_string_create(void *env_ptr, uint8_t *utf8_str) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    return ap_new_string(env, utf8_str, -1);
}

void *jni_string_create_with_bytes(void *env_ptr, uint8_t *bytes, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    return ap_new_string(env, bytes, byte_len);
}

uint8_t *jni_string_to_utf8(void *env_ptr, void *jstr, int32_t *out_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    return ap_string_copy_utf8(env, (jstring)jstr, out_len);
}

void jni_string_release_utf8(void *env_ptr, void *jstr, uint8_t *utf8) {
    (void)env_ptr;
    (void)jstr;
    free(utf8);
}

int32_t jni_string_length(void *env_ptr, void *jstr) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    return (int32_t)ap_jni_GetStringLength(env, (jstring)jstr);
}

void *jni_object_array_create(void *env_ptr, uint8_t *element_class, void **objects, int32_t count) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (!ap_jni_ready(env, count >= 0 && (!count || objects), "Invalid native object array")) return NULL;
    jclass cls = ap_jni_FindClass(env, (const char *)element_class);
    jobjectArray array = ap_jni_NewObjectArray(env, count, cls, NULL);
    for (int32_t index = 0; index < count && !(*env)->ExceptionCheck(env); index++) {
        ap_jni_SetObjectArrayElement(env, array, index, (jobject)objects[index]);
    }
    (*env)->DeleteLocalRef(env, cls);
    return array;
}

int32_t jni_object_array_length(void *env_ptr, void *jarr) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    return (int32_t)ap_jni_GetArrayLength(env, (jarray)jarr);
}

void *jni_object_array_get(void *env_ptr, void *jarr, int32_t index) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    return ap_jni_GetObjectArrayElement(env, (jobjectArray)jarr, index);
}

void *jni_arraylist_create(void *env_ptr, void **objects, int32_t count) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (!ap_jni_ready(env, count >= 0 && (!count || objects), "Invalid native list")) return NULL;
    jclass cls = ap_jni_FindClass(env, "java/util/ArrayList");
    jmethodID ctor = ap_jni_GetMethodID(env, cls, "<init>", "(I)V");
    jmethodID add = ap_jni_GetMethodID(env, cls, "add", "(Ljava/lang/Object;)Z");
    jobject list = ap_jni_NewObject(env, cls, ctor, count > 0 ? count : 4);
    for (int32_t index = 0; index < count && !(*env)->ExceptionCheck(env); index++) {
        ap_jni_CallBooleanMethod(env, list, add, (jobject)objects[index]);
    }
    (*env)->DeleteLocalRef(env, cls);
    return list;
}

int32_t jni_arraylist_size(void *env_ptr, void *list) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)list);
    jmethodID method = ap_jni_GetMethodID(env, cls, "size", "()I");
    jint result = ap_jni_CallIntMethod(env, (jobject)list, method);
    (*env)->DeleteLocalRef(env, cls);
    return (int32_t)result;
}

void *jni_arraylist_get(void *env_ptr, void *list, int32_t index) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)list);
    jmethodID method = ap_jni_GetMethodID(env, cls, "get", "(I)Ljava/lang/Object;");
    jobject result = ap_jni_CallObjectMethod(env, (jobject)list, method, index);
    (*env)->DeleteLocalRef(env, cls);
    return result;
}

void jni_arraylist_add(void *env_ptr, void *list, void *object) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)list);
    jmethodID method = ap_jni_GetMethodID(env, cls, "add", "(Ljava/lang/Object;)Z");
    ap_jni_CallBooleanMethod(env, (jobject)list, method, (jobject)object);
    (*env)->DeleteLocalRef(env, cls);
}

void *jni_arraylist_remove_at(void *env_ptr, void *list, int32_t index) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)list);
    jmethodID method = ap_jni_GetMethodID(env, cls, "remove", "(I)Ljava/lang/Object;");
    jobject result = ap_jni_CallObjectMethod(env, (jobject)list, method, index);
    (*env)->DeleteLocalRef(env, cls);
    return result;
}

void jni_arraylist_clear(void *env_ptr, void *list) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)list);
    jmethodID method = ap_jni_GetMethodID(env, cls, "clear", "()V");
    ap_jni_CallVoidMethod(env, (jobject)list, method);
    (*env)->DeleteLocalRef(env, cls);
}

void jni_viewgroup_add_views_batch(void *env_ptr, void *view_group, void **children, int32_t count) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (!ap_jni_ready(env, count >= 0 && (!count || children), "Invalid native view batch")) return;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)view_group);
    jmethodID add_view = ap_jni_GetMethodID(env, cls, "addView", "(Landroid/view/View;)V");
    for (int32_t index = 0; index < count && !(*env)->ExceptionCheck(env); index++) {
        ap_jni_CallVoidMethod(env, (jobject)view_group, add_view, (jobject)children[index]);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void jni_viewgroup_remove_all(void *env_ptr, void *view_group) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)view_group);
    jmethodID method = ap_jni_GetMethodID(env, cls, "removeAllViews", "()V");
    ap_jni_CallVoidMethod(env, (jobject)view_group, method);
    (*env)->DeleteLocalRef(env, cls);
}

void *jni_new_global_ref(void *env_ptr, void *local_ref) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject global_ref = ap_jni_NewGlobalRef(env, (jobject)local_ref);
    if (global_ref) {
        jni_track_global_ref_created();
    }
    return global_ref;
}

void jni_delete_global_ref(void *env_ptr, void *global_ref) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (global_ref) {
        (*env)->DeleteGlobalRef(env, (jobject)global_ref);
        jni_track_global_ref_deleted();
    }
}

int32_t jni_live_global_ref_count(void) {
    return atomic_load_explicit(&ap_live_global_refs, memory_order_relaxed);
}

void jni_delete_local_ref(void *env_ptr, void *local_ref) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (local_ref) {
        (*env)->DeleteLocalRef(env, (jobject)local_ref);
    }
}

int32_t jni_push_local_frame(void *env_ptr, int32_t capacity) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    return (int32_t)ap_jni_PushLocalFrame(env, capacity);
}

void *jni_pop_local_frame(void *env_ptr, void *result) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    return (*env)->PopLocalFrame(env, (jobject)result);
}

void *jni_hashmap_create_string_string_with_lengths(void *env_ptr, uint8_t **keys, int32_t *key_lengths,
                                                   uint8_t **values, int32_t *value_lengths, int32_t count) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (count < 0 || (count && (!keys || !values)) || ap_jni_PushLocalFrame(env, 8) != JNI_OK) return NULL;
    jclass cls = ap_jni_FindClass(env, "java/util/HashMap");
    if (!cls || (*env)->ExceptionCheck(env)) goto failed;
    jmethodID ctor = ap_jni_GetMethodID(env, cls, "<init>", "()V");
    if (!ctor || (*env)->ExceptionCheck(env)) goto failed;
    jmethodID put = ap_jni_GetMethodID(env, cls, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
    if (!put || (*env)->ExceptionCheck(env)) goto failed;
    jobject map = ap_jni_NewObject(env, cls, ctor);
    if (!map || (*env)->ExceptionCheck(env)) goto failed;

    for (int32_t index = 0; index < count; index++) {
        jstring key = ap_new_string(env, keys[index], key_lengths ? key_lengths[index] : -1);
        if (!key || (*env)->ExceptionCheck(env)) goto failed;
        jstring value = ap_new_string(env, values[index], value_lengths ? value_lengths[index] : -1);
        if (!value || (*env)->ExceptionCheck(env)) goto failed;
        jobject previous = ap_jni_CallObjectMethod(env, map, put, key, value);
        if ((*env)->ExceptionCheck(env)) goto failed;
        if (previous) (*env)->DeleteLocalRef(env, previous);
        (*env)->DeleteLocalRef(env, key);
        (*env)->DeleteLocalRef(env, value);
    }
    return (*env)->PopLocalFrame(env, map);
failed:
    (*env)->PopLocalFrame(env, NULL);
    return NULL;
}

void *jni_hashmap_create_string_string(void *env_ptr, uint8_t **keys, uint8_t **values, int32_t count) {
    return jni_hashmap_create_string_string_with_lengths(env_ptr, keys, NULL, values, NULL, count);
}
