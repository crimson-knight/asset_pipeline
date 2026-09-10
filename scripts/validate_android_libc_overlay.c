#include <dirent.h>
#include <pthread.h>
#include <signal.h>
#include <stdarg.h>
#include <stddef.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <time.h>

/* Keep the generated Crystal x86_64 Android overlay honest against bionic. */
_Static_assert(sizeof(pthread_attr_t) == 56, "pthread_attr_t size changed");
_Static_assert(sizeof(pthread_cond_t) == 48, "pthread_cond_t size changed");
_Static_assert(sizeof(pthread_mutex_t) == 40, "pthread_mutex_t size changed");
_Static_assert(sizeof(sigset_t) == 8, "sigset_t size changed");
_Static_assert(sizeof(struct sigaction) == 32, "sigaction size changed");
_Static_assert(offsetof(struct sigaction, sa_flags) == 0, "sigaction flags offset changed");
_Static_assert(offsetof(struct sigaction, sa_mask) == 16, "sigaction mask offset changed");
_Static_assert(sizeof(stack_t) == 24, "stack_t size changed");
_Static_assert(sizeof(struct dirent) == 280, "dirent size changed");
_Static_assert(sizeof(struct stat) == 144, "stat size changed");
_Static_assert(offsetof(struct stat, st_nlink) == 16, "stat nlink offset changed");
_Static_assert(offsetof(struct stat, st_rdev) == 40, "stat rdev offset changed");
_Static_assert(offsetof(struct stat, st_atim) == 72, "stat atim offset changed");
_Static_assert(sizeof(struct timespec) == 16, "timespec size changed");
_Static_assert(sizeof(va_list) == 24, "x86_64 va_list size changed");
_Static_assert(SYS_getrandom == 318, "x86_64 getrandom syscall changed");

int asset_pipeline_android_libc_overlay_probe(void) {
    return 0;
}
