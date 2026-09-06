#ifndef AP_ANDROID_TEXT_BRIDGE_H
#define AP_ANDROID_TEXT_BRIDGE_H
#include "android_jni_guard.h"
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include "unicode_text_codec.h"

static inline jstring ap_new_string(JNIEnv *env, const uint8_t *bytes, jint byte_len) {
    if (!bytes || (*env)->ExceptionCheck(env)) return NULL;
    size_t length = byte_len < 0 ? strlen((const char *)bytes) : (size_t)byte_len;
    if (length > INT32_MAX || length > SIZE_MAX / sizeof(jchar)) {
        ap_jni_throw(env, "java/lang/IllegalArgumentException", "Native text exceeds JNI size limit");
        return NULL;
    }
    jchar *units = (jchar *)malloc((length ? length : 1) * sizeof(jchar));
    if (!units) { ap_jni_throw(env, "java/lang/OutOfMemoryError", "Native UTF-16 allocation failed"); return NULL; }
    size_t count = ap_utf8_to_utf16(bytes, length, units);
    jstring result = ap_jni_NewString(env, units, (jsize)count);
    free(units);
    return result;
}

/* The returned buffer belongs to malloc/free, not GetStringUTFChars/Release.
 * out_len is authoritative; the extra terminator is only for legacy callers. */
static inline uint8_t *ap_string_copy_utf8(JNIEnv *env, jstring value, int32_t *out_len) {
    if (out_len) *out_len = 0;
    if (!value || (*env)->ExceptionCheck(env)) return NULL;
    jsize length = ap_jni_GetStringLength(env, value);
    if ((*env)->ExceptionCheck(env)) return NULL;
    if (length < 0 || length > (INT32_MAX - 1) / 3) {
        ap_jni_throw(env, "java/lang/IllegalArgumentException", "Java text exceeds native UTF-8 size limit");
        return NULL;
    }
    const jchar *units = ap_jni_GetStringChars(env, value, NULL);
    if (!units) return NULL;
    uint8_t *bytes = (uint8_t *)malloc((size_t)length * 3 + 1);
    if (bytes) {
        size_t count = ap_utf16_to_utf8(units, (size_t)length, bytes);
        bytes[count] = 0;
        if (out_len) *out_len = (int32_t)count;
    }
    (*env)->ReleaseStringChars(env, value, units);
    if (!bytes) ap_jni_throw(env, "java/lang/OutOfMemoryError", "Native UTF-8 allocation failed");
    return bytes;
}
#endif
