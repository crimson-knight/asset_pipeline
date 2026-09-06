#define GC_THREADS 1
#include <gc/gc.h>
#include <stdint.h>
#include <pthread.h>
#include <stdatomic.h>
#include <android/log.h>

extern int crystal_android_initialize_runtime(int argc, char **argv);

void crystal_android_log_runtime_error(const unsigned char *message) {
    __android_log_print(ANDROID_LOG_ERROR, "AssetPipelineNative",
                       "Crystal bootstrap error: %s", message);
}

static pthread_once_t ap_runtime_once = PTHREAD_ONCE_INIT;
static _Atomic int ap_runtime_ready = 0;
static _Atomic int ap_runtime_initializations = 0;
static char ap_program_name[] = "asset_pipeline_android";
static char *ap_program_argv[] = {ap_program_name, NULL};

static void ap_initialize_runtime_once(void) {
    if (crystal_android_initialize_runtime(1, ap_program_argv) != 0) {
        return;
    }
    GC_allow_register_threads();
    atomic_fetch_add_explicit(&ap_runtime_initializations, 1, memory_order_relaxed);
    atomic_store_explicit(&ap_runtime_ready, 1, memory_order_release);
}

/* First call belongs to the Android main thread. Subsequent calls may race,
 * but never reset Crystal's thread/fiber registries or scheduler. */
void crystal_init(void) {
    pthread_once(&ap_runtime_once, ap_initialize_runtime_once);
}

int32_t crystal_runtime_is_ready(void) {
    return atomic_load_explicit(&ap_runtime_ready, memory_order_acquire);
}

int32_t crystal_runtime_initialization_count(void) {
    return atomic_load_explicit(&ap_runtime_initializations, memory_order_relaxed);
}

/*
 * Boehm must see a JVM-created thread before that thread enters Crystal.
 * These functions deliberately live in C: calling a Crystal wrapper in order
 * to register an unregistered stack would already be too late.
 *
 * Return values from crystal_gc_register_thread:
 *   1  this helper registered the current thread
 *   0  the current thread was already registered
 *  <0  registration failed (the absolute value is a Boehm status code)
 */
static _Thread_local int ap_gc_registered_here = 0;

void crystal_gc_allow_thread_registration(void) {
    GC_allow_register_threads();
}

int32_t crystal_gc_register_thread(void) {
    struct GC_stack_base stack_base;
    int status;

    if (!crystal_runtime_is_ready()) {
        return -100;
    }
    if (GC_thread_is_registered()) {
        return 0;
    }

    status = GC_get_stack_base(&stack_base);
    if (status != GC_SUCCESS) {
        return -status;
    }

    status = GC_register_my_thread(&stack_base);
    if (status == GC_DUPLICATE) {
        return 0;
    }
    if (status != GC_SUCCESS) {
        return -status;
    }

    ap_gc_registered_here = 1;
    return 1;
}

int32_t crystal_gc_unregister_thread(void) {
    int status;

    if (!ap_gc_registered_here) {
        return 0;
    }

    status = GC_unregister_my_thread();
    if (status == GC_SUCCESS) {
        ap_gc_registered_here = 0;
        return 0;
    }
    return -status;
}
