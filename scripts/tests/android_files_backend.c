/* Host POSIX contract for the exact Android C backend. This supplements, never
 * substitutes for, the real Android tests. Particularly, some Android app
 * domains deny creating hard links before a backend can inspect one.
 */
#define AP_FILES_HOST_TEST
#include "../../src/ui/native/android_private_files.c"
#include <assert.h>
#include <sys/wait.h>

static void expect(const char *root, const char *path, int operation, int expected) {
    char mutable_path[AP_FILE_MAX_PATH + 1];
    strcpy(mutable_path, path);
    unsigned char data[] = {0, 255, 128, 1}, *result = NULL;
    size_t size = 0;
    assert(ap_file_execute(root, "contract", mutable_path, operation, data, sizeof(data), &result, &size) == expected);
    if (expected == AP_FILE_OK && operation == 1) assert(size == sizeof(data) && !memcmp(result, data, size));
    free(result);
}

int main(int argc, char **argv) {
    assert(argc == 2 && argv[1][0] == '/');
    const char *root = argv[1];
    char original[4096], alias[4096], fifo[4096];
    assert(snprintf(original, sizeof(original), "%s/contract/original", root) < (int)sizeof(original));
    assert(snprintf(alias, sizeof(alias), "%s/contract/alias", root) < (int)sizeof(alias));
    assert(snprintf(fifo, sizeof(fifo), "%s/contract/fifo", root) < (int)sizeof(fifo));
    expect(root, "original", 2, AP_FILE_OK);
    expect(root, "original", 1, AP_FILE_OK);
    assert(link(original, alias) == 0);
    for (int operation = 1; operation <= 3; ++operation) expect(root, "alias", operation, AP_FILE_INVALID);
    assert(unlink(alias) == 0);
    expect(root, "original", 1, AP_FILE_OK);
    assert(symlink(original, alias) == 0);
    for (int operation = 1; operation <= 3; ++operation) expect(root, "alias", operation, AP_FILE_INVALID);
    assert(unlink(alias) == 0);
    assert(mkfifo(fifo, 0600) == 0);
    for (int operation = 1; operation <= 3; ++operation) expect(root, "fifo", operation, AP_FILE_INVALID);
    assert(unlink(fifo) == 0);
    expect(root, "original", 1, AP_FILE_OK);
    expect(root, "nested/file", 2, AP_FILE_OK);
    expect(root, "nested/file", 1, AP_FILE_OK);
    expect(root, "nested/file", 3, AP_FILE_OK);
    expect(root, "nested/file", 1, AP_FILE_IO);
    const char *invalid[] = {"", "../escape", "a//b", "/file", ".ap-lock", "a/../b", "a\\b"};
    for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) assert(!ap_file_path_valid(invalid[i], strlen(invalid[i])));
    char lock_path[4096];
    assert(snprintf(lock_path, sizeof(lock_path), "%s/contract/.ap-lock", root) < (int)sizeof(lock_path));
    int held = open(lock_path, O_RDWR);
    assert(held >= 0 && flock(held, LOCK_EX) == 0);
    pid_t child = fork();
    assert(child >= 0);
    if (child == 0) {
        close(held);
        alarm(10); /* An indefinitely blocking implementation must fail. */
        expect(root, "original", 1, AP_FILE_IO);
        _exit(0);
    }
    int child_status = 0;
    assert(waitpid(child, &child_status, 0) == child);
    assert(WIFEXITED(child_status) && WEXITSTATUS(child_status) == 0);
    close(held);
    expect(root, "original", 1, AP_FILE_OK);
    puts("PASS: exact C file backend binary IO, hard-link/symlink/FIFO rejection, bounded cross-process locking and path policy (host POSIX)");
    return 0;
}
