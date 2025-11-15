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
    offset += snprintf(profile + offset, buffer_size - offset,
        "(version 1)\n"
        "(deny default)\n"
        "\n"
        ";; Process execution - allow executing system binaries\n"
        "(allow process-exec* (subpath \"/bin\"))\n"
        "(allow process-exec* (subpath \"/usr\"))\n"
        "(allow process-exec* (subpath \"/sbin\"))\n"
        "(allow process-exec* (subpath \"/System\"))\n"
        "(allow process-exec* (subpath \"/Library\"))\n"
        "(allow process-exec-interpreter (subpath \"/bin\"))\n"
        "(allow process-exec-interpreter (subpath \"/usr\"))\n"
        "(allow process-exec-interpreter (subpath \"/sbin\"))\n"
        "(allow process-fork)\n"
        "\n"
        ";; Process inspection (required for ps, top, etc.)\n"
        "(allow process-info-pidinfo)\n"
        "(allow process-info-pidfdinfo)\n"
        "(allow process-info-pidfileportinfo)\n"
        "(allow process-info-setcontrol)\n"
        "(allow process-info-dirtycontrol)\n"
        "(allow process-info-rusage)\n"
        "(allow process-info-ledger)\n"
        "(allow process-info-listpids)\n"
        "(allow process-info-codesignature)\n"
        "\n"
        ";; System information (required for ps, top, system commands)\n"
        "(allow sysctl-read)\n"
        "\n"
        ";; IPC and Mach operations\n"
        "(allow mach-lookup)\n"
        "(allow mach-task-name)\n"
        "(allow mach-task-read)\n"
        "(allow ipc-posix-shm)\n"
        "(allow signal (target self))\n"
        "\n"
        ";; Network access\n"
        "(allow network*)\n"
        "\n"
        ";; File operations\n"
        "(allow file-read*)\n"
        "(allow file-read-metadata)\n"
        "(allow file-ioctl)\n"
        "(deny file-write*)\n");

    // Add write permissions for each path
    for (int i = 0; i < all_paths->count; i++) {
        char* escaped = escape_sandbox_string(all_paths->paths[i]);
        if (!escaped) {
            free(profile);
            pathlist_free(all_paths);
            return NULL;
        }

        offset += snprintf(profile + offset, buffer_size - offset,
            "(allow file-write* (subpath \"%s\"))\n",
            escaped);
        free(escaped);

        if (offset >= buffer_size - 512) {
            // Need more space
            buffer_size *= 2;
            char* new_profile = realloc(profile, buffer_size);
            if (!new_profile) {
                free(profile);
                pathlist_free(all_paths);
                return NULL;
            }
            profile = new_profile;
        }
    }

    pathlist_free(all_paths);
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
