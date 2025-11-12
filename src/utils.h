#ifndef UTILS_H
#define UTILS_H

#include <stdbool.h>

// Check if current directory is under HOME
bool is_under_home_directory(void);

// Get expanded path (handle ~ and relative paths)
char* expand_path(const char* path);

// Compute SHA256 hash of string, return first 16 hex chars
char* compute_path_hash(const char* path);

// Get XDG config directory (~/.config)
char* get_xdg_config_dir(void);

// Free allocated string
void free_string(char* str);

#endif // UTILS_H
