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

    // Estimate buffer size
    size_t buffer_size = 4096 + (all_paths->count * 512);
    char* profile = malloc(buffer_size);
    if (!profile) {
        pathlist_free(all_paths);
        return NULL;
    }

    // Build profile
    int offset = 0;

    offset += snprintf(profile + offset, buffer_size - offset,
        "(version 1)\n"
        "(deny default)\n"
        "\n"
        "; Allow basic process operations\n"
        "(allow process*)\n"
        "(allow sysctl-read)\n"
        "(allow mach-lookup)\n"
        "(allow ipc-posix-shm)\n"
        "\n"
        "; Allow network access (unrestricted)\n"
        "(allow network*)\n"
        "\n"
        "; Allow reading entire filesystem\n"
        "(allow file-read*)\n"
        "\n"
        "; Deny all write operations by default\n"
        "(deny file-write*)\n"
        "\n"
        "; Allow writes to configured paths\n");

    for (int i = 0; i < all_paths->count; i++) {
        offset += snprintf(profile + offset, buffer_size - offset,
            "(allow file-write* (subpath \"%s\"))\n",
            all_paths->paths[i]);
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
