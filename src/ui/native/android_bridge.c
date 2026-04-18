#include <jni.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static jstring ap_new_string(JNIEnv *env, const uint8_t *bytes, jint byte_len) {
    if (!bytes) {
        return NULL;
    }

    if (byte_len < 0) {
        byte_len = (jint)strlen((const char *)bytes);
    }

    char *buffer = (char *)malloc((size_t)byte_len + 1U);
    if (!buffer) {
        return NULL;
    }

    memcpy(buffer, bytes, (size_t)byte_len);
    buffer[byte_len] = '\0';
    jstring str = (*env)->NewStringUTF(env, buffer);
    free(buffer);
    return str;
}

static jmethodID ap_get_method(JNIEnv *env, jclass cls, const char *name, const char *sig) {
    return (*env)->GetMethodID(env, cls, name, sig);
}

static jmethodID ap_try_get_method(JNIEnv *env, jclass cls, const char *name, const char *sig) {
    jmethodID method = (*env)->GetMethodID(env, cls, name, sig);
    if (!method && (*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
    }
    return method;
}

static jmethodID ap_get_static_method(JNIEnv *env, jclass cls, const char *name, const char *sig) {
    return (*env)->GetStaticMethodID(env, cls, name, sig);
}

static jobject ap_make_color_state_list(JNIEnv *env, jint argb) {
    jclass cls = (*env)->FindClass(env, "android/content/res/ColorStateList");
    if (!cls) {
        return NULL;
    }

    jmethodID value_of = ap_get_static_method(env, cls, "valueOf", "(I)Landroid/content/res/ColorStateList;");
    jobject color_state_list = value_of ? (*env)->CallStaticObjectMethod(env, cls, value_of, argb) : NULL;
    (*env)->DeleteLocalRef(env, cls);
    return color_state_list;
}

static jobject ap_ensure_gradient_background(JNIEnv *env, jobject view) {
    jclass view_cls = (*env)->GetObjectClass(env, view);
    jmethodID get_background = ap_get_method(env, view_cls, "getBackground", "()Landroid/graphics/drawable/Drawable;");
    jobject background = get_background ? (*env)->CallObjectMethod(env, view, get_background) : NULL;

    jclass gradient_cls = (*env)->FindClass(env, "android/graphics/drawable/GradientDrawable");
    if (background && gradient_cls && (*env)->IsInstanceOf(env, background, gradient_cls)) {
        (*env)->DeleteLocalRef(env, view_cls);
        (*env)->DeleteLocalRef(env, gradient_cls);
        return background;
    }

    if (background) {
        (*env)->DeleteLocalRef(env, background);
    }

    jmethodID ctor = ap_get_method(env, gradient_cls, "<init>", "()V");
    jobject gradient = ctor ? (*env)->NewObject(env, gradient_cls, ctor) : NULL;

    if (gradient) {
        jmethodID set_color = ap_try_get_method(env, gradient_cls, "setColor", "(I)V");
        jmethodID set_shape = ap_try_get_method(env, gradient_cls, "setShape", "(I)V");
        jmethodID set_background = ap_get_method(env, view_cls, "setBackground", "(Landroid/graphics/drawable/Drawable;)V");

        if (set_shape) {
            (*env)->CallVoidMethod(env, gradient, set_shape, 0);
        }
        if (set_color) {
            (*env)->CallVoidMethod(env, gradient, set_color, 0x00000000);
        }
        if (set_background) {
            (*env)->CallVoidMethod(env, view, set_background, gradient);
        }
    }

    (*env)->DeleteLocalRef(env, view_cls);
    (*env)->DeleteLocalRef(env, gradient_cls);
    return gradient;
}

void *android_view_new(void *env_ptr, uint8_t *class_name, void *context) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->FindClass(env, (const char *)class_name);
    if (!cls) {
        return NULL;
    }

    jmethodID ctor = ap_get_method(env, cls, "<init>", "(Landroid/content/Context;)V");
    jobject view = ctor ? (*env)->NewObject(env, cls, ctor, (jobject)context) : NULL;
    (*env)->DeleteLocalRef(env, cls);
    return view;
}

void android_textview_set_text(void *env_ptr, void *tv, uint8_t *text, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)tv);
    jmethodID method = ap_get_method(env, cls, "setText", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, text, byte_len);
    if (method && value) {
        (*env)->CallVoidMethod(env, (jobject)tv, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textview_set_text_size(void *env_ptr, void *tv, float size_sp) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)tv);
    jmethodID method = ap_get_method(env, cls, "setTextSize", "(F)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)tv, method, size_sp);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textview_set_text_color(void *env_ptr, void *tv, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)tv);
    jmethodID method = ap_get_method(env, cls, "setTextColor", "(I)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)tv, method, argb);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textview_set_gravity(void *env_ptr, void *tv, int32_t gravity) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)tv);
    jmethodID method = ap_get_method(env, cls, "setGravity", "(I)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)tv, method, gravity);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textview_set_max_lines(void *env_ptr, void *tv, int32_t max) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)tv);
    jmethodID method = ap_get_method(env, cls, "setMaxLines", "(I)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)tv, method, max);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textview_set_single_line(void *env_ptr, void *tv, int32_t single) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)tv);
    jmethodID method = ap_get_method(env, cls, "setSingleLine", "(Z)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)tv, method, single ? JNI_TRUE : JNI_FALSE);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_textview_set_typeface(void *env_ptr, void *tv, int32_t style) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass text_cls = (*env)->GetObjectClass(env, (jobject)tv);
    jclass typeface_cls = (*env)->FindClass(env, "android/graphics/Typeface");
    jmethodID default_from_style = ap_get_static_method(env, typeface_cls, "defaultFromStyle", "(I)Landroid/graphics/Typeface;");
    jmethodID set_typeface = ap_get_method(env, text_cls, "setTypeface", "(Landroid/graphics/Typeface;)V");
    jobject typeface = default_from_style ? (*env)->CallStaticObjectMethod(env, typeface_cls, default_from_style, style) : NULL;
    if (set_typeface && typeface) {
        (*env)->CallVoidMethod(env, (jobject)tv, set_typeface, typeface);
    }
    if (typeface) {
        (*env)->DeleteLocalRef(env, typeface);
    }
    (*env)->DeleteLocalRef(env, typeface_cls);
    (*env)->DeleteLocalRef(env, text_cls);
}

void android_imageview_set_scale_type(void *env_ptr, void *iv, int32_t scale_type) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass image_cls = (*env)->GetObjectClass(env, (jobject)iv);
    jclass scale_cls = (*env)->FindClass(env, "android/widget/ImageView$ScaleType");
    const char *field_name = "FIT_CENTER";
    if (scale_type == 1) {
        field_name = "CENTER_CROP";
    } else if (scale_type == 2) {
        field_name = "FIT_XY";
    }
    jfieldID field = (*env)->GetStaticFieldID(env, scale_cls, field_name, "Landroid/widget/ImageView$ScaleType;");
    jmethodID method = ap_get_method(env, image_cls, "setScaleType", "(Landroid/widget/ImageView$ScaleType;)V");
    jobject value = field ? (*env)->GetStaticObjectField(env, scale_cls, field) : NULL;
    if (method && value) {
        (*env)->CallVoidMethod(env, (jobject)iv, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, scale_cls);
    (*env)->DeleteLocalRef(env, image_cls);
}

void android_imageview_set_image_resource(void *env_ptr, void *iv, int32_t res_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)iv);
    jmethodID method = ap_get_method(env, cls, "setImageResource", "(I)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)iv, method, res_id);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_imageview_set_image_named(void *env_ptr, void *iv, uint8_t *name) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject image_view = (jobject)iv;
    jclass view_cls = (*env)->GetObjectClass(env, image_view);
    jmethodID get_context = ap_get_method(env, view_cls, "getContext", "()Landroid/content/Context;");
    jobject context = get_context ? (*env)->CallObjectMethod(env, image_view, get_context) : NULL;
    if (!context) {
        (*env)->DeleteLocalRef(env, view_cls);
        return;
    }

    jclass context_cls = (*env)->GetObjectClass(env, context);
    jmethodID get_resources = ap_get_method(env, context_cls, "getResources", "()Landroid/content/res/Resources;");
    jmethodID get_package_name = ap_get_method(env, context_cls, "getPackageName", "()Ljava/lang/String;");
    jobject resources = get_resources ? (*env)->CallObjectMethod(env, context, get_resources) : NULL;
    jstring package_name = get_package_name ? (*env)->CallObjectMethod(env, context, get_package_name) : NULL;
    jclass resources_cls = resources ? (*env)->GetObjectClass(env, resources) : NULL;
    jmethodID get_identifier = resources_cls ? ap_get_method(env, resources_cls, "getIdentifier", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)I") : NULL;
    jstring image_name = ap_new_string(env, name, -1);
    jstring drawable_type = (*env)->NewStringUTF(env, "drawable");
    jint res_id = get_identifier ? (*env)->CallIntMethod(env, resources, get_identifier, image_name, drawable_type, package_name) : 0;

    if (res_id != 0) {
        android_imageview_set_image_resource(env_ptr, iv, res_id);
    }

    if (drawable_type) {
        (*env)->DeleteLocalRef(env, drawable_type);
    }
    if (image_name) {
        (*env)->DeleteLocalRef(env, image_name);
    }
    if (resources_cls) {
        (*env)->DeleteLocalRef(env, resources_cls);
    }
    if (resources) {
        (*env)->DeleteLocalRef(env, resources);
    }
    if (package_name) {
        (*env)->DeleteLocalRef(env, package_name);
    }
    (*env)->DeleteLocalRef(env, context_cls);
    (*env)->DeleteLocalRef(env, context);
    (*env)->DeleteLocalRef(env, view_cls);
}

void android_edittext_set_hint(void *env_ptr, void *et, uint8_t *hint, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)et);
    jmethodID method = ap_get_method(env, cls, "setHint", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, hint, byte_len);
    if (method && value) {
        (*env)->CallVoidMethod(env, (jobject)et, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_edittext_set_input_type(void *env_ptr, void *et, int32_t input_type) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)et);
    jmethodID method = ap_get_method(env, cls, "setInputType", "(I)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)et, method, input_type);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_edittext_set_text(void *env_ptr, void *et, uint8_t *text, int32_t byte_len) {
    android_textview_set_text(env_ptr, et, text, byte_len);
}

void *android_edittext_get_text(void *env_ptr, void *et) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)et);
    jmethodID get_text = ap_get_method(env, cls, "getText", "()Landroid/text/Editable;");
    jobject editable = get_text ? (*env)->CallObjectMethod(env, (jobject)et, get_text) : NULL;
    jstring result = NULL;
    if (editable) {
        jclass editable_cls = (*env)->GetObjectClass(env, editable);
        jmethodID to_string = ap_get_method(env, editable_cls, "toString", "()Ljava/lang/String;");
        result = to_string ? (*env)->CallObjectMethod(env, editable, to_string) : NULL;
        (*env)->DeleteLocalRef(env, editable_cls);
        (*env)->DeleteLocalRef(env, editable);
    }
    (*env)->DeleteLocalRef(env, cls);
    return result;
}

void android_webview_load_url(void *env_ptr, void *web, uint8_t *url, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)web);
    jmethodID load_url = ap_get_method(env, cls, "loadUrl", "(Ljava/lang/String;)V");
    jstring url_value = ap_new_string(env, url, byte_len);
    if (load_url && url_value) {
        (*env)->CallVoidMethod(env, (jobject)web, load_url, url_value);
    }
    if (url_value) {
        (*env)->DeleteLocalRef(env, url_value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_webview_load_html(void *env_ptr, void *web, uint8_t *html, int32_t html_len,
                               uint8_t *base_url, int32_t base_url_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass web_cls = (*env)->GetObjectClass(env, (jobject)web);
    jmethodID get_settings = ap_try_get_method(env, web_cls, "getSettings", "()Landroid/webkit/WebSettings;");
    jobject settings = get_settings ? (*env)->CallObjectMethod(env, (jobject)web, get_settings) : NULL;

    if (settings) {
        jclass settings_cls = (*env)->GetObjectClass(env, settings);
        jmethodID set_js_enabled = ap_try_get_method(env, settings_cls, "setJavaScriptEnabled", "(Z)V");
        if (set_js_enabled) {
            (*env)->CallVoidMethod(env, settings, set_js_enabled, JNI_TRUE);
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
    jstring mime_type = (*env)->NewStringUTF(env, "text/html");
    jstring encoding = (*env)->NewStringUTF(env, "utf-8");
    if (load_html && html_value && mime_type && encoding) {
        (*env)->CallVoidMethod(env, (jobject)web, load_html, base_value, html_value, mime_type, encoding, NULL);
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
    jclass cls = (*env)->GetObjectClass(env, (jobject)ll);
    jmethodID method = ap_get_method(env, cls, "setOrientation", "(I)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)ll, method, orientation);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_linearlayout_set_gravity(void *env_ptr, void *ll, int32_t gravity) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)ll);
    jmethodID method = ap_get_method(env, cls, "setGravity", "(I)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)ll, method, gravity);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_viewgroup_add_view(void *env_ptr, void *parent, void *child) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)parent);
    jmethodID method = ap_get_method(env, cls, "addView", "(Landroid/view/View;)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)parent, method, (jobject)child);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_viewgroup_add_view_wh(void *env_ptr, void *parent, void *child, int32_t width, int32_t height) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)parent);
    jmethodID method = ap_try_get_method(env, cls, "addView", "(Landroid/view/View;II)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)parent, method, (jobject)child, width, height);
    } else {
        android_viewgroup_add_view(env_ptr, parent, child);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_linearlayout_add_view_weight(void *env_ptr, void *parent, void *child,
                                          int32_t width, int32_t height, float weight) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass params_cls = (*env)->FindClass(env, "android/widget/LinearLayout$LayoutParams");
    jmethodID ctor = ap_get_method(env, params_cls, "<init>", "(IIF)V");
    jobject params = ctor ? (*env)->NewObject(env, params_cls, ctor, width, height, weight) : NULL;

    jclass parent_cls = (*env)->GetObjectClass(env, (jobject)parent);
    jmethodID add_view = ap_get_method(env, parent_cls, "addView", "(Landroid/view/View;Landroid/view/ViewGroup$LayoutParams;)V");
    if (add_view && params) {
        (*env)->CallVoidMethod(env, (jobject)parent, add_view, (jobject)child, params);
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
    jclass cls = (*env)->GetObjectClass(env, (jobject)parent);
    jmethodID method = ap_get_method(env, cls, "removeAllViews", "()V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)parent, method);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_visibility(void *env_ptr, void *v, int32_t visibility) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)v);
    jmethodID method = ap_get_method(env, cls, "setVisibility", "(I)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)v, method, visibility);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_alpha(void *env_ptr, void *v, float alpha) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)v);
    jmethodID method = ap_get_method(env, cls, "setAlpha", "(F)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)v, method, alpha);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_background_color(void *env_ptr, void *v, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject drawable = ap_ensure_gradient_background(env, (jobject)v);
    if (!drawable) {
        return;
    }

    jclass gradient_cls = (*env)->GetObjectClass(env, drawable);
    jmethodID method = ap_try_get_method(env, gradient_cls, "setColor", "(I)V");
    if (method) {
        (*env)->CallVoidMethod(env, drawable, method, argb);
    }
    (*env)->DeleteLocalRef(env, gradient_cls);
    (*env)->DeleteLocalRef(env, drawable);
}

void android_view_set_content_description(void *env_ptr, void *v, uint8_t *desc, int32_t byte_len) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)v);
    jmethodID method = ap_get_method(env, cls, "setContentDescription", "(Ljava/lang/CharSequence;)V");
    jstring value = ap_new_string(env, desc, byte_len);
    if (method && value) {
        (*env)->CallVoidMethod(env, (jobject)v, method, value);
    }
    if (value) {
        (*env)->DeleteLocalRef(env, value);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_clip_to_outline(void *env_ptr, void *v, int32_t clip) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)v);
    jmethodID method = ap_try_get_method(env, cls, "setClipToOutline", "(Z)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)v, method, clip ? JNI_TRUE : JNI_FALSE);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_elevation(void *env_ptr, void *v, float dp) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)v);
    jmethodID method = ap_try_get_method(env, cls, "setElevation", "(F)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)v, method, dp);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_padding(void *env_ptr, void *v, int32_t left, int32_t top, int32_t right, int32_t bottom) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)v);
    jmethodID method = ap_get_method(env, cls, "setPadding", "(IIII)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)v, method, left, top, right, bottom);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_view_set_corner_radius(void *env_ptr, void *v, float radius) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject drawable = ap_ensure_gradient_background(env, (jobject)v);
    if (!drawable) {
        return;
    }

    jclass gradient_cls = (*env)->GetObjectClass(env, drawable);
    jmethodID method = ap_try_get_method(env, gradient_cls, "setCornerRadius", "(F)V");
    if (method) {
        (*env)->CallVoidMethod(env, drawable, method, radius);
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

    jclass gradient_cls = (*env)->GetObjectClass(env, drawable);
    jmethodID method = ap_try_get_method(env, gradient_cls, "setStroke", "(II)V");
    if (method) {
        (*env)->CallVoidMethod(env, drawable, method, (jint)lroundf(width), argb);
    }
    (*env)->DeleteLocalRef(env, gradient_cls);
    (*env)->DeleteLocalRef(env, drawable);
}

void android_switch_set_checked(void *env_ptr, void *sw, int32_t checked) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)sw);
    jmethodID method = ap_get_method(env, cls, "setChecked", "(Z)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)sw, method, checked ? JNI_TRUE : JNI_FALSE);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_switch_set_thumb_tint(void *env_ptr, void *sw, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject tint = ap_make_color_state_list(env, argb);
    jclass cls = (*env)->GetObjectClass(env, (jobject)sw);
    jmethodID method = ap_try_get_method(env, cls, "setThumbTintList", "(Landroid/content/res/ColorStateList;)V");
    if (method && tint) {
        (*env)->CallVoidMethod(env, (jobject)sw, method, tint);
    }
    if (tint) {
        (*env)->DeleteLocalRef(env, tint);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_switch_set_track_tint(void *env_ptr, void *sw, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject tint = ap_make_color_state_list(env, argb);
    jclass cls = (*env)->GetObjectClass(env, (jobject)sw);
    jmethodID method = ap_try_get_method(env, cls, "setTrackTintList", "(Landroid/content/res/ColorStateList;)V");
    if (method && tint) {
        (*env)->CallVoidMethod(env, (jobject)sw, method, tint);
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
    jclass cls = (*env)->GetObjectClass(env, (jobject)cb);
    jmethodID method = ap_try_get_method(env, cls, "setButtonTintList", "(Landroid/content/res/ColorStateList;)V");
    if (method && tint) {
        (*env)->CallVoidMethod(env, (jobject)cb, method, tint);
    }
    if (tint) {
        (*env)->DeleteLocalRef(env, tint);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_radiogroup_check(void *env_ptr, void *rg, int32_t child_id) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)rg);
    jmethodID method = ap_get_method(env, cls, "check", "(I)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)rg, method, child_id);
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
    jclass cls = (*env)->FindClass(env, "android/view/View");
    jmethodID method = ap_get_static_method(env, cls, "generateViewId", "()I");
    jint result = method ? (*env)->CallStaticIntMethod(env, cls, method) : 0;
    (*env)->DeleteLocalRef(env, cls);
    return result;
}

void android_seekbar_set_max(void *env_ptr, void *sb, int32_t max) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)sb);
    jmethodID method = ap_get_method(env, cls, "setMax", "(I)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)sb, method, max);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_seekbar_set_progress(void *env_ptr, void *sb, int32_t progress) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)sb);
    jmethodID method = ap_get_method(env, cls, "setProgress", "(I)V");
    if (method) {
        (*env)->CallVoidMethod(env, (jobject)sb, method, progress);
    }
    (*env)->DeleteLocalRef(env, cls);
}

void android_seekbar_set_progress_tint(void *env_ptr, void *sb, int32_t argb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jobject tint = ap_make_color_state_list(env, argb);
    jclass cls = (*env)->GetObjectClass(env, (jobject)sb);
    jmethodID method = ap_try_get_method(env, cls, "setProgressTintList", "(Landroid/content/res/ColorStateList;)V");
    if (method && tint) {
        (*env)->CallVoidMethod(env, (jobject)sb, method, tint);
    }
    if (tint) {
        (*env)->DeleteLocalRef(env, tint);
    }
    (*env)->DeleteLocalRef(env, cls);
}

int32_t android_seekbar_get_progress(void *env_ptr, void *sb) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    jclass cls = (*env)->GetObjectClass(env, (jobject)sb);
    jmethodID method = ap_get_method(env, cls, "getProgress", "()I");
    jint result = method ? (*env)->CallIntMethod(env, (jobject)sb, method) : 0;
    (*env)->DeleteLocalRef(env, cls);
    return result;
}

void android_view_set_on_click_listener(void *env_ptr, void *v, uint64_t callback_id) {
    (void)env_ptr;
    (void)v;
    (void)callback_id;
}

void android_view_set_on_checked_change_listener(void *env_ptr, void *v, uint64_t callback_id) {
    (void)env_ptr;
    (void)v;
    (void)callback_id;
}

void android_seekbar_set_on_change_listener(void *env_ptr, void *sb, uint64_t callback_id) {
    (void)env_ptr;
    (void)sb;
    (void)callback_id;
}

void android_edittext_set_text_watcher(void *env_ptr, void *et, uint64_t callback_id) {
    (void)env_ptr;
    (void)et;
    (void)callback_id;
}

void android_radiogroup_set_on_checked_change_listener(void *env_ptr, void *rg, uint64_t callback_id) {
    (void)env_ptr;
    (void)rg;
    (void)callback_id;
}

void *android_new_global_ref(void *env_ptr, void *local_ref) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    return (*env)->NewGlobalRef(env, (jobject)local_ref);
}

void android_delete_global_ref(void *env_ptr, void *global_ref) {
    JNIEnv *env = (JNIEnv *)env_ptr;
    if (global_ref) {
        (*env)->DeleteGlobalRef(env, (jobject)global_ref);
    }
}
