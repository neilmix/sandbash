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
        "(allow process*)\n"
        "(allow sysctl-read)\n"
        "(allow mach-lookup)\n"
        "(allow ipc-posix-shm)\n"
        "(allow network*)\n"
        "(allow file-read*)\n"
        "(deny file-write*)\n");

    // Add write permissions for each path
    for (int i = 0; i < all_paths->count; i++) {
        offset += snprintf(profile + offset, buffer_size - offset,
            "(allow file-write* (subpath \"%s\"))\n",
            all_paths->paths[i]);

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
