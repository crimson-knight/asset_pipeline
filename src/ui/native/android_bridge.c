#include <jni.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "android_text_bridge.h"

static jmethodID ap_get_method(JNIEnv *env, jclass cls, const char *name, const char *sig) {
    return ap_jni_GetMethodID(env, cls, name, sig);
}

static jmethodID ap_try_get_method(JNIEnv *env, jclass cls, const char *name, const char *sig) {
    if ((*env)->ExceptionCheck(env)) return NULL;
    jmethodID method = ap_jni_GetMethodID(env, cls, name, sig);
    if (!method && (*env)->ExceptionCheck(env)) {
        ap_jni_clear_expected(env, "java/lang/NoSuchMethodError");
    }
    return method;
}

static jmethodID ap_get_static_method(JNIEnv *env, jclass cls, const char *name, const char *sig) {
    return ap_jni_GetStaticMethodID(env, cls, name, sig);
}

int32_t android_exception_pending(void *env_ptr) {
    return (*((JNIEnv *)env_ptr))->ExceptionCheck((JNIEnv *)env_ptr) ? 1 : 0;
}

/* All layout dimensions crossing this bridge are dp, except TextView text
 * size, which is sp and is converted by Android itself. Read the View's own
 * resources so configuration contexts and display changes stay correct. */
static float ap_view_density(JNIEnv *env, jobject view) {
    if (ap_jni_PushLocalFrame(env, 8) != JNI_OK) return 1.0f;
    float density = 1.0f;
    jclass view_cls = ap_jni_GetObjectClass(env, view);
    jmethodID get_resources = ap_get_method(env, view_cls, "getResources", "()Landroid/content/res/Resources;");
    if (!get_resources) goto done;
    jobject resources = ap_jni_CallObjectMethod(env, view, get_resources);
    if ((*env)->ExceptionCheck(env) || !resources) goto done;
    jclass resources_cls = ap_jni_GetObjectClass(env, resources);
    jmethodID get_metrics = ap_get_method(env, resources_cls, "getDisplayMetrics", "()Landroid/util/DisplayMetrics;");
    if (!get_metrics) goto done;
    jobject metrics = ap_jni_CallObjectMethod(env, resources, get_metrics);
    if ((*env)->ExceptionCheck(env) || !metrics) goto done;
    jclass metrics_cls = ap_jni_GetObjectClass(env, metrics);
    jfieldID field = ap_jni_GetFieldID(env, metrics_cls, "density", "F");
    if (field) density = ap_jni_GetFloatField(env, metrics, field);
done:
    (*env)->PopLocalFrame(env, NULL);
    return isfinite(density) && density > 0.0f ? density : 1.0f;
}

static float ap_dp(JNIEnv *env, jobject view, float value) {
    return value * ap_view_density(env, view);
}

static jint ap_layout_dimension(float density, jint value) {
    /* MATCH_PARENT and WRAP_CONTENT are semantic sentinels, not lengths. */
    return value == -1 || value == -2 ? value : (jint)lroundf(value * density);
}

void android_view_set_size_constraints(void *env_ptr, void *v,
                                       float min_width, float min_height,
                                       float fixed_width, float fixed_height) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (ap_jni_PushLocalFrame(env, 8) != JNI_OK) return;
    float density = ap_view_density(env, (jobject)v);
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    if (min_width >= 0) {
        jmethodID method = ap_get_method(env, cls, "setMinimumWidth", "(I)V");
        if (method) ap_jni_CallVoidMethod(env, (jobject)v, method, (jint)lroundf(min_width * density));
        if ((*env)->ExceptionCheck(env)) goto done;
    }
    if (min_height >= 0) {
        jmethodID method = ap_get_method(env, cls, "setMinimumHeight", "(I)V");
        if (method) ap_jni_CallVoidMethod(env, (jobject)v, method, (jint)lroundf(min_height * density));
        if ((*env)->ExceptionCheck(env)) goto done;
    }
    if (fixed_width >= 0 || fixed_height >= 0) {
        jclass params_cls = ap_jni_FindClass(env, "android/view/ViewGroup$LayoutParams");
        jmethodID ctor = ap_get_method(env, params_cls, "<init>", "(II)V");
        if (!ctor) goto done;
        jint width = fixed_width >= 0 ? (jint)lroundf(fixed_width * density) : -2;
        jint height = fixed_height >= 0 ? (jint)lroundf(fixed_height * density) : -2;
        jobject params = ap_jni_NewObject(env, params_cls, ctor, width, height);
        if ((*env)->ExceptionCheck(env) || !params) goto done;
        jmethodID set_params = ap_get_method(env, cls, "setLayoutParams", "(Landroid/view/ViewGroup$LayoutParams;)V");
        if (set_params) ap_jni_CallVoidMethod(env, (jobject)v, set_params, params);
    }
done:
    (*env)->PopLocalFrame(env, NULL);
}

void android_linearlayout_set_spacing(void *env_ptr, void *ll, float spacing) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeLayout");
    jmethodID method = ap_get_static_method(env, cls, "configureSpacing", "(Landroid/view/View;F)V");
    if (method) ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)ll, spacing);
    (*env)->DeleteLocalRef(env, cls);
}

static jobject ap_make_color_state_list(JNIEnv *env, jint argb) {
    jclass cls = ap_jni_FindClass(env, "android/content/res/ColorStateList");
    if (!cls) {
        return NULL;
    }

    jmethodID value_of = ap_get_static_method(env, cls, "valueOf", "(I)Landroid/content/res/ColorStateList;");
    jobject color_state_list = value_of ? ap_jni_CallStaticObjectMethod(env, cls, value_of, argb) : NULL;
    (*env)->DeleteLocalRef(env, cls);
    return color_state_list;
}

static jobject ap_new_callback_helper(JNIEnv *env, const char *class_name, uint64_t callback_id) {
    jclass cls = ap_jni_FindClass(env, class_name);
    if (!cls) {
        return NULL;
    }

    jmethodID ctor = ap_get_method(env, cls, "<init>", "(J)V");
    jobject helper = ctor ? ap_jni_NewObject(env, cls, ctor, (jlong)callback_id) : NULL;
    (*env)->DeleteLocalRef(env, cls);
    return helper;
}

static jobject ap_new_dual_callback_helper(JNIEnv *env, const char *class_name, uint64_t callback_id_a, uint64_t callback_id_b) {
    jclass cls = ap_jni_FindClass(env, class_name);
    if (!cls) {
        return NULL;
    }

    jmethodID ctor = ap_get_method(env, cls, "<init>", "(JJ)V");
    jobject helper = ctor ? ap_jni_NewObject(env, cls, ctor, (jlong)callback_id_a, (jlong)callback_id_b) : NULL;
    (*env)->DeleteLocalRef(env, cls);
    return helper;
}

int32_t android_context_resolve_material_color(void *env_ptr, void *context,
                                               uint8_t *attribute_name,
                                               int32_t fallback_argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if ((*env)->ExceptionCheck(env)) return fallback_argb;
    if (!context || !attribute_name || attribute_name[0] == '\0') {
        return fallback_argb;
    }

    jclass attr_cls = ap_jni_FindClass(env, "com/google/android/material/R$attr");
    if (!attr_cls) {
        return fallback_argb;
    }

    jfieldID attr_field = ap_jni_GetStaticFieldID(
        env, attr_cls, (const char *)attribute_name, "I");
    if (!attr_field) {
        ap_jni_clear_expected(env, "java/lang/NoSuchFieldError");
        (*env)->DeleteLocalRef(env, attr_cls);
        return fallback_argb;
    }
    jint attr_id = ap_jni_GetStaticIntField(env, attr_cls, attr_field);
    (*env)->DeleteLocalRef(env, attr_cls);

    jclass colors_cls = ap_jni_FindClass(
        env, "com/google/android/material/color/MaterialColors");
    if (!colors_cls) {
        return fallback_argb;
    }

    jmethodID get_color = ap_get_static_method(
        env,
        colors_cls,
        "getColor",
        "(Landroid/content/Context;II)I"
    );
    if (!get_color) {
        (*env)->DeleteLocalRef(env, colors_cls);
        return fallback_argb;
    }

    jint resolved = ap_jni_CallStaticIntMethod(
        env, colors_cls, get_color, (jobject)context, attr_id, fallback_argb);
    if ((*env)->ExceptionCheck(env)) {
        resolved = fallback_argb;
    }
    (*env)->DeleteLocalRef(env, colors_cls);
    return (int32_t)resolved;
}

static jobject ap_ensure_gradient_background(JNIEnv *env, jobject view) {
    jclass view_cls = ap_jni_GetObjectClass(env, view);
    jmethodID get_background = ap_get_method(env, view_cls, "getBackground", "()Landroid/graphics/drawable/Drawable;");
    jobject background = get_background ? ap_jni_CallObjectMethod(env, view, get_background) : NULL;

    jclass gradient_cls = ap_jni_FindClass(env, "android/graphics/drawable/GradientDrawable");
    if (background && gradient_cls && ap_jni_IsInstanceOf(env, background, gradient_cls)) {
        (*env)->DeleteLocalRef(env, view_cls);
        (*env)->DeleteLocalRef(env, gradient_cls);
        return background;
    }

    if (background) {
        (*env)->DeleteLocalRef(env, background);
    }

    jmethodID ctor = ap_get_method(env, gradient_cls, "<init>", "()V");
    jobject gradient = ctor ? ap_jni_NewObject(env, gradient_cls, ctor) : NULL;

    if (gradient) {
        jmethodID set_color = ap_try_get_method(env, gradient_cls, "setColor", "(I)V");
        jmethodID set_shape = ap_try_get_method(env, gradient_cls, "setShape", "(I)V");
        jmethodID set_background = ap_get_method(env, view_cls, "setBackground", "(Landroid/graphics/drawable/Drawable;)V");

        if (set_shape) {
            ap_jni_CallVoidMethod(env, gradient, set_shape, 0);
        }
        if (set_color) {
            ap_jni_CallVoidMethod(env, gradient, set_color, 0x00000000);
        }
        if (set_background) {
            ap_jni_CallVoidMethod(env, view, set_background, gradient);
        }
    }

    (*env)->DeleteLocalRef(env, view_cls);
    (*env)->DeleteLocalRef(env, gradient_cls);
    return gradient;
}

void *android_view_new(void *env_ptr, uint8_t *class_name, void *context) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_FindClass(env, (const char *)class_name);
    if (!cls) {
        return NULL;
    }

    jmethodID ctor = ap_get_method(env, cls, "<init>", "(Landroid/content/Context;)V");
    jobject view = ctor ? ap_jni_NewObject(env, cls, ctor, (jobject)context) : NULL;
    (*env)->DeleteLocalRef(env, cls);
    return view;
}

void *android_view_new_themed(void *env_ptr, uint8_t *class_name, void *context, uint8_t *style_field_name) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if ((*env)->ExceptionCheck(env)) return NULL;
    jobject themed_context = NULL;

    if (style_field_name && style_field_name[0] != '\0') {
        jclass style_cls = ap_jni_FindClass(env, "com/google/android/material/R$style");
        if (style_cls) {
            jfieldID style_field = ap_jni_GetStaticFieldID(env, style_cls, (const char *)style_field_name, "I");
            if (!style_field && (*env)->ExceptionCheck(env)) {
                ap_jni_clear_expected(env, "java/lang/NoSuchFieldError");
            }
            if (style_field) {
                jint style_res = ap_jni_GetStaticIntField(env, style_cls, style_field);
                if (style_res != 0) {
                    jclass wrapper_cls = ap_jni_FindClass(env, "android/view/ContextThemeWrapper");
                    if (wrapper_cls) {
                        jmethodID wrapper_ctor = ap_get_method(env, wrapper_cls, "<init>", "(Landroid/content/Context;I)V");
                        if (wrapper_ctor) {
                            themed_context = ap_jni_NewObject(env, wrapper_cls, wrapper_ctor, (jobject)context, style_res);
                        }
                        (*env)->DeleteLocalRef(env, wrapper_cls);
                    }
                }
            }
            (*env)->DeleteLocalRef(env, style_cls);
        }
    }

    jclass cls = ap_jni_FindClass(env, (const char *)class_name);
    if (!cls) {
        if (themed_context) {
            (*env)->DeleteLocalRef(env, themed_context);
        }
        return NULL;
    }

    jmethodID ctor = ap_get_method(env, cls, "<init>", "(Landroid/content/Context;)V");
    jobject ctor_context = themed_context ? themed_context : (jobject)context;
    jobject view = ctor ? ap_jni_NewObject(env, cls, ctor, ctor_context) : NULL;

    if (themed_context) {
        (*env)->DeleteLocalRef(env, themed_context);
    }
    (*env)->DeleteLocalRef(env, cls);
    return view;
}

void android_textview_set_text(void *env_ptr, void *tv, uint8_t *text, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)tv);
    jmethodID method = ap_get_method(env, cls, "setText", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, text, byte_len);
    if (method && value) {
        ap_jni_CallVoidMethod(env, (jobject)tv, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textview_set_text_size(void *env_ptr, void *tv, float size_sp) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)tv);
    jmethodID method = ap_get_method(env, cls, "setTextSize", "(F)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)tv, method, size_sp);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textview_set_text_color(void *env_ptr, void *tv, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)tv);
    jmethodID method = ap_get_method(env, cls, "setTextColor", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)tv, method, argb);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textview_set_gravity(void *env_ptr, void *tv, int32_t gravity) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)tv);
    jmethodID method = ap_get_method(env, cls, "setGravity", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)tv, method, gravity);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textview_set_max_lines(void *env_ptr, void *tv, int32_t max) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)tv);
    jmethodID method = ap_get_method(env, cls, "setMaxLines", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)tv, method, max);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textview_set_single_line(void *env_ptr, void *tv, int32_t single) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)tv);
    jmethodID method = ap_get_method(env, cls, "setSingleLine", "(Z)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)tv, method, single ? JNI_TRUE : JNI_FALSE);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textview_set_typeface(void *env_ptr, void *tv, int32_t style) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass text_cls = ap_jni_GetObjectClass(env, (jobject)tv);
    jclass typeface_cls = ap_jni_FindClass(env, "android/graphics/Typeface");
    jmethodID default_from_style = ap_get_static_method(env, typeface_cls, "defaultFromStyle", "(I)Landroid/graphics/Typeface;");
    jmethodID set_typeface = ap_get_method(env, text_cls, "setTypeface", "(Landroid/graphics/Typeface;)V");
    jobject typeface = default_from_style ? ap_jni_CallStaticObjectMethod(env, typeface_cls, default_from_style, style) : NULL;
    if (set_typeface && typeface) {
        ap_jni_CallVoidMethod(env, (jobject)tv, set_typeface, typeface);
    }
    if (typeface) {
        (*env)->DeleteLocalRef(env, typeface);
    }
    (*env)->DeleteLocalRef(env, typeface_cls);
    (*env)->DeleteLocalRef(env, text_cls);
}

void android_imageview_set_scale_type(void *env_ptr, void *iv, int32_t scale_type) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass image_cls = ap_jni_GetObjectClass(env, (jobject)iv);
    jclass scale_cls = ap_jni_FindClass(env, "android/widget/ImageView$ScaleType");
    const char *field_name = "FIT_CENTER";
    if (scale_type == 1) {
        field_name = "CENTER_CROP";
    } else if (scale_type == 2) {
        field_name = "FIT_XY";
    }
    jfieldID field = ap_jni_GetStaticFieldID(env, scale_cls, field_name, "Landroid/widget/ImageView$ScaleType;");
    jmethodID method = ap_get_method(env, image_cls, "setScaleType", "(Landroid/widget/ImageView$ScaleType;)V");
    jobject value = field ? ap_jni_GetStaticObjectField(env, scale_cls, field) : NULL;
    if (method && value) {
        ap_jni_CallVoidMethod(env, (jobject)iv, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, scale_cls);
    (*env)->DeleteLocalRef(env, image_cls);
}

void android_imageview_set_image_resource(void *env_ptr, void *iv, int32_t res_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)iv);
    jmethodID method = ap_get_method(env, cls, "setImageResource", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)iv, method, res_id);
    }
    (*env)->DeleteLocalRef(env, cls);
}

int32_t android_imageview_set_image_named(void *env_ptr, void *iv, uint8_t *name, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (!name || byte_len <= 0 || byte_len > 1024 || ap_jni_PushLocalFrame(env, 4) != JNI_OK) return 0;
    int32_t success = 0;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/ImageAssets");
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = ap_jni_GetStaticMethodID(env, cls, "setSource", "(Landroid/widget/ImageView;[B)Z");
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    jbyteArray bytes = ap_jni_NewByteArray(env, byte_len);
    if (!bytes || (*env)->ExceptionCheck(env)) goto done;
    ap_jni_SetByteArrayRegion(env, bytes, 0, byte_len, (const jbyte *)name);
    if ((*env)->ExceptionCheck(env)) goto done;
    success = ap_jni_CallStaticBooleanMethod(env, cls, method, (jobject)iv, bytes) == JNI_TRUE;
done:
    if ((*env)->ExceptionCheck(env)) success = 0;
    (*env)->PopLocalFrame(env, NULL);
    return success;
}

int32_t android_imageview_set_tint(void *env_ptr, void *iv, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    int32_t success = 0;
    if (ap_jni_PushLocalFrame(env, 5) != JNI_OK) return 0;
    jclass image_cls = ap_jni_GetObjectClass(env, (jobject)iv);
    if (!image_cls || (*env)->ExceptionCheck(env)) goto done;
    jclass colors_cls = ap_jni_FindClass(env, "android/content/res/ColorStateList");
    if (!colors_cls || (*env)->ExceptionCheck(env)) goto done;
    jclass mode_cls = ap_jni_FindClass(env, "android/graphics/PorterDuff$Mode");
    if (!image_cls || !colors_cls || !mode_cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID value_of = ap_jni_GetStaticMethodID(env, colors_cls, "valueOf", "(I)Landroid/content/res/ColorStateList;");
    if (!value_of || (*env)->ExceptionCheck(env)) goto done;
    jmethodID set_tint = ap_jni_GetMethodID(env, image_cls, "setImageTintList", "(Landroid/content/res/ColorStateList;)V");
    if (!set_tint || (*env)->ExceptionCheck(env)) goto done;
    jmethodID set_mode = ap_jni_GetMethodID(env, image_cls, "setImageTintMode", "(Landroid/graphics/PorterDuff$Mode;)V");
    if (!set_mode || (*env)->ExceptionCheck(env)) goto done;
    jfieldID src_in = ap_jni_GetStaticFieldID(env, mode_cls, "SRC_IN", "Landroid/graphics/PorterDuff$Mode;");
    if (!value_of || !set_tint || !set_mode || !src_in || (*env)->ExceptionCheck(env)) goto done;
    jobject colors = ap_jni_CallStaticObjectMethod(env, colors_cls, value_of, argb);
    if (!colors || (*env)->ExceptionCheck(env)) goto done;
    jobject mode = ap_jni_GetStaticObjectField(env, mode_cls, src_in);
    if (!mode || (*env)->ExceptionCheck(env)) goto done;
    ap_jni_CallVoidMethod(env, (jobject)iv, set_mode, mode);
    if ((*env)->ExceptionCheck(env)) goto done;
    ap_jni_CallVoidMethod(env, (jobject)iv, set_tint, colors);
    success = !(*env)->ExceptionCheck(env);
done:
    if ((*env)->ExceptionCheck(env)) success = 0;
    (*env)->PopLocalFrame(env, NULL);
    return success;
}

void android_edittext_set_hint(void *env_ptr, void *et, uint8_t *hint, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)et);
    jmethodID method = ap_get_method(env, cls, "setHint", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, hint, byte_len);
    if (method && value) {
        ap_jni_CallVoidMethod(env, (jobject)et, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_searchview_set_query_hint(void *env_ptr, void *sv, uint8_t *hint, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)sv);
    jmethodID method = ap_try_get_method(env, cls, "setQueryHint", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, hint, byte_len);
    if (method && value) {
        ap_jni_CallVoidMethod(env, (jobject)sv, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_searchview_set_query(void *env_ptr, void *sv, uint8_t *query, int32_t byte_len, int32_t submit) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)sv);
    jmethodID method = ap_try_get_method(env, cls, "setQuery", "(Ljava/lang/CharSequence;Z)V");
    jstring value = ap_new_string(env, query, byte_len);
    if (method && value) {
        ap_jni_CallVoidMethod(env, (jobject)sv, method, value, submit ? JNI_TRUE : JNI_FALSE);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_searchview_set_iconified(void *env_ptr, void *sv, int32_t iconified) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)sv);
    jmethodID set_default = ap_try_get_method(env, cls, "setIconifiedByDefault", "(Z)V");
    jmethodID set_iconified = ap_try_get_method(env, cls, "setIconified", "(Z)V");
    jboolean flag = iconified ? JNI_TRUE : JNI_FALSE;
    if (set_default) {
        ap_jni_CallVoidMethod(env, (jobject)sv, set_default, flag);
    }
    if (set_iconified) {
        ap_jni_CallVoidMethod(env, (jobject)sv, set_iconified, flag);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_spinner_set_prompt(void *env_ptr, void *spinner, uint8_t *prompt, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)spinner);
    jmethodID method = ap_try_get_method(env, cls, "setPrompt", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, prompt, byte_len);
    if (method && value) {
        ap_jni_CallVoidMethod(env, (jobject)spinner, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_spinner_set_selection(void *env_ptr, void *spinner, int32_t selected_index) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)spinner);
    jmethodID method = ap_try_get_method(env, cls, "setSelection", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)spinner, method, selected_index);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_spinner_set_items(void *env_ptr, void *spinner, uint8_t *joined_items, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass spinner_cls = ap_jni_GetObjectClass(env, (jobject)spinner);
    jmethodID get_context = ap_try_get_method(env, spinner_cls, "getContext", "()Landroid/content/Context;");
    jobject context = get_context ? ap_jni_CallObjectMethod(env, (jobject)spinner, get_context) : NULL;
    if (!context) {
        (*env)->DeleteLocalRef(env, spinner_cls);
        return;
    }

    jclass list_cls = ap_jni_FindClass(env, "java/util/ArrayList");
    jmethodID list_ctor = ap_get_method(env, list_cls, "<init>", "(I)V");
    jmethodID list_add = ap_get_method(env, list_cls, "add", "(Ljava/lang/Object;)Z");
    jobject items = ap_jni_NewObject(env, list_cls, list_ctor, 4);

    if (joined_items && byte_len > 0) {
        char *buffer = (char *)malloc((size_t)byte_len + 1U);
        if (buffer) {
            memcpy(buffer, joined_items, (size_t)byte_len);
            buffer[byte_len] = '\0';

            char *saveptr = NULL;
            char *token = strtok_r(buffer, "\n", &saveptr);
            while (token) {
                jstring value = ap_new_string(env, (const uint8_t *)token, -1);
                if (value) {
                    ap_jni_CallBooleanMethod(env, items, list_add, value);
                    (*env)->DeleteLocalRef(env, value);
                }
                token = strtok_r(NULL, "\n", &saveptr);
            }
            free(buffer);
        }
    }

    jclass layout_cls = ap_jni_FindClass(env, "android/R$layout");
    jfieldID simple_item_field = ap_jni_GetStaticFieldID(env, layout_cls, "simple_spinner_item", "I");
    jfieldID dropdown_item_field = ap_jni_GetStaticFieldID(env, layout_cls, "simple_spinner_dropdown_item", "I");
    jint simple_item_layout = simple_item_field ? ap_jni_GetStaticIntField(env, layout_cls, simple_item_field) : 0;
    jint dropdown_item_layout = dropdown_item_field ? ap_jni_GetStaticIntField(env, layout_cls, dropdown_item_field) : 0;

    jclass adapter_cls = ap_jni_FindClass(env, "android/widget/ArrayAdapter");
    jmethodID adapter_ctor = ap_get_method(env, adapter_cls, "<init>", "(Landroid/content/Context;ILjava/util/List;)V");
    jobject adapter = adapter_ctor ? ap_jni_NewObject(env, adapter_cls, adapter_ctor, context, simple_item_layout, items) : NULL;

    if (adapter) {
        jmethodID set_dropdown = ap_try_get_method(env, adapter_cls, "setDropDownViewResource", "(I)V");
        if (set_dropdown) {
            ap_jni_CallVoidMethod(env, adapter, set_dropdown, dropdown_item_layout);
        }
        jmethodID set_adapter = ap_try_get_method(env, spinner_cls, "setAdapter", "(Landroid/widget/SpinnerAdapter;)V");
        if (set_adapter) {
            ap_jni_CallVoidMethod(env, (jobject)spinner, set_adapter, adapter);
        }
    }

    if (adapter) {
        (*env)->DeleteLocalRef(env, adapter);
    }
    (*env)->DeleteLocalRef(env, adapter_cls);
    (*env)->DeleteLocalRef(env, layout_cls);
    (*env)->DeleteLocalRef(env, items);
    (*env)->DeleteLocalRef(env, list_cls);
    (*env)->DeleteLocalRef(env, context);
    (*env)->DeleteLocalRef(env, spinner_cls);
}

void android_edittext_set_input_type(void *env_ptr, void *et, int32_t input_type) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)et);
    jmethodID method = ap_get_method(env, cls, "setInputType", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)et, method, input_type);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_edittext_set_text(void *env_ptr, void *et, uint8_t *text, int32_t byte_len) {
    android_textview_set_text(env_ptr, et, text, byte_len);
}

void *android_edittext_get_text(void *env_ptr, void *et) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)et);
    jmethodID get_text = ap_get_method(env, cls, "getText", "()Landroid/text/Editable;");
    jobject editable = get_text ? ap_jni_CallObjectMethod(env, (jobject)et, get_text) : NULL;
    jstring result = NULL;
    if (editable) {
        jclass editable_cls = ap_jni_GetObjectClass(env, editable);
        jmethodID to_string = ap_get_method(env, editable_cls, "toString", "()Ljava/lang/String;");
        result = to_string ? ap_jni_CallObjectMethod(env, editable, to_string) : NULL;
        (*env)->DeleteLocalRef(env, editable_cls);
        (*env)->DeleteLocalRef(env, editable);
    }
    (*env)->DeleteLocalRef(env, cls);
    return result;
}

void android_textinputlayout_set_hint(void *env_ptr, void *til, uint8_t *hint, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)til);
    jmethodID method = ap_try_get_method(env, cls, "setHint", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, hint, byte_len);
    if (method && value) {
        ap_jni_CallVoidMethod(env, (jobject)til, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textinputlayout_set_placeholder_text(void *env_ptr, void *til, uint8_t *text, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)til);
    jmethodID method = ap_try_get_method(env, cls, "setPlaceholderText", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, text, byte_len);
    if (method && value) {
        ap_jni_CallVoidMethod(env, (jobject)til, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textinputlayout_set_helper_text(void *env_ptr, void *til, uint8_t *text, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)til);
    jmethodID method = ap_try_get_method(env, cls, "setHelperText", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, text, byte_len);
    if (method && value) {
        ap_jni_CallVoidMethod(env, (jobject)til, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textinputlayout_set_box_background_mode(void *env_ptr, void *til, int32_t mode) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)til);
    jmethodID method = ap_try_get_method(env, cls, "setBoxBackgroundMode", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)til, method, mode);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textinputlayout_set_box_background_color(void *env_ptr, void *til, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)til);
    jmethodID method = ap_try_get_method(env, cls, "setBoxBackgroundColor", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)til, method, argb);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textinputlayout_set_box_stroke_color(void *env_ptr, void *til, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)til);
    jmethodID method = ap_try_get_method(env, cls, "setBoxStrokeColor", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)til, method, argb);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textinputlayout_set_hint_text_color(void *env_ptr, void *til, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject tint = ap_make_color_state_list(env, argb);
    jclass cls = ap_jni_GetObjectClass(env, (jobject)til);
    jmethodID method = ap_try_get_method(env, cls, "setHintTextColor", "(Landroid/content/res/ColorStateList;)V");
    if (method && tint) {
        ap_jni_CallVoidMethod(env, (jobject)til, method, tint);
    }
    if (tint) {
        (*env)->DeleteLocalRef(env, tint);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textinputlayout_set_end_icon_mode(void *env_ptr, void *til, int32_t mode) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)til);
    jmethodID method = ap_try_get_method(env, cls, "setEndIconMode", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)til, method, mode);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_webview_load_url(void *env_ptr, void *web, uint8_t *url, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)web);
    jmethodID load_url = ap_get_method(env, cls, "loadUrl", "(Ljava/lang/String;)V");
    jstring url_value = ap_new_string(env, url, byte_len);
    if (load_url && url_value) {
        ap_jni_CallVoidMethod(env, (jobject)web, load_url, url_value);
    }
    if (url_value) {
        (*env)->DeleteLocalRef(env, url_value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_webview_load_html(void *env_ptr, void *web, uint8_t *html, int32_t html_len,
                               uint8_t *base_url, int32_t base_url_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass web_cls = ap_jni_GetObjectClass(env, (jobject)web);
    jmethodID get_settings = ap_try_get_method(env, web_cls, "getSettings", "()Landroid/webkit/WebSettings;");
    jobject settings = get_settings ? ap_jni_CallObjectMethod(env, (jobject)web, get_settings) : NULL;

    if (settings) {
        jclass settings_cls = ap_jni_GetObjectClass(env, settings);
        jmethodID set_js_enabled = ap_try_get_method(env, settings_cls, "setJavaScriptEnabled", "(Z)V");
        if (set_js_enabled) {
            ap_jni_CallVoidMethod(env, settings, set_js_enabled, JNI_TRUE);
        }
        (*env)->DeleteLocalRef(env, settings_cls);
        (*env)->DeleteLocalRef(env, settings);
    }

    jmethodID load_html = ap_get_method(
        env,
        web_cls,
        "loadDataWithBaseURL",
        "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V"
    );
    jstring base_value = ap_new_string(env, base_url, base_url_len);
    jstring html_value = ap_new_string(env, html, html_len);
    jstring mime_type = ap_jni_NewStringUTF(env, "text/html");
    jstring encoding = ap_jni_NewStringUTF(env, "utf-8");
    if (load_html && html_value && mime_type && encoding) {
        ap_jni_CallVoidMethod(env, (jobject)web, load_html, base_value, html_value, mime_type, encoding, NULL);
    }
    if (encoding) {
        (*env)->DeleteLocalRef(env, encoding);
    }
    if (mime_type) {
        (*env)->DeleteLocalRef(env, mime_type);
    }
    if (html_value) {
        (*env)->DeleteLocalRef(env, html_value);
    }
    if (base_value) {
        (*env)->DeleteLocalRef(env, base_value);
    }
    (*env)->DeleteLocalRef(env, web_cls);
}

void android_linearlayout_set_orientation(void *env_ptr, void *ll, int32_t orientation) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)ll);
    jmethodID method = ap_get_method(env, cls, "setOrientation", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)ll, method, orientation);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_linearlayout_set_gravity(void *env_ptr, void *ll, int32_t gravity) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)ll);
    jmethodID method = ap_get_method(env, cls, "setGravity", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)ll, method, gravity);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_viewgroup_add_view(void *env_ptr, void *parent, void *child) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeLayout");
    jmethodID method = ap_get_static_method(env, cls, "addChild", "(Landroid/view/ViewGroup;Landroid/view/View;)V");
    if (method) {
        ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)parent, (jobject)child);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_layout_prepare(void *env_ptr, void *view, float min_width, float min_height,
                            float max_width, float max_height, int32_t fill_horizontal, int32_t fill_vertical) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeLayout");
    jmethodID method = ap_get_static_method(env, cls, "prepare", "(Landroid/view/View;FFFFZZ)V");
    if (method) ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)view, min_width, min_height,
                                           max_width, max_height, fill_horizontal != 0, fill_vertical != 0);
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_state_metadata(void *env_ptr, void *view,
                                 const uint8_t *key, int32_t key_len,
                                 const uint8_t *kind, int32_t kind_len,
                                 const uint8_t *screen, int32_t screen_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (ap_jni_PushLocalFrame(env, 8) != JNI_OK) return;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeViewState");
    jmethodID method = ap_get_static_method(env, cls, "mark", "(Landroid/view/View;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
    jstring key_value = ap_new_string(env, key, key_len);
    jstring kind_value = ap_new_string(env, kind, kind_len);
    jstring screen_value = ap_new_string(env, screen, screen_len);
    if (method) ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)view, key_value, kind_value, screen_value);
    (*env)->PopLocalFrame(env, NULL);
}

void *android_layout_wrap(void *env_ptr, void *view) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeLayout");
    jmethodID method = ap_get_static_method(env, cls, "wrapPrepared", "(Landroid/view/View;)Landroid/view/View;");
    jobject result = method ? ap_jni_CallStaticObjectMethod(env, cls, method, (jobject)view) : NULL;
    (*env)->DeleteLocalRef(env, cls);
    return result;
}

void android_stack_set_alignment(void *env_ptr, void *view, int32_t alignment) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeLayout");
    jmethodID method = ap_get_static_method(env, cls, "configureStack", "(Landroid/view/View;I)V");
    if (method) ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)view, alignment);
    (*env)->DeleteLocalRef(env, cls);
}

void android_stack_set_equal_width(void *env_ptr, void *view, int32_t enabled) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeLayout");
    jmethodID method = ap_get_static_method(env, cls, "configureEqualWidth", "(Landroid/view/View;Z)V");
    if (method) ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)view, enabled != 0);
    (*env)->DeleteLocalRef(env, cls);
}

void android_layout_add_spacer(void *env_ptr, void *parent, void *child, float minimum) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeLayout");
    jmethodID method = ap_get_static_method(env, cls, "addSpacer", "(Landroid/view/ViewGroup;Landroid/view/View;F)V");
    if (method) ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)parent, (jobject)child, minimum);
    (*env)->DeleteLocalRef(env, cls);
}

void android_scrollview_configure(void *env_ptr, void *view, int32_t horizontal, int32_t vertical, int32_t indicators) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeLayout");
    jmethodID method = ap_get_static_method(env, cls, "configureScroll", "(Landroid/view/View;ZZZ)V");
    if (method) ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)view, horizontal != 0, vertical != 0, indicators != 0);
    (*env)->DeleteLocalRef(env, cls);
}

void android_viewgroup_add_view_wh(void *env_ptr, void *parent, void *child, int32_t width, int32_t height) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    float density = ap_view_density(env, (jobject)child);
    jclass cls = ap_jni_GetObjectClass(env, (jobject)parent);
    jmethodID method = ap_try_get_method(env, cls, "addView", "(Landroid/view/View;II)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)parent, method, (jobject)child,
                              ap_layout_dimension(density, width), ap_layout_dimension(density, height));
    } else {
        android_viewgroup_add_view(env_ptr, parent, child);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_linearlayout_add_view_weight(void *env_ptr, void *parent, void *child,
                                          int32_t width, int32_t height, float weight) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    float density = ap_view_density(env, (jobject)child);
    jclass params_cls = ap_jni_FindClass(env, "android/widget/LinearLayout$LayoutParams");
    jmethodID ctor = ap_get_method(env, params_cls, "<init>", "(IIF)V");
    jobject params = ctor ? ap_jni_NewObject(env, params_cls, ctor,
        ap_layout_dimension(density, width), ap_layout_dimension(density, height), weight) : NULL;

    jclass parent_cls = ap_jni_GetObjectClass(env, (jobject)parent);
    jmethodID add_view = ap_get_method(env, parent_cls, "addView", "(Landroid/view/View;Landroid/view/ViewGroup$LayoutParams;)V");
    if (add_view && params) {
        ap_jni_CallVoidMethod(env, (jobject)parent, add_view, (jobject)child, params);
    } else {
        android_viewgroup_add_view(env_ptr, parent, child);
    }

    if (params) {
        (*env)->DeleteLocalRef(env, params);
    }
    (*env)->DeleteLocalRef(env, parent_cls);
    (*env)->DeleteLocalRef(env, params_cls);
}

void android_viewgroup_remove_all(void *env_ptr, void *parent) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)parent);
    jmethodID method = ap_get_method(env, cls, "removeAllViews", "()V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)parent, method);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_visibility(void *env_ptr, void *v, int32_t visibility) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_get_method(env, cls, "setVisibility", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)v, method, visibility);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_enabled(void *env_ptr, void *v, int32_t enabled) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_try_get_method(env, cls, "setEnabled", "(Z)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)v, method, enabled ? JNI_TRUE : JNI_FALSE);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_alpha(void *env_ptr, void *v, float alpha) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_get_method(env, cls, "setAlpha", "(F)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)v, method, alpha);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_background_color(void *env_ptr, void *v, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject drawable = ap_ensure_gradient_background(env, (jobject)v);
    if (!drawable) {
        return;
    }

    jclass gradient_cls = ap_jni_GetObjectClass(env, drawable);
    jmethodID method = ap_try_get_method(env, gradient_cls, "setColor", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, drawable, method, argb);
    }
    (*env)->DeleteLocalRef(env, gradient_cls);
    (*env)->DeleteLocalRef(env, drawable);
}

void android_view_clear_background(void *env_ptr, void *v) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_try_get_method(env, cls, "setBackground", "(Landroid/graphics/drawable/Drawable;)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)v, method, NULL);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_content_description(void *env_ptr, void *v, uint8_t *desc, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_get_method(env, cls, "setContentDescription", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, desc, byte_len);
    if (method && value) {
        ap_jni_CallVoidMethod(env, (jobject)v, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_clip_to_outline(void *env_ptr, void *v, int32_t clip) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_try_get_method(env, cls, "setClipToOutline", "(Z)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)v, method, clip ? JNI_TRUE : JNI_FALSE);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_elevation(void *env_ptr, void *v, float dp) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_try_get_method(env, cls, "setElevation", "(F)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)v, method, ap_dp(env, (jobject)v, dp));
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_padding(void *env_ptr, void *v, int32_t left, int32_t top, int32_t right, int32_t bottom) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    float density = ap_view_density(env, (jobject)v);
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_get_method(env, cls, "setPadding", "(IIII)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)v, method,
            (jint)lroundf(left * density), (jint)lroundf(top * density),
            (jint)lroundf(right * density), (jint)lroundf(bottom * density));
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_padding_f(void *env_ptr, void *v, float left, float top, float right, float bottom) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    float density = ap_view_density(env, (jobject)v);
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_get_method(env, cls, "setPadding", "(IIII)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)v, method,
            (jint)lroundf(left * density), (jint)lroundf(top * density),
            (jint)lroundf(right * density), (jint)lroundf(bottom * density));
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_clear_focus(void *env_ptr, void *v) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_try_get_method(env, cls, "clearFocus", "()V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)v, method);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_semantics(void *env_ptr, void *v, uint8_t *packet, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (ap_jni_PushLocalFrame(env, 4) < 0) return;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeSemantics");
    jmethodID method = ap_jni_GetStaticMethodID(env, cls, "configure", "(Landroid/view/View;Ljava/lang/String;)V");
    jstring value = ap_new_string(env, packet, byte_len);
    ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)v, value);
    (*env)->PopLocalFrame(env, NULL);
}

void android_dialog_configure(void *env_ptr, void *view, uint8_t *packet, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (ap_jni_PushLocalFrame(env, 4) < 0) return;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeDialogs");
    jmethodID method = ap_jni_GetStaticMethodID(env, cls, "configure", "(Landroid/view/View;Ljava/lang/String;)V");
    jstring value = ap_new_string(env, packet, byte_len);
    ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)view, value);
    (*env)->PopLocalFrame(env, NULL);
}

void android_sheet_configure(void *env_ptr, void *view, uint8_t *packet, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (ap_jni_PushLocalFrame(env, 4) < 0) return;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeSheets");
    jmethodID method = ap_jni_GetStaticMethodID(env, cls, "configure", "(Landroid/view/View;Ljava/lang/String;)V");
    jstring value = ap_new_string(env, packet, byte_len);
    ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)view, value);
    (*env)->PopLocalFrame(env, NULL);
}

void android_sheet_request_dismiss(void *env_ptr, void *view) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (ap_jni_PushLocalFrame(env, 2) < 0) return;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeSheets");
    jmethodID method = ap_jni_GetStaticMethodID(env, cls, "requestDismiss", "(Landroid/view/View;)V");
    ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)view);
    (*env)->PopLocalFrame(env, NULL);
}

void android_view_set_corner_radius(void *env_ptr, void *v, float radius) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject drawable = ap_ensure_gradient_background(env, (jobject)v);
    if (!drawable) {
        return;
    }

    jclass gradient_cls = ap_jni_GetObjectClass(env, drawable);
    jmethodID method = ap_try_get_method(env, gradient_cls, "setCornerRadius", "(F)V");
    if (method) {
        ap_jni_CallVoidMethod(env, drawable, method, ap_dp(env, (jobject)v, radius));
    }
    (*env)->DeleteLocalRef(env, gradient_cls);
    (*env)->DeleteLocalRef(env, drawable);
}

void android_view_set_stroke(void *env_ptr, void *v, float width, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject drawable = ap_ensure_gradient_background(env, (jobject)v);
    if (!drawable) {
        return;
    }

    jclass gradient_cls = ap_jni_GetObjectClass(env, drawable);
    jmethodID method = ap_try_get_method(env, gradient_cls, "setStroke", "(II)V");
    if (method) {
        ap_jni_CallVoidMethod(env, drawable, method, (jint)lroundf(ap_dp(env, (jobject)v, width)), argb);
    }
    (*env)->DeleteLocalRef(env, gradient_cls);
    (*env)->DeleteLocalRef(env, drawable);
}

void android_material_button_set_background_tint(void *env_ptr, void *btn, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject tint = ap_make_color_state_list(env, argb);
    jclass cls = ap_jni_GetObjectClass(env, (jobject)btn);
    jmethodID method = ap_try_get_method(env, cls, "setBackgroundTintList", "(Landroid/content/res/ColorStateList;)V");
    if (method && tint) {
        ap_jni_CallVoidMethod(env, (jobject)btn, method, tint);
    }
    if (tint) {
        (*env)->DeleteLocalRef(env, tint);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_material_button_set_stroke_color(void *env_ptr, void *btn, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject tint = ap_make_color_state_list(env, argb);
    jclass cls = ap_jni_GetObjectClass(env, (jobject)btn);
    jmethodID method = ap_try_get_method(env, cls, "setStrokeColor", "(Landroid/content/res/ColorStateList;)V");
    if (method && tint) {
        ap_jni_CallVoidMethod(env, (jobject)btn, method, tint);
    }
    if (tint) {
        (*env)->DeleteLocalRef(env, tint);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_material_button_set_stroke_width(void *env_ptr, void *btn, int32_t width) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)btn);
    jmethodID method = ap_try_get_method(env, cls, "setStrokeWidth", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)btn, method, (jint)lroundf(ap_dp(env, (jobject)btn, width)));
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_material_button_set_corner_radius(void *env_ptr, void *btn, int32_t radius) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)btn);
    jmethodID method = ap_try_get_method(env, cls, "setCornerRadius", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)btn, method, (jint)lroundf(ap_dp(env, (jobject)btn, radius)));
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_material_button_set_corner_radius_f(void *env_ptr, void *btn, float radius) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)btn);
    jmethodID method = ap_try_get_method(env, cls, "setCornerRadius", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)btn, method, (jint)lroundf(ap_dp(env, (jobject)btn, radius)));
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_material_card_set_background_color(void *env_ptr, void *card, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)card);
    jmethodID method = ap_try_get_method(env, cls, "setCardBackgroundColor", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)card, method, argb);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_material_card_set_radius(void *env_ptr, void *card, float radius) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)card);
    jmethodID method = ap_try_get_method(env, cls, "setRadius", "(F)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)card, method, ap_dp(env, (jobject)card, radius));
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_material_card_set_elevation(void *env_ptr, void *card, float elevation) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)card);
    jmethodID method = ap_try_get_method(env, cls, "setCardElevation", "(F)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)card, method, ap_dp(env, (jobject)card, elevation));
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_material_card_set_stroke_color(void *env_ptr, void *card, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)card);
    jmethodID method = ap_try_get_method(env, cls, "setStrokeColor", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)card, method, argb);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_material_card_set_stroke_width(void *env_ptr, void *card, int32_t width) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)card);
    jmethodID method = ap_try_get_method(env, cls, "setStrokeWidth", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)card, method, (jint)lroundf(ap_dp(env, (jobject)card, width)));
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_toolbar_set_title(void *env_ptr, void *toolbar, uint8_t *title, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)toolbar);
    jmethodID method = ap_try_get_method(env, cls, "setTitle", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, title, byte_len);
    if (method && value) {
        ap_jni_CallVoidMethod(env, (jobject)toolbar, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_toolbar_set_title_text_color(void *env_ptr, void *toolbar, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)toolbar);
    jmethodID method = ap_try_get_method(env, cls, "setTitleTextColor", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)toolbar, method, argb);
    }
    (*env)->DeleteLocalRef(env, cls);
}

int32_t android_toolbar_set_navigation(void *env_ptr, void *toolbar, uint64_t callback_id, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (ap_jni_PushLocalFrame(env, 2) != JNI_OK) return 0;
    int32_t result = 0;
    jclass cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/NativeNavigation");
    if (!cls || (*env)->ExceptionCheck(env)) goto done;
    jmethodID method = ap_jni_GetStaticMethodID(env, cls, "configureToolbar", "(Lcom/google/android/material/appbar/MaterialToolbar;JI)V");
    if (!method || (*env)->ExceptionCheck(env)) goto done;
    ap_jni_CallStaticVoidMethod(env, cls, method, (jobject)toolbar, (jlong)callback_id, (jint)argb);
    result = !(*env)->ExceptionCheck(env);
done:
    if ((*env)->ExceptionCheck(env)) result = 0;
    (*env)->PopLocalFrame(env, NULL);
    return result;
}

void android_toolbar_add_menu_item(void *env_ptr, void *toolbar, int32_t item_id,
                                   uint8_t *title, int32_t byte_len, int32_t show_as_action) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass toolbar_cls = ap_jni_GetObjectClass(env, (jobject)toolbar);
    jmethodID get_menu = ap_try_get_method(env, toolbar_cls, "getMenu", "()Landroid/view/Menu;");
    jobject menu = get_menu ? ap_jni_CallObjectMethod(env, (jobject)toolbar, get_menu) : NULL;
    if (!menu) {
        (*env)->DeleteLocalRef(env, toolbar_cls);
        return;
    }

    jclass menu_cls = ap_jni_GetObjectClass(env, menu);
    jmethodID add = ap_try_get_method(env, menu_cls, "add", "(IIILjava/lang/CharSequence;)Landroid/view/MenuItem;");
    jstring value = ap_new_string(env, title, byte_len);
    jobject menu_item = (add && value) ? ap_jni_CallObjectMethod(env, menu, add, 0, item_id, 0, value) : NULL;
    if (menu_item) {
        jclass item_cls = ap_jni_GetObjectClass(env, menu_item);
        jmethodID set_show = ap_try_get_method(env, item_cls, "setShowAsAction", "(I)V");
        if (set_show) {
            ap_jni_CallVoidMethod(env, menu_item, set_show, show_as_action);
        }
        (*env)->DeleteLocalRef(env, item_cls);
        (*env)->DeleteLocalRef(env, menu_item);
    }

    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, menu_cls);
    (*env)->DeleteLocalRef(env, menu);
    (*env)->DeleteLocalRef(env, toolbar_cls);
}

void android_context_start_share_chooser(void *env_ptr, void *context_ptr,
                                         uint8_t *title, int32_t title_len,
                                         uint8_t *text, int32_t text_len,
                                         uint8_t *url, int32_t url_len,
                                         uint8_t *subject, int32_t subject_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject context = (jobject)context_ptr;
    if (!context) {
        return;
    }

    size_t share_len = 0U;
    if (text && text_len > 0) {
        share_len += (size_t)text_len;
    }
    if (url && url_len > 0) {
        if (share_len > 0U) {
            share_len += 1U;
        }
        share_len += (size_t)url_len;
    }
    if (share_len == 0U) {
        return;
    }

    char *share_buffer = (char *)malloc(share_len + 1U);
    if (!share_buffer) {
        return;
    }

    size_t cursor = 0U;
    if (text && text_len > 0) {
        memcpy(share_buffer + cursor, text, (size_t)text_len);
        cursor += (size_t)text_len;
    }
    if (url && url_len > 0) {
        if (cursor > 0U) {
            share_buffer[cursor++] = '\n';
        }
        memcpy(share_buffer + cursor, url, (size_t)url_len);
        cursor += (size_t)url_len;
    }
    share_buffer[cursor] = '\0';

    jclass intent_cls = ap_jni_FindClass(env, "android/content/Intent");
    jmethodID intent_ctor = ap_get_method(env, intent_cls, "<init>", "()V");
    jobject intent = intent_ctor ? ap_jni_NewObject(env, intent_cls, intent_ctor) : NULL;
    if (!intent) {
        free(share_buffer);
        (*env)->DeleteLocalRef(env, intent_cls);
        return;
    }

    jmethodID set_action = ap_try_get_method(env, intent_cls, "setAction", "(Ljava/lang/String;)Landroid/content/Intent;");
    jmethodID set_type = ap_try_get_method(env, intent_cls, "setType", "(Ljava/lang/String;)Landroid/content/Intent;");
    jmethodID put_extra = ap_try_get_method(env, intent_cls, "putExtra", "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;");
    jmethodID add_flags = ap_try_get_method(env, intent_cls, "addFlags", "(I)Landroid/content/Intent;");
    jmethodID create_chooser = ap_get_static_method(env, intent_cls, "createChooser", "(Landroid/content/Intent;Ljava/lang/CharSequence;)Landroid/content/Intent;");

    jfieldID action_send_field = ap_jni_GetStaticFieldID(env, intent_cls, "ACTION_SEND", "Ljava/lang/String;");
    jfieldID extra_text_field = ap_jni_GetStaticFieldID(env, intent_cls, "EXTRA_TEXT", "Ljava/lang/String;");
    jfieldID extra_subject_field = ap_jni_GetStaticFieldID(env, intent_cls, "EXTRA_SUBJECT", "Ljava/lang/String;");
    jfieldID new_task_field = ap_jni_GetStaticFieldID(env, intent_cls, "FLAG_ACTIVITY_NEW_TASK", "I");

    jobject action_send = action_send_field ? ap_jni_GetStaticObjectField(env, intent_cls, action_send_field) : NULL;
    jobject extra_text = extra_text_field ? ap_jni_GetStaticObjectField(env, intent_cls, extra_text_field) : NULL;
    jobject extra_subject = extra_subject_field ? ap_jni_GetStaticObjectField(env, intent_cls, extra_subject_field) : NULL;
    jint flag_new_task = new_task_field ? ap_jni_GetStaticIntField(env, intent_cls, new_task_field) : 0;

    jstring mime_type = ap_new_string(env, (const uint8_t *)"text/plain", -1);
    jstring share_body = ap_new_string(env, (const uint8_t *)share_buffer, (jint)cursor);
    jstring chooser_title = ap_new_string(env, title, title_len);
    jstring subject_value = ap_new_string(env, subject, subject_len);

    if (set_action && action_send) {
        ap_jni_CallObjectMethod(env, intent, set_action, action_send);
    }
    if (set_type && mime_type) {
        ap_jni_CallObjectMethod(env, intent, set_type, mime_type);
    }
    if (put_extra && extra_text && share_body) {
        ap_jni_CallObjectMethod(env, intent, put_extra, extra_text, share_body);
    }
    if (put_extra && extra_subject && subject_value) {
        ap_jni_CallObjectMethod(env, intent, put_extra, extra_subject, subject_value);
    }
    if (add_flags && flag_new_task != 0) {
        ap_jni_CallObjectMethod(env, intent, add_flags, flag_new_task);
    }

    jobject chooser = create_chooser ? ap_jni_CallStaticObjectMethod(env, intent_cls, create_chooser, intent, chooser_title) : NULL;
    if (chooser) {
        jclass context_cls = ap_jni_GetObjectClass(env, context);
        jmethodID start_activity = ap_try_get_method(env, context_cls, "startActivity", "(Landroid/content/Intent;)V");
        if (start_activity) {
            ap_jni_CallVoidMethod(env, context, start_activity, chooser);
        }
        (*env)->DeleteLocalRef(env, context_cls);
        (*env)->DeleteLocalRef(env, chooser);
    }

    if (subject_value) {
        (*env)->DeleteLocalRef(env, subject_value);
    }
    if (chooser_title) {
        (*env)->DeleteLocalRef(env, chooser_title);
    }
    if (share_body) {
        (*env)->DeleteLocalRef(env, share_body);
    }
    if (mime_type) {
        (*env)->DeleteLocalRef(env, mime_type);
    }
    if (extra_subject) {
        (*env)->DeleteLocalRef(env, extra_subject);
    }
    if (extra_text) {
        (*env)->DeleteLocalRef(env, extra_text);
    }
    if (action_send) {
        (*env)->DeleteLocalRef(env, action_send);
    }
    (*env)->DeleteLocalRef(env, intent);
    (*env)->DeleteLocalRef(env, intent_cls);
    free(share_buffer);
}

void android_switch_set_checked(void *env_ptr, void *sw, int32_t checked) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)sw);
    jmethodID method = ap_get_method(env, cls, "setChecked", "(Z)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)sw, method, checked ? JNI_TRUE : JNI_FALSE);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_switch_set_thumb_tint(void *env_ptr, void *sw, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject tint = ap_make_color_state_list(env, argb);
    jclass cls = ap_jni_GetObjectClass(env, (jobject)sw);
    jmethodID method = ap_try_get_method(env, cls, "setThumbTintList", "(Landroid/content/res/ColorStateList;)V");
    if (method && tint) {
        ap_jni_CallVoidMethod(env, (jobject)sw, method, tint);
    }
    if (tint) {
        (*env)->DeleteLocalRef(env, tint);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_switch_set_track_tint(void *env_ptr, void *sw, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject tint = ap_make_color_state_list(env, argb);
    jclass cls = ap_jni_GetObjectClass(env, (jobject)sw);
    jmethodID method = ap_try_get_method(env, cls, "setTrackTintList", "(Landroid/content/res/ColorStateList;)V");
    if (method && tint) {
        ap_jni_CallVoidMethod(env, (jobject)sw, method, tint);
    }
    if (tint) {
        (*env)->DeleteLocalRef(env, tint);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_checkbox_set_checked(void *env_ptr, void *cb, int32_t checked) {
    android_switch_set_checked(env_ptr, cb, checked);
}

void android_checkbox_set_text(void *env_ptr, void *cb, uint8_t *text, int32_t byte_len) {
    android_textview_set_text(env_ptr, cb, text, byte_len);
}

void android_checkbox_set_button_tint(void *env_ptr, void *cb, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject tint = ap_make_color_state_list(env, argb);
    jclass cls = ap_jni_GetObjectClass(env, (jobject)cb);
    jmethodID method = ap_try_get_method(env, cls, "setButtonTintList", "(Landroid/content/res/ColorStateList;)V");
    if (method && tint) {
        ap_jni_CallVoidMethod(env, (jobject)cb, method, tint);
    }
    if (tint) {
        (*env)->DeleteLocalRef(env, tint);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_radiogroup_check(void *env_ptr, void *rg, int32_t child_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)rg);
    jmethodID method = ap_get_method(env, cls, "check", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)rg, method, child_id);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_radiobutton_set_text(void *env_ptr, void *rb, uint8_t *text, int32_t byte_len) {
    android_textview_set_text(env_ptr, rb, text, byte_len);
}

void android_radiobutton_set_checked(void *env_ptr, void *rb, int32_t checked) {
    android_switch_set_checked(env_ptr, rb, checked);
}

int32_t android_view_generate_id(void *env_ptr) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_FindClass(env, "android/view/View");
    jmethodID method = ap_get_static_method(env, cls, "generateViewId", "()I");
    jint result = method ? ap_jni_CallStaticIntMethod(env, cls, method) : 0;
    (*env)->DeleteLocalRef(env, cls);
    return result;
}

void android_view_set_id(void *env_ptr, void *v, int32_t view_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_try_get_method(env, cls, "setId", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)v, method, view_id);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_progressbar_set_indeterminate(void *env_ptr, void *pb, int32_t indeterminate) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)pb);
    jmethodID method = ap_get_method(env, cls, "setIndeterminate", "(Z)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)pb, method, (jboolean)(indeterminate != 0));
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_togglebutton_set_text_on_off(void *env_ptr, void *v, uint8_t *text, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID on = ap_get_method(env, cls, "setTextOn", "(Ljava/lang/CharSequence;)V");
    jmethodID off = ap_get_method(env, cls, "setTextOff", "(Ljava/lang/CharSequence;)V");
    jmethodID text_method = ap_get_method(env, cls, "setText", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, text, byte_len);
    if (value) {
        if (on) ap_jni_CallVoidMethod(env, (jobject)v, on, value);
        if (off) ap_jni_CallVoidMethod(env, (jobject)v, off, value);
        if (text_method) ap_jni_CallVoidMethod(env, (jobject)v, text_method, value);
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_button_set_open_url_on_click(void *env_ptr, void *v, uint8_t *url, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass listener_cls = ap_jni_FindClass(env, "dev/assetpipeline/androidhost/CrystalOpenUrlListener");
    jmethodID ctor = listener_cls ? ap_get_method(env, listener_cls, "<init>", "(Ljava/lang/String;)V") : NULL;
    jstring value = ap_new_string(env, url, byte_len);
    jobject listener = (ctor && value) ? ap_jni_NewObject(env, listener_cls, ctor, value) : NULL;
    if (listener) {
        jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
        jmethodID method = ap_try_get_method(env, cls, "setOnClickListener", "(Landroid/view/View$OnClickListener;)V");
        if (method) ap_jni_CallVoidMethod(env, (jobject)v, method, listener);
        (*env)->DeleteLocalRef(env, cls);
        (*env)->DeleteLocalRef(env, listener);
    }
    if (value) (*env)->DeleteLocalRef(env, value);
    if (listener_cls) (*env)->DeleteLocalRef(env, listener_cls);
}

void android_seekbar_set_max(void *env_ptr, void *sb, int32_t max) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)sb);
    jmethodID method = ap_get_method(env, cls, "setMax", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)sb, method, max);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_seekbar_set_progress(void *env_ptr, void *sb, int32_t progress) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)sb);
    jmethodID method = ap_get_method(env, cls, "setProgress", "(I)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)sb, method, progress);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_seekbar_set_progress_tint(void *env_ptr, void *sb, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject tint = ap_make_color_state_list(env, argb);
    jclass cls = ap_jni_GetObjectClass(env, (jobject)sb);
    jmethodID method = ap_try_get_method(env, cls, "setProgressTintList", "(Landroid/content/res/ColorStateList;)V");
    if (method && tint) {
        ap_jni_CallVoidMethod(env, (jobject)sb, method, tint);
    }
    if (tint) {
        (*env)->DeleteLocalRef(env, tint);
    }
    (*env)->DeleteLocalRef(env, cls);
}

int32_t android_seekbar_get_progress(void *env_ptr, void *sb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)sb);
    jmethodID method = ap_get_method(env, cls, "getProgress", "()I");
    jint result = method ? ap_jni_CallIntMethod(env, (jobject)sb, method) : 0;
    (*env)->DeleteLocalRef(env, cls);
    return result;
}

int32_t android_compoundbutton_is_checked(void *env_ptr, void *button) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)button);
    jmethodID method = ap_try_get_method(env, cls, "isChecked", "()Z");
    jint result = method ? (ap_jni_CallBooleanMethod(env, (jobject)button, method) ? 1 : 0) : 0;
    (*env)->DeleteLocalRef(env, cls);
    return result;
}

int32_t android_radiogroup_get_checked_radio_button_id(void *env_ptr, void *rg) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)rg);
    jmethodID method = ap_try_get_method(env, cls, "getCheckedRadioButtonId", "()I");
    jint result = method ? ap_jni_CallIntMethod(env, (jobject)rg, method) : -1;
    (*env)->DeleteLocalRef(env, cls);
    return result;
}

void android_view_set_on_click_listener(void *env_ptr, void *v, uint64_t callback_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject listener = ap_new_callback_helper(env, "dev/assetpipeline/androidhost/CrystalClickListener", callback_id);
    if (!listener) {
        return;
    }

    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_try_get_method(env, cls, "setOnClickListener", "(Landroid/view/View$OnClickListener;)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)v, method, listener);
    }
    (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, listener);
}

void android_view_set_on_checked_change_listener(void *env_ptr, void *v, uint64_t callback_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject listener = ap_new_callback_helper(env, "dev/assetpipeline/androidhost/CrystalCheckedChangeListener", callback_id);
    if (!listener) {
        return;
    }

    jclass cls = ap_jni_GetObjectClass(env, (jobject)v);
    jmethodID method = ap_try_get_method(env, cls, "setOnCheckedChangeListener", "(Landroid/widget/CompoundButton$OnCheckedChangeListener;)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)v, method, listener);
    }
    (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, listener);
}

void android_seekbar_set_on_change_listener(void *env_ptr, void *sb, uint64_t callback_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject listener = ap_new_callback_helper(env, "dev/assetpipeline/androidhost/CrystalSeekBarChangeListener", callback_id);
    if (!listener) {
        return;
    }

    jclass cls = ap_jni_GetObjectClass(env, (jobject)sb);
    jmethodID method = ap_try_get_method(env, cls, "setOnSeekBarChangeListener", "(Landroid/widget/SeekBar$OnSeekBarChangeListener;)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)sb, method, listener);
    }
    (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, listener);
}

static void ap_bind_callback_owner(JNIEnv *env, jobject listener, jobject view) {
    jclass cls = ap_jni_GetObjectClass(env, listener);
    jmethodID method = ap_jni_GetMethodID(env, cls, "bindOwner", "(Landroid/view/View;)V");
    ap_jni_CallVoidMethod(env, listener, method, view);
    (*env)->DeleteLocalRef(env, cls);
}

void android_edittext_set_text_watcher(void *env_ptr, void *et, uint64_t callback_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject watcher = ap_new_callback_helper(env, "dev/assetpipeline/androidhost/CrystalTextWatcher", callback_id);
    if (!watcher) {
        return;
    }
    ap_bind_callback_owner(env, watcher, (jobject)et);

    jclass cls = ap_jni_GetObjectClass(env, (jobject)et);
    jmethodID method = ap_try_get_method(env, cls, "addTextChangedListener", "(Landroid/text/TextWatcher;)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)et, method, watcher);
    }
    (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, watcher);
}

void android_edittext_set_submit_listener(void *env_ptr, void *et, uint64_t callback_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject listener = ap_new_callback_helper(env, "dev/assetpipeline/androidhost/CrystalEditorActionListener", callback_id);
    if (!listener) return;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)et);
    jmethodID method = ap_get_method(env, cls, "setOnEditorActionListener", "(Landroid/widget/TextView$OnEditorActionListener;)V");
    if (method) ap_jni_CallVoidMethod(env, (jobject)et, method, listener);
    if (!(*env)->ExceptionCheck(env)) {
        jmethodID options = ap_get_method(env, cls, "setImeOptions", "(I)V");
        if (options) ap_jni_CallVoidMethod(env, (jobject)et, options, 6); // IME_ACTION_DONE
    }
    (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, listener);
}

void android_edittext_set_read_only(void *env_ptr, void *et) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = ap_jni_GetObjectClass(env, (jobject)et);
    jmethodID method = ap_get_method(env, cls, "setKeyListener", "(Landroid/text/method/KeyListener;)V");
    if (method) ap_jni_CallVoidMethod(env, (jobject)et, method, NULL);
    (*env)->DeleteLocalRef(env, cls);
}

void android_radiogroup_set_on_checked_change_listener(void *env_ptr, void *rg, uint64_t callback_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject listener = ap_new_callback_helper(env, "dev/assetpipeline/androidhost/CrystalRadioGroupCheckedChangeListener", callback_id);
    if (!listener) {
        return;
    }

    jclass cls = ap_jni_GetObjectClass(env, (jobject)rg);
    jmethodID method = ap_try_get_method(env, cls, "setOnCheckedChangeListener", "(Landroid/widget/RadioGroup$OnCheckedChangeListener;)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)rg, method, listener);
    }
    (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, listener);
}

void android_searchview_set_on_query_text_listener(void *env_ptr, void *sv, uint64_t change_callback_id, uint64_t submit_callback_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject listener = ap_new_dual_callback_helper(
        env,
        "dev/assetpipeline/androidhost/CrystalSearchQueryListener",
        change_callback_id,
        submit_callback_id
    );
    if (!listener) {
        return;
    }
    ap_bind_callback_owner(env, listener, (jobject)sv);

    jclass cls = ap_jni_GetObjectClass(env, (jobject)sv);
    jmethodID method = ap_try_get_method(env, cls, "setOnQueryTextListener", "(Landroid/widget/SearchView$OnQueryTextListener;)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)sv, method, listener);
    }
    (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, listener);
}

void android_searchview_set_on_close_listener(void *env_ptr, void *sv, uint64_t callback_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject listener = ap_new_callback_helper(env, "dev/assetpipeline/androidhost/CrystalSearchCloseListener", callback_id);
    if (!listener) {
        return;
    }
    ap_bind_callback_owner(env, listener, (jobject)sv);

    jclass cls = ap_jni_GetObjectClass(env, (jobject)sv);
    jmethodID method = ap_try_get_method(env, cls, "setOnCloseListener", "(Landroid/widget/SearchView$OnCloseListener;)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)sv, method, listener);
    }
    (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, listener);
}

void android_spinner_set_on_item_selected_listener(void *env_ptr, void *spinner, uint64_t callback_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject listener = ap_new_callback_helper(env, "dev/assetpipeline/androidhost/CrystalItemSelectedListener", callback_id);
    if (!listener) {
        return;
    }

    jclass cls = ap_jni_GetObjectClass(env, (jobject)spinner);
    jmethodID method = ap_try_get_method(env, cls, "setOnItemSelectedListener", "(Landroid/widget/AdapterView$OnItemSelectedListener;)V");
    if (method) {
        ap_jni_CallVoidMethod(env, (jobject)spinner, method, listener);
    }
    (*env)->DeleteLocalRef(env, cls);
    (*env)->DeleteLocalRef(env, listener);
}

extern void jni_track_global_ref_created(void);
extern void jni_track_global_ref_deleted(void);

void *android_new_global_ref(void *env_ptr, void *local_ref) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject global_ref = ap_jni_NewGlobalRef(env, (jobject)local_ref);
    if (global_ref) {
        jni_track_global_ref_created();
    }
    return global_ref;
}

void android_delete_global_ref(void *env_ptr, void *global_ref) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (global_ref) {
        (*env)->DeleteGlobalRef(env, (jobject)global_ref);
        jni_track_global_ref_deleted();
    }
}

// Phase 5 — Glass material RenderEffect bridge.
//
// Calls the host's AssetPipelineGlassHelper.applyGlass(view, blurRadius,
// fallbackArgb) static helper. The helper itself decides API 31+ blur vs
// alpha fill — Crystal-side resolution remains uniform. Returns 1 if a
// real RenderEffect blur was applied, 0 if the fallback alpha was used or
// the helper class could not be loaded (e.g., the consumer app did not
// bundle the helper).
int32_t android_view_apply_glass(void *env_ptr, void *view, float blur_radius, int32_t fallback_argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if ((*env)->ExceptionCheck(env)) return 0;
    jclass helper_cls = ap_jni_FindClass(env, "com/assetpipeline/glass/AssetPipelineGlassHelper");
    if (!helper_cls) {
        if ((*env)->ExceptionCheck(env)) {
            ap_jni_clear_expected(env, "java/lang/ClassNotFoundException");
        }
        return 0;
    }
    jmethodID apply = ap_get_static_method(env, helper_cls, "applyGlass", "(Landroid/view/View;FI)Z");
    if (!apply) {
        (*env)->DeleteLocalRef(env, helper_cls);
        return 0;
    }
    jboolean result = ap_jni_CallStaticBooleanMethod(env, helper_cls, apply,
                                                     (jobject)view,
                                                     (jfloat)ap_dp(env, (jobject)view, blur_radius),
                                                     (jint)fallback_argb);
    (*env)->DeleteLocalRef(env, helper_cls);
    return result ? 1 : 0;
}

// ============================================================================
// Phase 10B.3.x — Class C feature bridge functions (Android / JNI branch).
//
// Each function takes (void *env_ptr, void *context_ptr) plus feature args.
// `context_ptr` is the application Context (or any subclass) used for
// system-service lookups; the Crystal-side renderer stashes it at app
// boot via the JNI surface and passes it down to each Class C dispatch.
//
// Functions that need to return data (clipboard read, file picker) route
// the result through `crystal_ui_string_callback_dispatch` using a token
// the caller passes in. The same symbol is exposed by the objc bridge —
// the Crystal-side `CallbackRegistry` is platform-agnostic.
// ============================================================================

extern int crystal_android_host_callback_string(unsigned long long token, const uint8_t *value, int32_t byte_len);

static int ap_clipboard_empty_callback(JNIEnv *env, unsigned long long token) {
    if ((*env)->ExceptionCheck(env)) return -1;
    return crystal_android_host_callback_string(token, (const uint8_t *)"", 0) ? 0 : -1;
}

// :copy_to_clipboard — write `text` to the system clipboard via
// ClipboardManager. ClipData.newPlainText("ap_clipboard", text).
//
// Reachable from any thread; ClipboardManager is thread-safe.
void ap_clipboard_write_android(void *env_ptr, void *context_ptr,
                                uint8_t *text, int32_t text_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject context = (jobject)context_ptr;
    if (!context) return;

    jclass context_cls = ap_jni_GetObjectClass(env, context);
    jmethodID get_system_service = ap_try_get_method(env, context_cls, "getSystemService",
                                                     "(Ljava/lang/String;)Ljava/lang/Object;");
    if (!get_system_service) {
        (*env)->DeleteLocalRef(env, context_cls);
        return;
    }

    jstring service_name = ap_new_string(env, (const uint8_t *)"clipboard", -1);
    jobject manager = ap_jni_CallObjectMethod(env, context, get_system_service, service_name);
    (*env)->DeleteLocalRef(env, service_name);
    if (!manager) {
        (*env)->DeleteLocalRef(env, context_cls);
        return;
    }

    jclass clipdata_cls = ap_jni_FindClass(env, "android/content/ClipData");
    jmethodID new_plain_text = ap_get_static_method(env, clipdata_cls, "newPlainText",
                                                   "(Ljava/lang/CharSequence;Ljava/lang/CharSequence;)Landroid/content/ClipData;");
    jstring label = ap_new_string(env, (const uint8_t *)"ap_clipboard", -1);
    jstring value = ap_new_string(env, text, text_len);
    jobject clip = ap_jni_CallStaticObjectMethod(env, clipdata_cls, new_plain_text, label, value);

    jclass manager_cls = ap_jni_GetObjectClass(env, manager);
    jmethodID set_primary_clip = ap_try_get_method(env, manager_cls, "setPrimaryClip",
                                                   "(Landroid/content/ClipData;)V");
    if (set_primary_clip && clip) {
        ap_jni_CallVoidMethod(env, manager, set_primary_clip, clip);
    }

    if (clip) (*env)->DeleteLocalRef(env, clip);
    if (value) (*env)->DeleteLocalRef(env, value);
    if (label) (*env)->DeleteLocalRef(env, label);
    (*env)->DeleteLocalRef(env, manager_cls);
    (*env)->DeleteLocalRef(env, clipdata_cls);
    (*env)->DeleteLocalRef(env, manager);
    (*env)->DeleteLocalRef(env, context_cls);
}

// :paste_from_clipboard — read the primary ClipData item's text and
// route to the Crystal callback. Returns 1 on success, 0 if the
// clipboard is empty or unavailable; -1 means conversion/callback failure.
int ap_clipboard_read_android(void *env_ptr, void *context_ptr,
                              unsigned long long token) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject context = (jobject)context_ptr;
    if (!context) {
        return ap_clipboard_empty_callback(env, token);
    }

    jclass context_cls = ap_jni_GetObjectClass(env, context);
    jmethodID get_system_service = ap_try_get_method(env, context_cls, "getSystemService",
                                                     "(Ljava/lang/String;)Ljava/lang/Object;");
    if (!get_system_service) {
        (*env)->DeleteLocalRef(env, context_cls);
        return ap_clipboard_empty_callback(env, token);
    }

    jstring service_name = ap_new_string(env, (const uint8_t *)"clipboard", -1);
    jobject manager = ap_jni_CallObjectMethod(env, context, get_system_service, service_name);
    (*env)->DeleteLocalRef(env, service_name);
    (*env)->DeleteLocalRef(env, context_cls);
    if (!manager) {
        return ap_clipboard_empty_callback(env, token);
    }

    jclass manager_cls = ap_jni_GetObjectClass(env, manager);
    jmethodID get_primary_clip = ap_try_get_method(env, manager_cls, "getPrimaryClip",
                                                   "()Landroid/content/ClipData;");
    jobject clip = get_primary_clip ? ap_jni_CallObjectMethod(env, manager, get_primary_clip) : NULL;
    (*env)->DeleteLocalRef(env, manager_cls);
    (*env)->DeleteLocalRef(env, manager);

    if (!clip) {
        return ap_clipboard_empty_callback(env, token);
    }

    jclass clip_cls = ap_jni_GetObjectClass(env, clip);
    jmethodID get_item_count = ap_try_get_method(env, clip_cls, "getItemCount", "()I");
    jmethodID get_item_at = ap_try_get_method(env, clip_cls, "getItemAt", "(I)Landroid/content/ClipData$Item;");
    jint count = get_item_count ? ap_jni_CallIntMethod(env, clip, get_item_count) : 0;
    if (count <= 0 || !get_item_at) {
        (*env)->DeleteLocalRef(env, clip_cls);
        (*env)->DeleteLocalRef(env, clip);
        return ap_clipboard_empty_callback(env, token);
    }

    jobject item = ap_jni_CallObjectMethod(env, clip, get_item_at, 0);
    (*env)->DeleteLocalRef(env, clip_cls);
    (*env)->DeleteLocalRef(env, clip);
    if (!item) {
        return ap_clipboard_empty_callback(env, token);
    }

    jclass item_cls = ap_jni_GetObjectClass(env, item);
    jmethodID get_text = ap_try_get_method(env, item_cls, "getText", "()Ljava/lang/CharSequence;");
    jobject text_seq = get_text ? ap_jni_CallObjectMethod(env, item, get_text) : NULL;
    (*env)->DeleteLocalRef(env, item_cls);
    (*env)->DeleteLocalRef(env, item);

    if (!text_seq) {
        return ap_clipboard_empty_callback(env, token);
    }

    // text_seq is a CharSequence; the easiest path is its toString().
    jclass cs_cls = ap_jni_GetObjectClass(env, text_seq);
    jmethodID to_string = ap_try_get_method(env, cs_cls, "toString", "()Ljava/lang/String;");
    jstring jstr = to_string ? (jstring)ap_jni_CallObjectMethod(env, text_seq, to_string) : NULL;
    (*env)->DeleteLocalRef(env, cs_cls);
    (*env)->DeleteLocalRef(env, text_seq);

    if (!jstr) {
        return ap_clipboard_empty_callback(env, token);
    }

    int32_t byte_len = 0;
    uint8_t *utf = ap_string_copy_utf8(env, jstr, &byte_len);
    int success = utf ? crystal_android_host_callback_string(token, utf, byte_len) : 0;
    free(utf);
    (*env)->DeleteLocalRef(env, jstr);
    return success ? 1 : -1;
}

// :open_url — fire an Intent.ACTION_VIEW with the given URL.
int ap_open_url_android(void *env_ptr, void *context_ptr,
                        uint8_t *url, int32_t url_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject context = (jobject)context_ptr;
    if (!context || !url || url_len <= 0) return 0;

    jclass uri_cls = ap_jni_FindClass(env, "android/net/Uri");
    jmethodID parse = ap_get_static_method(env, uri_cls, "parse",
                                            "(Ljava/lang/String;)Landroid/net/Uri;");
    jstring url_str = ap_new_string(env, url, url_len);
    jobject uri = ap_jni_CallStaticObjectMethod(env, uri_cls, parse, url_str);
    (*env)->DeleteLocalRef(env, url_str);
    (*env)->DeleteLocalRef(env, uri_cls);
    if (!uri) return 0;

    jclass intent_cls = ap_jni_FindClass(env, "android/content/Intent");
    jfieldID action_view_field = ap_jni_GetStaticFieldID(env, intent_cls, "ACTION_VIEW", "Ljava/lang/String;");
    jstring action_view = action_view_field ? ap_jni_GetStaticObjectField(env, intent_cls, action_view_field) : NULL;
    jmethodID intent_ctor = ap_get_method(env, intent_cls, "<init>",
                                          "(Ljava/lang/String;Landroid/net/Uri;)V");
    jobject intent = (action_view && intent_ctor)
        ? ap_jni_NewObject(env, intent_cls, intent_ctor, action_view, uri)
        : NULL;
    (*env)->DeleteLocalRef(env, uri);
    if (action_view) (*env)->DeleteLocalRef(env, action_view);
    if (!intent) {
        (*env)->DeleteLocalRef(env, intent_cls);
        return 0;
    }

    jmethodID add_flags = ap_try_get_method(env, intent_cls, "addFlags",
                                            "(I)Landroid/content/Intent;");
    jfieldID new_task_field = ap_jni_GetStaticFieldID(env, intent_cls, "FLAG_ACTIVITY_NEW_TASK", "I");
    jint flag_new_task = new_task_field ? ap_jni_GetStaticIntField(env, intent_cls, new_task_field) : 0;
    if (add_flags && flag_new_task != 0) {
        ap_jni_CallObjectMethod(env, intent, add_flags, flag_new_task);
    }

    jclass context_cls = ap_jni_GetObjectClass(env, context);
    jmethodID start_activity = ap_try_get_method(env, context_cls, "startActivity",
                                                 "(Landroid/content/Intent;)V");
    int ok = 0;
    if (start_activity) {
        ap_jni_CallVoidMethod(env, context, start_activity, intent);
        if ((*env)->ExceptionCheck(env)) {
            // Only a missing intent handler is an expected fallback.
            ap_jni_clear_expected(env, "android/content/ActivityNotFoundException");
            ok = 0;
        } else {
            ok = 1;
        }
    }
    (*env)->DeleteLocalRef(env, context_cls);
    (*env)->DeleteLocalRef(env, intent);
    (*env)->DeleteLocalRef(env, intent_cls);
    return ok;
}
