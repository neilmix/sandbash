#ifndef SANDBOX_H
#define SANDBOX_H

#include "config.h"
#include <stdbool.h>

// Generate sandbox profile from config
char* sandbox_generate_profile(Config* config);

// Initialize sandbox with profile
bool sandbox_init_with_profile(const char* profile);

#endif // SANDBOX_H
