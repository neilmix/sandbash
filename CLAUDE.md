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
bash test/test_sandbox_profile.sh
bash test/test_editor_security.sh
bash test/test_executable_permissions.sh
bash test/test_sandbox_escaping.sh
```

Run all of them — `for t in test/test_*.sh; do bash "$t"; done`. Suites report in two different formats (`PASS:`/`FAIL:` counts vs. `Results: N passed, N failed`), so grepping for just one format silently skips the others.

`test/manual_tests.sh` and `test/test_shell_selection.sh` require interactive input and contain no automated assertions.

Sandbox-dependent tests (most of `test_argument_parsing.sh` and all of `test_sandbox_profile.sh`) require the binary to be code-signed. In unsigned dev builds they fail with "Operation not permitted" — this is expected. Only config-management and error-handling tests pass without signing.

## Key conventions

- Config parsing is strict: missing directories and invalid paths are hard errors (not warnings)
- Config lines are `+ PATH` (writable) or `- PATH` (denied read+write). Any other non-blank line, including `#` comments, is a hard error. No wildcards.
- Deny rules are emitted after write allowances (last match wins). Every ancestor of a denied path gets `(deny file-write-unlink (literal ...))` so it cannot be renamed to move the denied content out from under the path-based rule.
- Symlinked paths are rejected everywhere (config files, `--allow-write`, `--add-path`) — user must specify canonical paths. Uses `expand_tilde()` vs `expand_path()` comparison to detect symlinks.
- `expand_tilde()` does `~` expansion only; `expand_path()` does `~` expansion + `realpath()`
- Config load failures in `main.c` must be checked and cause exit(1)
- The sandbox profile is fixed — there are no flags that loosen it. `--allow-write`/`--add-path` only add writable paths. Signals are scoped to `(target same-sandbox)`; SysV shm and semaphores are always allowed, message queues are not.
- Setuid/setgid exec is denied to sandboxed processes by macOS unless the rule carries `(with no-sandbox)`, which runs the child unconfined. The profile grants exactly one such exception, scoped to the literal `/bin/ps` (read-only, spawns nothing). Do NOT broaden it to a subpath/name or other setuid tools — that turns write-confinement into a general escape primitive.

## Test conventions

- All tests must isolate config via `setup_config`/`teardown_config` setting `XDG_CONFIG_HOME` to a temp dir
- Use `inc_pass`/`inc_fail` helper functions, never `((VAR++))` — the latter returns exit code 1 when VAR=0, which kills scripts under `set -e`
