#ifndef CONFIG_H
#define CONFIG_H

#include <stdbool.h>

#define MAX_PATHS 256
#define MAX_PATH_LENGTH 4096

typedef struct {
    char** paths;
    int count;
    int capacity;
} PathList;

typedef struct {
    PathList* global_paths;
    PathList* local_paths;
    PathList* cli_paths;
    char* current_dir;
} Config;

// Create new PathList
PathList* pathlist_create(void);

// Add path to PathList
bool pathlist_add(PathList* list, const char* path);

// Check if path exists in PathList
bool pathlist_contains(PathList* list, const char* path);

// Remove path from PathList
bool pathlist_remove(PathList* list, const char* path);

// Free PathList
void pathlist_free(PathList* list);

// Create new Config
Config* config_create(void);

// Free Config
void config_free(Config* config);

// Load global config file
bool config_load_global(Config* config);

// Load per-directory config file
bool config_load_local(Config* config);

// Get merged list of all writable paths
PathList* config_get_all_paths(Config* config);

#endif // CONFIG_H
