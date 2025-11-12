#include "utils.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <pwd.h>
#include <sys/types.h>
#include <CommonCrypto/CommonDigest.h>

bool is_under_home_directory(void) {
    char cwd[PATH_MAX];
    const char* home = getenv("HOME");

    if (!home) {
        return false;
    }

    if (!getcwd(cwd, sizeof(cwd))) {
        return false;
    }

    size_t home_len = strlen(home);

    // Check if cwd starts with home path
    return strncmp(cwd, home, home_len) == 0 &&
           (cwd[home_len] == '/' || cwd[home_len] == '\0');
}

char* expand_path(const char* path) {
    if (!path) {
        return NULL;
    }

    char expanded[PATH_MAX];

    // Handle tilde expansion (only ~ for current user, not ~username)
    if (path[0] == '~' && (path[1] == '/' || path[1] == '\0')) {
        const char* home = getenv("HOME");
        if (!home) {
            struct passwd* pw = getpwuid(getuid());
            home = pw ? pw->pw_dir : NULL;
        }
        if (!home) {
            return NULL;
        }
        snprintf(expanded, sizeof(expanded), "%s%s", home, path + 1);
    } else if (path[0] == '~') {
        // ~username syntax not supported
        return NULL;
    } else {
        strncpy(expanded, path, sizeof(expanded) - 1);
        expanded[sizeof(expanded) - 1] = '\0';
    }

    // Resolve to absolute path
    char* absolute = realpath(expanded, NULL);
    return absolute;
}

char* compute_path_hash(const char* path) {
    if (!path) {
        return NULL;
    }

    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(path, strlen(path), hash);

    // Convert first 8 bytes to hex (16 chars)
    char* hex = malloc(17);
    if (!hex) {
        return NULL;
    }

    for (int i = 0; i < 8; i++) {
        sprintf(hex + (i * 2), "%02x", hash[i]);
    }
    hex[16] = '\0';

    return hex;
}

char* get_xdg_config_dir(void) {
    const char* xdg = getenv("XDG_CONFIG_HOME");
    if (xdg && xdg[0] == '/') {
        return strdup(xdg);
    }

    const char* home = getenv("HOME");
    if (!home) {
        return NULL;
    }

    char path[PATH_MAX];
    snprintf(path, sizeof(path), "%s/.config", home);
    return strdup(path);
}

void free_string(char* str) {
    free(str);
}
