#include "config.h"
#include "utils.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

PathList* pathlist_create(void) {
    PathList* list = malloc(sizeof(PathList));
    if (!list) {
        return NULL;
    }

    list->capacity = 16;
    list->count = 0;
    list->paths = calloc(list->capacity, sizeof(char*));

    if (!list->paths) {
        free(list);
        return NULL;
    }

    return list;
}

bool pathlist_add(PathList* list, const char* path) {
    if (!list || !path) {
        return false;
    }

    // Check for duplicates
    if (pathlist_contains(list, path)) {
        return true;
    }

    // Expand capacity if needed
    if (list->count >= list->capacity) {
        int new_capacity = list->capacity * 2;
        char** new_paths = realloc(list->paths, new_capacity * sizeof(char*));
        if (!new_paths) {
            return false;
        }
        list->paths = new_paths;
        list->capacity = new_capacity;
    }

    list->paths[list->count] = strdup(path);
    if (!list->paths[list->count]) {
        return false;
    }

    list->count++;
    return true;
}

bool pathlist_contains(PathList* list, const char* path) {
    if (!list || !path) {
        return false;
    }

    for (int i = 0; i < list->count; i++) {
        if (strcmp(list->paths[i], path) == 0) {
            return true;
        }
    }

    return false;
}

bool pathlist_remove(PathList* list, const char* path) {
    if (!list || !path) {
        return false;
    }

    for (int i = 0; i < list->count; i++) {
        if (strcmp(list->paths[i], path) == 0) {
            free(list->paths[i]);
            // Shift remaining elements
            for (int j = i; j < list->count - 1; j++) {
                list->paths[j] = list->paths[j + 1];
            }
            list->count--;
            return true;
        }
    }

    return false;
}

void pathlist_free(PathList* list) {
    if (!list) {
        return;
    }

    for (int i = 0; i < list->count; i++) {
        free(list->paths[i]);
    }
    free(list->paths);
    free(list);
}

#include <unistd.h>
#include <limits.h>

Config* config_create(void) {
    Config* config = malloc(sizeof(Config));
    if (!config) {
        return NULL;
    }

    config->global_paths = pathlist_create();
    config->local_paths = pathlist_create();
    config->cli_paths = pathlist_create();

    if (!config->global_paths || !config->local_paths || !config->cli_paths) {
        config_free(config);
        return NULL;
    }

    // Store current directory
    char cwd[PATH_MAX];
    if (!getcwd(cwd, sizeof(cwd))) {
        config_free(config);
        return NULL;
    }
    config->current_dir = strdup(cwd);

    return config;
}

void config_free(Config* config) {
    if (!config) {
        return;
    }

    pathlist_free(config->global_paths);
    pathlist_free(config->local_paths);
    pathlist_free(config->cli_paths);
    free(config->current_dir);
    free(config);
}

PathList* config_get_all_paths(Config* config) {
    if (!config) {
        return NULL;
    }

    PathList* all = pathlist_create();
    if (!all) {
        return NULL;
    }

    // Add current directory first
    pathlist_add(all, config->current_dir);

    // Merge global paths
    for (int i = 0; i < config->global_paths->count; i++) {
        pathlist_add(all, config->global_paths->paths[i]);
    }

    // Merge local paths
    for (int i = 0; i < config->local_paths->count; i++) {
        pathlist_add(all, config->local_paths->paths[i]);
    }

    // Merge CLI paths
    for (int i = 0; i < config->cli_paths->count; i++) {
        pathlist_add(all, config->cli_paths->paths[i]);
    }

    return all;
}
