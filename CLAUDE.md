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
bash test/test_allow_signal.sh
```

`test/manual_tests.sh` requires interactive input.

Sandbox-dependent tests (most of `test_argument_parsing.sh` and all of `test_allow_signal.sh`) require the binary to be code-signed. In unsigned dev builds they fail with "Operation not permitted" — this is expected. Only config-management and error-handling tests pass without signing.

## Key conventions

- Config parsing is strict: missing directories and invalid paths are hard errors (not warnings)
- Symlinked paths are rejected everywhere (config files, `--allow-write`, `--add-path`) — user must specify canonical paths. Uses `expand_tilde()` vs `expand_path()` comparison to detect symlinks.
- `expand_tilde()` does `~` expansion only; `expand_path()` does `~` expansion + `realpath()`
- Config load failures in `main.c` must be checked and cause exit(1)

## Test conventions

- All tests must isolate config via `setup_config`/`teardown_config` setting `XDG_CONFIG_HOME` to a temp dir
- Use `inc_pass`/`inc_fail` helper functions, never `((VAR++))` — the latter returns exit code 1 when VAR=0, which kills scripts under `set -e`
