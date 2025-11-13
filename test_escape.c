#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

// Function under test - declare it but it doesn't exist yet
char* escape_sandbox_string(const char* str);

int main(void) {
    printf("=== Sandbox Profile Escaping Tests ===\n\n");

    // Test 1: Escape double quotes
    printf("Test 1: Escape double quotes...\n");
    char* result1 = escape_sandbox_string("/tmp/test\"path");
    assert(strcmp(result1, "/tmp/test\\\"path") == 0);
    free(result1);
    printf("  PASS\n\n");

    // Test 2: Escape backslashes
    printf("Test 2: Escape backslashes...\n");
    char* result2 = escape_sandbox_string("/tmp/test\\path");
    assert(strcmp(result2, "/tmp/test\\\\path") == 0);
    free(result2);
    printf("  PASS\n\n");

    // Test 3: Escape both
    printf("Test 3: Escape both quotes and backslashes...\n");
    char* result3 = escape_sandbox_string("/tmp/test\\\"path");
    assert(strcmp(result3, "/tmp/test\\\\\\\"path") == 0);
    free(result3);
    printf("  PASS\n\n");

    // Test 4: Normal path unchanged
    printf("Test 4: Normal path unchanged...\n");
    char* result4 = escape_sandbox_string("/tmp/normal/path");
    assert(strcmp(result4, "/tmp/normal/path") == 0);
    free(result4);
    printf("  PASS\n\n");

    printf("All tests passed!\n");
    return 0;
}
