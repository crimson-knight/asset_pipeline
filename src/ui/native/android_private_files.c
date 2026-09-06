/* JVM-worker-only file IO. Never enters Crystal or retains a JNI reference.
 * Every untrusted path component is opened relative to an owned directory fd;
 * no symlink is followed. The reserved namespace lock serializes cooperating
 * writers across processes. Writes commit via same-directory atomic rename.
 */
#ifndef AP_FILES_HOST_TEST
#include <jni.h>
#endif
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

enum { AP_FILE_OK = 0, AP_FILE_PERMISSION = 3, AP_FILE_INVALID = 5, AP_FILE_IO = 6 };
#define AP_FILE_MAX_DATA 1048576
#define AP_FILE_MAX_PATH 1024
#define AP_FILE_PENDING ".ap-pending"

static int ap_file_error(void) {
    if (errno == EACCES || errno == EPERM) return AP_FILE_PERMISSION;
    if (errno == ELOOP || errno == ENOTDIR || errno == ENAMETOOLONG) return AP_FILE_INVALID;
    return AP_FILE_IO;
}

static int ap_file_regular(const struct stat *info) {
    return S_ISREG(info->st_mode) && info->st_nlink == 1;
}

static int ap_file_lock(int fd) {
    struct timespec start, now, pause = {0, 20000000};
    if (clock_gettime(CLOCK_MONOTONIC, &start) < 0) return -1;
    for (;;) {
        if (flock(fd, LOCK_EX | LOCK_NB) == 0) return 0;
        if (errno != EWOULDBLOCK && errno != EAGAIN && errno != EINTR) return -1;
        if (clock_gettime(CLOCK_MONOTONIC, &now) < 0) return -1;
        if ((now.tv_sec - start.tv_sec) * 1000000000LL + now.tv_nsec - start.tv_nsec >= 5000000000LL) { errno = ETIMEDOUT; return -1; }
        nanosleep(&pause, NULL);
    }
}

/* Reject traversal, URI/drive paths, control bytes and reserved internal names.
 * Kotlin additionally checks strict UTF-8 before calling this boundary.
 */
static int ap_file_path_valid(const char *path, size_t size) {
    if (!size || size > AP_FILE_MAX_PATH || path[0] == '/' || path[size - 1] == '/') return 0;
    size_t start = 0, count = 0;
    for (size_t i = 0; i <= size; ++i) {
        if (i < size && ((unsigned char)path[i] < 32 || path[i] == 127 || path[i] == '\\' || path[i] == ':')) return 0;
        if (i == size || path[i] == '/') {
            size_t length = i - start;
            if (!length || length > 255 || ++count > 32 ||
                (length == 1 && path[start] == '.') ||
                (length == 2 && path[start] == '.' && path[start + 1] == '.') ||
                (length >= 4 && !memcmp(path + start, ".ap-", 4))) return 0;
            start = i + 1;
        }
    }
    return 1;
}

static int ap_file_directory(int parent, const char *name, int create) {
    int fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0 && errno == ENOENT && create) {
        if (mkdirat(parent, name, 0700) < 0 && errno != EEXIST) return -1;
        if (fsync(parent) < 0) return -1;
        fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    }
    return fd;
}

static int ap_file_execute(const char *root, const char *space, char *path, int operation,
                           const unsigned char *input, size_t input_size,
                           unsigned char **output, size_t *output_size) {
    int root_fd = -1, directory = -1, lock = -1, file = -1, pending_owned = 0;
    int status = AP_FILE_IO;
    struct stat info;
    *output = NULL; *output_size = 0;
    root_fd = open(root, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (root_fd < 0) { status = ap_file_error(); goto done; }
    directory = ap_file_directory(root_fd, space, operation == 2);
    if (directory < 0) { status = operation == 3 && errno == ENOENT ? AP_FILE_OK : ap_file_error(); goto done; }
    lock = openat(directory, ".ap-lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0600);
    if (lock < 0) { status = ap_file_error(); goto done; }
    if (fstat(lock, &info) < 0) goto done;
    if (!ap_file_regular(&info)) { status = AP_FILE_INVALID; goto done; }
    if (ap_file_lock(lock) < 0) goto done;

    char *leaf = path, *slash;
    while ((slash = strchr(leaf, '/')) != NULL) {
        *slash = '\0';
        int next = ap_file_directory(directory, leaf, operation == 2);
        if (next < 0) { status = operation == 3 && errno == ENOENT ? AP_FILE_OK : ap_file_error(); goto done; }
        close(directory); directory = next; leaf = slash + 1;
    }
    if (fstatat(directory, leaf, &info, AT_SYMLINK_NOFOLLOW) == 0) {
        if (!ap_file_regular(&info)) { status = AP_FILE_INVALID; goto done; }
    } else if (errno != ENOENT) { status = ap_file_error(); goto done; }

    if (operation == 1) {
        file = openat(directory, leaf, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
        if (file < 0) { status = ap_file_error(); goto done; }
        if (fstat(file, &info) < 0) goto done;
        if (!ap_file_regular(&info) || info.st_size < 0 || info.st_size > AP_FILE_MAX_DATA) { status = AP_FILE_INVALID; goto done; }
        *output = malloc(AP_FILE_MAX_DATA + 1);
        if (!*output) goto done;
        for (;;) {
            ssize_t size = read(file, *output + *output_size, AP_FILE_MAX_DATA + 1 - *output_size);
            if (size < 0) { if (errno == EINTR) continue; status = ap_file_error(); goto done; }
            if (!size) break;
            *output_size += (size_t)size;
            if (*output_size > AP_FILE_MAX_DATA) { status = AP_FILE_INVALID; goto done; }
        }
        status = AP_FILE_OK;
    } else if (operation == 3) {
        if (unlinkat(directory, leaf, 0) < 0) { status = errno == ENOENT ? AP_FILE_OK : ap_file_error(); goto done; }
        status = fsync(directory) == 0 ? AP_FILE_OK : AP_FILE_IO;
    } else {
        /* A leftover private temporary file is an uncommitted prior write.
         * Reads ignore it. Only a regular, unaliased temporary file is removed.
         */
        if (fstatat(directory, AP_FILE_PENDING, &info, AT_SYMLINK_NOFOLLOW) == 0) {
            if (!ap_file_regular(&info)) { status = AP_FILE_INVALID; goto done; }
            if (unlinkat(directory, AP_FILE_PENDING, 0) < 0) goto done;
        } else if (errno != ENOENT) { status = ap_file_error(); goto done; }
        file = openat(directory, AP_FILE_PENDING, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
        if (file < 0) { status = ap_file_error(); goto done; }
        pending_owned = 1;
        size_t written = 0;
        while (written < input_size) {
            ssize_t size = write(file, input + written, input_size - written);
            if (size < 0) { if (errno == EINTR) continue; status = ap_file_error(); goto done; }
            if (!size) goto done;
            written += (size_t)size;
        }
        if (fsync(file) < 0) goto done;
        int closed = close(file); file = -1;
        if (closed < 0) goto done;
        if (renameat(directory, AP_FILE_PENDING, directory, leaf) < 0) { status = ap_file_error(); goto done; }
        pending_owned = 0;
        status = fsync(directory) == 0 ? AP_FILE_OK : AP_FILE_IO;
    }
done:
    if (file >= 0) close(file);
    if (pending_owned && directory >= 0) unlinkat(directory, AP_FILE_PENDING, 0);
    if (directory >= 0) close(directory);
    if (lock >= 0) close(lock);
    if (root_fd >= 0) close(root_fd);
    if (status != AP_FILE_OK) { free(*output); *output = NULL; *output_size = 0; }
    return status;
}

#ifndef AP_FILES_HOST_TEST
JNIEXPORT jbyteArray JNICALL
Java_dev_assetpipeline_androidhost_PrivateFiles_executeNative(JNIEnv *env, jclass klass,
    jbyteArray root_array, jbyteArray space_array, jbyteArray path_array, jbyteArray data_array, jint operation) {
    (void)klass;
    int status = AP_FILE_INVALID;
    unsigned char *input = NULL, *output = NULL;
    size_t output_size = 0;
    char root[4097], space[65], path[AP_FILE_MAX_PATH + 1];
    if (!root_array || !space_array || !path_array || !data_array) goto reply;
    jsize root_size = (*env)->GetArrayLength(env, root_array);
    jsize space_size = (*env)->GetArrayLength(env, space_array);
    jsize path_size = (*env)->GetArrayLength(env, path_array);
    jsize data_size = (*env)->GetArrayLength(env, data_array);
    if (root_size < 1 || root_size > 4096 || space_size < 1 || space_size > 64 ||
        path_size < 1 || path_size > AP_FILE_MAX_PATH || data_size > AP_FILE_MAX_DATA || operation < 1 || operation > 3) goto reply;
    (*env)->GetByteArrayRegion(env, root_array, 0, root_size, (jbyte *)root);
    (*env)->GetByteArrayRegion(env, space_array, 0, space_size, (jbyte *)space);
    (*env)->GetByteArrayRegion(env, path_array, 0, path_size, (jbyte *)path);
    if ((*env)->ExceptionCheck(env)) return NULL;
    if (root[0] != '/' || memchr(root, 0, root_size) || !ap_file_path_valid(path, path_size)) goto reply;
    for (jsize i = 0; i < space_size; ++i) {
        char c = space[i];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-')) goto reply;
    }
    root[root_size] = 0; space[space_size] = 0; path[path_size] = 0;
    input = malloc(data_size ? (size_t)data_size : 1);
    if (!input) { status = AP_FILE_IO; goto reply; }
    if (data_size) (*env)->GetByteArrayRegion(env, data_array, 0, data_size, (jbyte *)input);
    if ((*env)->ExceptionCheck(env)) { free(input); return NULL; }
    status = ap_file_execute(root, space, path, operation, input, (size_t)data_size, &output, &output_size);
reply:;
    jbyteArray result = (*env)->NewByteArray(env, (jsize)output_size + 1);
    if (result) {
        jbyte code = (jbyte)status;
        (*env)->SetByteArrayRegion(env, result, 0, 1, &code);
        if (output_size) (*env)->SetByteArrayRegion(env, result, 1, (jsize)output_size, (const jbyte *)output);
    }
    free(input); free(output);
    return result;
}
#endif
