# sandbash

macOS sandbox launcher for shells. Uses the private `sandbox_init_with_parameters` API.

## Build

```
make          # build
make clean    # clean build artifacts
```

Compiler: clang, C11, `-Wall -Wextra -O2`

## Tests

Shell scripts in `test/`. No `make test` target — run individually:

```
bash test/test_argument_parsing.sh
bash test/test_config_errors.sh
```

`test/manual_tests.sh` requires interactive input.

## Key conventions

- Config parsing is strict: missing directories and invalid paths are hard errors (not warnings)
- `expand_path()` uses `realpath()` — returns NULL for nonexistent paths
- Config load failures in `main.c` must be checked and cause exit(1)
