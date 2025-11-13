#ifndef SANDBOX_H
#define SANDBOX_H

#include "config.h"
#include <stdbool.h>

// Generate sandbox profile from config
char* sandbox_generate_profile(Config* config);

// Initialize sandbox with profile
bool sandbox_init_with_profile(const char* profile);

// Escape special characters in strings for sandbox profile
char* escape_sandbox_string(const char* str);

#endif // SANDBOX_H
