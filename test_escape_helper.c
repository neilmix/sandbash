#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Function to test - should escape quotes and backslashes
char* escape_sandbox_string(const char* str);

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <string_to_escape>\n", argv[0]);
        return 1;
    }

    char* escaped = escape_sandbox_string(argv[1]);
    if (!escaped) {
        fprintf(stderr, "Error: Failed to escape string\n");
        return 1;
    }

    printf("%s", escaped);
    free(escaped);
    return 0;
}
