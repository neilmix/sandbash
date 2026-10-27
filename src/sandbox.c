/*
 * Note: macOS sandbox_init_with_parameters is a private API.
 * For production use, this tool may need to be signed with proper
 * entitlements or use alternative sandboxing approaches.
 *
 * Alternative: Use sandbox_init(kSBXProfileNoWrite, SANDBOX_NAMED, &error)
 * and manage write permissions differently.
 */

#include "sandbox.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <sandbox.h>

char* escape_sandbox_string(const char* str) {
    if (!str) {
        return NULL;
    }

    // Count characters that need escaping (quotes and backslashes)
    size_t extra = 0;
    for (const char* p = str; *p; p++) {
        if (*p == '"' || *p == '\\') {
            extra++;
        }
    }

    // Allocate new string with space for escape characters
    char* escaped = malloc(strlen(str) + extra + 1);
    if (!escaped) {
        return NULL;
    }

    // Copy string, inserting backslashes before quotes and backslashes
    char* out = escaped;
    for (const char* p = str; *p; p++) {
        if (*p == '"' || *p == '\\') {
            *out++ = '\\';
        }
        *out++ = *p;
    }
    *out = '\0';

    return escaped;
}

// Append a rule whose single %s is filled with the escaped path, growing the
// buffer as needed. On failure the buffer is freed and false is returned.
static bool append_path_rule(char** profile, size_t* buffer_size,
                             size_t* offset, const char* format,
                             const char* path) {
    char* escaped = escape_sandbox_string(path);
    if (!escaped) {
        free(*profile);
        return false;
    }

    for (;;) {
        int n = snprintf(*profile + *offset, *buffer_size - *offset,
                         format, escaped);
        if (n < 0) {
            free(escaped);
            free(*profile);
            return false;
        }
        if ((size_t)n < *buffer_size - *offset) {
            *offset += n;
            free(escaped);
            return true;
        }

        size_t new_size = *buffer_size * 2;
        char* new_profile = realloc(*profile, new_size);
        if (!new_profile) {
            free(escaped);
            free(*profile);
            return false;
        }
        *profile = new_profile;
        *buffer_size = new_size;
    }
}

char* sandbox_generate_profile(Config* config) {
    if (!config) {
        return NULL;
    }

    PathList* all_paths = config_get_all_paths(config);
    if (!all_paths) {
        return NULL;
    }

    // Build profile string
    size_t buffer_size = 8192;
    char* profile = malloc(buffer_size);
    if (!profile) {
        pathlist_free(all_paths);
        return NULL;
    }

    size_t offset = 0;

    // Profile header
    //
    // signal is scoped to same-sandbox: processes started inside the sandbox
    // can signal each other (killing dev servers, test runners), but cannot
    // reach the user's editor, shell, or other sandbash sessions.
    //
    // ipc-sysv-shm and ipc-sysv-sem cover SysV shared memory and semaphores,
    // both of which Postgres needs. Note that the create path (shmget/semget)
    // has no MAC hook, so omitting these rules does not deny SysV IPC
    // outright -- it permits creating objects while denying IPC_RMID, leaking
    // them. For shm that fills the tiny system-wide table
    // (kern.sysv.shmmni = 32); for semaphores kern.sysv.semmni is large
    // enough that leaks accumulate without a hard cliff.
    //
    // ipc-sysv-msg (message queues) is deliberately NOT allowed: no known
    // workload needs it, and unlike semaphores it carries a data payload.
    // Hence two explicit rules rather than the ipc-sysv* wildcard.
    //
    // process-exec* of a setuid/setgid binary is denied to sandboxed
    // processes by macOS unless the rule carries (with no-sandbox), which
    // runs the child UNCONFINED. /bin/ps is setuid-root and this is the only
    // way to exec it. The exception is deliberately scoped to the exact
    // literal path: /bin/ps is read-only and spawns nothing, so an
    // unconfined ps cannot write files or leak confinement to descendants.
    // Do NOT broaden this to a subpath, a name, or other setuid tools
    // (top, sudo, crontab, ...) -- that would turn write-confinement into a
    // general sandbox-escape primitive.
    offset += snprintf(profile + offset, buffer_size - offset,
        "(version 1)\n"
        "(deny default)\n"
        "(allow process*)\n"
        "(allow process-exec* (with no-sandbox) (literal \"/bin/ps\"))\n"
        "(allow sysctl*)\n"
        "(allow mach-lookup)\n"
        "(allow mach-register)\n"
        "(allow iokit-open)\n"
        "(allow ipc-posix-shm)\n"
        "(allow ipc-sysv-shm)\n"
        "(allow ipc-sysv-sem)\n"
        "(allow file-ioctl)\n"
        "(allow signal (target same-sandbox))\n"
        "(allow network*)\n"
        "(allow file-read*)\n"
        "(allow file-read-metadata)\n"
        "(allow file-map-executable)\n"
        "(deny file-write*)\n");

    // Add write permissions for each path
    for (int i = 0; i < all_paths->count; i++) {
        if (!append_path_rule(&profile, &buffer_size, &offset,
                              "(allow file-write* (subpath \"%s\"))\n",
                              all_paths->paths[i])) {
            pathlist_free(all_paths);
            return NULL;
        }
    }

    pathlist_free(all_paths);

    // Denied paths come after the write allowances: when rules conflict the
    // last match wins, so a deny overrides a broader writable ancestor
    // (e.g. a denied directory inside the always-writable current dir).
    //
    // A path-based deny is bypassed by renaming any ancestor -- after
    // `mv parent other`, the content lives at a path no rule matches. So
    // every ancestor of a denied path also gets file-write-unlink denied as
    // a literal: the ancestor itself cannot be renamed or removed, while
    // everything else inside it stays writable.
    PathList* deny_paths = config_get_deny_paths(config);
    PathList* ancestors = pathlist_create();
    if (!deny_paths || !ancestors) {
        pathlist_free(deny_paths);
        pathlist_free(ancestors);
        free(profile);
        return NULL;
    }

    for (int i = 0; i < deny_paths->count; i++) {
        const char* path = deny_paths->paths[i];
        if (!append_path_rule(&profile, &buffer_size, &offset,
                              "(deny file-read* file-write* (subpath \"%s\"))\n",
                              path)) {
            pathlist_free(deny_paths);
            pathlist_free(ancestors);
            return NULL;
        }

        char ancestor[PATH_MAX];
        snprintf(ancestor, sizeof(ancestor), "%s", path);
        char* slash;
        while ((slash = strrchr(ancestor, '/')) && slash != ancestor) {
            *slash = '\0';
            pathlist_add(ancestors, ancestor);
        }
    }

    for (int i = 0; i < ancestors->count; i++) {
        if (!append_path_rule(&profile, &buffer_size, &offset,
                              "(deny file-write-unlink (literal \"%s\"))\n",
                              ancestors->paths[i])) {
            pathlist_free(deny_paths);
            pathlist_free(ancestors);
            return NULL;
        }
    }

    pathlist_free(deny_paths);
    pathlist_free(ancestors);
    return profile;
}

// Private API declaration (may require code signing)
extern int sandbox_init_with_parameters(const char *profile, uint64_t flags,
                                       const char *const parameters[],
                                       char **errorbuf);

bool sandbox_init_with_profile(const char* profile) {
    if (!profile) {
        return false;
    }

    char* error = NULL;
    int result = sandbox_init_with_parameters(profile, 0, NULL, &error);

    if (result != 0) {
        if (error) {
            fprintf(stderr, "Error: Failed to initialize sandbox: %s\n", error);
            free(error);
        } else {
            fprintf(stderr, "Error: Failed to initialize sandbox\n");
        }
        return false;
    }

    return true;
}
