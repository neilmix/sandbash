#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <getopt.h>
#include <unistd.h>
#include "config.h"
#include "sandbox.h"
#include "utils.h"

typedef enum {
    MODE_SANDBOX,
    MODE_ADD_PATH,
    MODE_REMOVE_PATH,
    MODE_EDIT,
    MODE_LIST_PATHS
} OperationMode;

typedef struct {
    OperationMode mode;
    PathList* allow_write_paths;
    int bash_argc;
    char** bash_argv;
} Arguments;

static void print_usage(const char* program_name) {
    printf("Usage: %s [OPTIONS] [BASH_ARGS...]\n", program_name);
    printf("\nSandbox execution:\n");
    printf("  %s [--allow-write=PATH]... [BASH_ARGS...]\n", program_name);
    printf("\nConfiguration management:\n");
    printf("  --add-path PATH      Add path to per-directory config\n");
    printf("  --remove-path PATH   Remove path from per-directory config\n");
    printf("  --edit               Edit per-directory config\n");
    printf("  --list-paths         List all writable paths\n");
    printf("\nOptions:\n");
    printf("  --allow-write=PATH   Add temporary writable path\n");
    printf("  -h, --help           Show this help message\n");
}

static Arguments* parse_arguments(int argc, char* argv[]) {
    Arguments* args = malloc(sizeof(Arguments));
    if (!args) {
        return NULL;
    }

    args->mode = MODE_SANDBOX;
    args->allow_write_paths = pathlist_create();
    args->bash_argc = 0;
    args->bash_argv = NULL;

    static struct option long_options[] = {
        {"allow-write", required_argument, 0, 'w'},
        {"add-path", required_argument, 0, 'a'},
        {"remove-path", required_argument, 0, 'r'},
        {"edit", no_argument, 0, 'e'},
        {"list-paths", no_argument, 0, 'l'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };

    int opt;
    int option_index = 0;

    while ((opt = getopt_long(argc, argv, "+w:a:r:elh",
                              long_options, &option_index)) != -1) {
        switch (opt) {
            case 'w':
                pathlist_add(args->allow_write_paths, optarg);
                break;
            case 'a':
                args->mode = MODE_ADD_PATH;
                pathlist_add(args->allow_write_paths, optarg);
                break;
            case 'r':
                args->mode = MODE_REMOVE_PATH;
                pathlist_add(args->allow_write_paths, optarg);
                break;
            case 'e':
                args->mode = MODE_EDIT;
                break;
            case 'l':
                args->mode = MODE_LIST_PATHS;
                break;
            case 'h':
                print_usage(argv[0]);
                exit(0);
            default:
                print_usage(argv[0]);
                exit(1);
        }
    }

    // Remaining arguments go to bash
    args->bash_argc = argc - optind;
    args->bash_argv = argv + optind;

    return args;
}

static void free_arguments(Arguments* args) {
    if (!args) {
        return;
    }
    pathlist_free(args->allow_write_paths);
    free(args);
}

int main(int argc, char* argv[]) {
    Arguments* args = parse_arguments(argc, argv);
    if (!args) {
        fprintf(stderr, "Error: Failed to parse arguments\n");
        return 1;
    }

    // Check home directory constraint
    if (!is_under_home_directory()) {
        fprintf(stderr, "Error: sandbash must be invoked from within your home directory\n");
        char cwd[4096];
        getcwd(cwd, sizeof(cwd));
        fprintf(stderr, "Current directory: %s\n", cwd);
        fprintf(stderr, "Home directory: %s\n", getenv("HOME"));
        free_arguments(args);
        return 1;
    }

    printf("Mode: %d\n", args->mode);
    printf("Allow-write paths: %d\n", args->allow_write_paths->count);
    printf("Bash args: %d\n", args->bash_argc);

    free_arguments(args);
    return 0;
}
