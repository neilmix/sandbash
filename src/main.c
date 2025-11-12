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

static int handle_add_path(Config* config, const char* path) {
    char* expanded = expand_path(path);
    if (!expanded) {
        fprintf(stderr, "Error: Invalid path: %s\n", path);
        return 1;
    }

    pathlist_add(config->local_paths, expanded);
    free(expanded);

    if (!config_save_local(config)) {
        fprintf(stderr, "Error: Failed to save configuration\n");
        return 1;
    }

    char* config_path = config_get_local_path(config);
    printf("Added path to config: %s\n", config_path);
    printf("Path: %s\n", path);
    free(config_path);

    return 0;
}

static int handle_remove_path(Config* config, const char* path) {
    char* expanded = expand_path(path);
    if (!expanded) {
        fprintf(stderr, "Error: Invalid path: %s\n", path);
        return 1;
    }

    if (!pathlist_remove(config->local_paths, expanded)) {
        fprintf(stderr, "Warning: Path not found in config: %s\n", path);
    }
    free(expanded);

    if (!config_save_local(config)) {
        fprintf(stderr, "Error: Failed to save configuration\n");
        return 1;
    }

    char* config_path = config_get_local_path(config);
    printf("Removed path from config: %s\n", config_path);
    printf("Path: %s\n", path);
    free(config_path);

    return 0;
}

static int handle_edit(Config* config) {
    char* config_path = config_get_local_path(config);
    if (!config_path) {
        fprintf(stderr, "Error: Failed to determine config path\n");
        return 1;
    }

    // Ensure file exists
    FILE* f = fopen(config_path, "a");
    if (f) {
        fclose(f);
    }

    const char* editor = getenv("EDITOR");
    if (!editor) {
        editor = "vi";
    }

    char command[PATH_MAX + 100];
    snprintf(command, sizeof(command), "%s %s", editor, config_path);

    int result = system(command);
    free(config_path);

    return result;
}

static int handle_list_paths(Config* config) {
    printf("Current directory: %s (always writable)\n\n", config->current_dir);

    char* xdg_config = get_xdg_config_dir();

    printf("Global paths (from %s/sandbash/config):\n", xdg_config);
    if (config->global_paths->count == 0) {
        printf("  (none)\n");
    } else {
        for (int i = 0; i < config->global_paths->count; i++) {
            printf("  %s\n", config->global_paths->paths[i]);
        }
    }
    printf("\n");

    char* local_config_path = config_get_local_path(config);
    printf("Per-directory paths (from %s):\n", local_config_path);
    free(local_config_path);

    if (config->local_paths->count == 0) {
        printf("  (none)\n");
    } else {
        for (int i = 0; i < config->local_paths->count; i++) {
            printf("  %s\n", config->local_paths->paths[i]);
        }
    }
    printf("\n");

    printf("Command-line paths:\n");
    if (config->cli_paths->count == 0) {
        printf("  (none)\n");
    } else {
        for (int i = 0; i < config->cli_paths->count; i++) {
            printf("  %s\n", config->cli_paths->paths[i]);
        }
    }

    free(xdg_config);
    return 0;
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

    // Create config
    Config* config = config_create();
    if (!config) {
        fprintf(stderr, "Error: Failed to create configuration\n");
        free_arguments(args);
        return 1;
    }

    // Load configs
    config_load_global(config);
    config_load_local(config);

    // Add CLI paths
    for (int i = 0; i < args->allow_write_paths->count; i++) {
        char* expanded = expand_path(args->allow_write_paths->paths[i]);
        if (expanded) {
            pathlist_add(config->cli_paths, expanded);
            free(expanded);
        }
    }

    // Handle different modes
    int result = 0;
    switch (args->mode) {
        case MODE_ADD_PATH:
            if (args->allow_write_paths->count > 0) {
                result = handle_add_path(config, args->allow_write_paths->paths[0]);
            }
            break;
        case MODE_REMOVE_PATH:
            if (args->allow_write_paths->count > 0) {
                result = handle_remove_path(config, args->allow_write_paths->paths[0]);
            }
            break;
        case MODE_EDIT:
            result = handle_edit(config);
            break;
        case MODE_LIST_PATHS:
            result = handle_list_paths(config);
            break;
        case MODE_SANDBOX:
            printf("TODO: Launch sandbox\n");
            break;
    }

    config_free(config);
    free_arguments(args);
    return result;
}
