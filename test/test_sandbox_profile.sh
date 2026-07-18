#!/bin/bash
# Test suite for base sandbox profile behavior
# Signals are scoped to the sandbox; SysV shared memory is available.
# Neither is gated behind a flag.

set -e

echo "=== Sandbox Profile Test Suite ==="
echo

PASS=0
FAIL=0

inc_pass() { PASS=$((PASS + 1)); }
inc_fail() { FAIL=$((FAIL + 1)); }

# Use isolated config dir to avoid interference from user's config
setup_config() {
    TEST_CONFIG=$(mktemp -d)
    mkdir -p "$TEST_CONFIG/sandbash/projects"
    export XDG_CONFIG_HOME="$TEST_CONFIG"
}

teardown_config() {
    rm -rf "$TEST_CONFIG"
    unset XDG_CONFIG_HOME
}

# Test 1: Self-signaling works
echo "Test 1: Self-signaling works"
setup_config
if ./sandbash bash -c 'kill -0 $$ && echo ok' 2>/dev/null | grep -q 'ok'; then
    echo "  ✓ PASS: kill -0 self succeeds"
    inc_pass
else
    echo "  ✗ FAIL: kill -0 self should succeed"
    inc_fail
fi
teardown_config
echo

# Test 2: Signaling a process spawned inside the sandbox works.
# This is the ergonomic case: killing dev servers and test runners.
echo "Test 2: Signaling a sandbox-spawned child works"
setup_config
if ./sandbash bash -c 'sleep 30 & C=$!; kill -0 $C && echo ok; kill -9 $C' 2>/dev/null | grep -q 'ok'; then
    echo "  ✓ PASS: kill -0 sandbox-spawned child succeeds"
    inc_pass
else
    echo "  ✗ FAIL: kill -0 sandbox-spawned child should succeed"
    inc_fail
fi
teardown_config
echo

# Test 3: Signaling a process outside the sandbox is still denied.
# This is the boundary that must NOT regress.
echo "Test 3: Signaling external process is denied"
setup_config
sleep 300 &
EXT_PID=$!
if ./sandbash bash -c "kill -0 $EXT_PID" 2>/dev/null; then
    echo "  ✗ FAIL: kill -0 external PID should be denied"
    inc_fail
else
    echo "  ✓ PASS: kill -0 external PID denied"
    inc_pass
fi
kill $EXT_PID 2>/dev/null || true
wait $EXT_PID 2>/dev/null || true
teardown_config
echo

# Test 4: --allow-signal is gone and rejected as an unknown option
echo "Test 4: --allow-signal is rejected"
setup_config
if ./sandbash --allow-signal bash -c 'echo ok' 2>/dev/null | grep -q 'ok'; then
    echo "  ✗ FAIL: --allow-signal should no longer be accepted"
    inc_fail
else
    echo "  ✓ PASS: --allow-signal rejected"
    inc_pass
fi
teardown_config
echo

# Test 5: SysV shm removal works. The create path has no MAC hook, so a bare
# create succeeds even when the profile is wrong -- IPC_RMID is the
# discriminating call.
echo "Test 5: SysV shm create+remove works"
setup_config
cat > "$TEST_CONFIG/shm.c" <<'EOF'
#include <sys/ipc.h>
#include <sys/shm.h>
#include <stdio.h>
int main(void) {
    int id = shmget(IPC_PRIVATE, 56, IPC_CREAT | 0600);
    if (id == -1) { printf("create failed\n"); return 1; }
    if (shmctl(id, IPC_RMID, NULL) == -1) { printf("remove failed\n"); return 1; }
    printf("ok\n");
    return 0;
}
EOF
cc -o "$TEST_CONFIG/shm" "$TEST_CONFIG/shm.c" 2>/dev/null
if ./sandbash bash -c "$TEST_CONFIG/shm" 2>/dev/null | grep -q 'ok'; then
    echo "  ✓ PASS: SysV shm create and remove succeed"
    inc_pass
else
    echo "  ✗ FAIL: SysV shm create and remove should succeed"
    inc_fail
fi
teardown_config
echo

# Test 6: SysV shm on an already-existing key works.
# Distinct code path from create; this is what broke Postgres restarts.
echo "Test 6: SysV shm on existing key works"
setup_config
cat > "$TEST_CONFIG/shm2.c" <<'EOF'
#include <sys/ipc.h>
#include <sys/shm.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char** argv) {
    key_t key = (key_t)strtol(argv[1], NULL, 0);
    int id = shmget(key, 56, IPC_CREAT | 0600);   /* existing-segment path */
    if (id == -1) { printf("get failed\n"); return 1; }
    if (argc > 2) shmctl(id, IPC_RMID, NULL);
    printf("ok\n");
    return 0;
}
EOF
cc -o "$TEST_CONFIG/shm2" "$TEST_CONFIG/shm2.c" 2>/dev/null
# Create the segment outside the sandbox, then open it from inside.
KEY=0x5A2B01
"$TEST_CONFIG/shm2" $KEY >/dev/null 2>&1
if ./sandbash bash -c "$TEST_CONFIG/shm2 $KEY rm" 2>/dev/null | grep -q 'ok'; then
    echo "  ✓ PASS: shmget on existing key succeeds"
    inc_pass
else
    echo "  ✗ FAIL: shmget on existing key should succeed"
    inc_fail
    "$TEST_CONFIG/shm2" $KEY rm >/dev/null 2>&1 || true
fi
teardown_config
echo

# Test 7: SysV semaphores work.
# As with shm, semget's allocate path has no MAC hook -- semctl is the
# discriminating call.
echo "Test 7: SysV semaphore setval+remove works"
setup_config
cat > "$TEST_CONFIG/sem.c" <<'EOF'
#include <sys/ipc.h>
#include <sys/sem.h>
#include <stdio.h>
union semun_t { int val; struct semid_ds *buf; unsigned short *array; };
int main(void) {
    int id = semget(IPC_PRIVATE, 1, IPC_CREAT | 0600);
    if (id == -1) { printf("semget failed\n"); return 1; }
    union semun_t arg; arg.val = 1;
    if (semctl(id, 0, SETVAL, arg) == -1) { printf("setval failed\n"); return 1; }
    if (semctl(id, 0, IPC_RMID) == -1) { printf("remove failed\n"); return 1; }
    printf("ok\n");
    return 0;
}
EOF
cc -o "$TEST_CONFIG/sem" "$TEST_CONFIG/sem.c" 2>/dev/null
if ./sandbash bash -c "$TEST_CONFIG/sem" 2>/dev/null | grep -q 'ok'; then
    echo "  ✓ PASS: semctl SETVAL and IPC_RMID succeed"
    inc_pass
else
    echo "  ✗ FAIL: semctl SETVAL and IPC_RMID should succeed"
    inc_fail
fi
teardown_config
echo

# Test 8: SysV message queues remain denied.
# Not needed by any known workload; unlike semaphores they carry a data
# payload, so the profile stays narrow rather than using ipc-sysv*.
echo "Test 8: SysV message queues remain denied"
setup_config
cat > "$TEST_CONFIG/msg.c" <<'EOF'
#include <sys/ipc.h>
#include <sys/msg.h>
#include <stdio.h>
int main(void) {
    int id = msgget(IPC_PRIVATE, IPC_CREAT | 0600);
    if (id == -1) { printf("denied\n"); return 0; }
    if (msgctl(id, IPC_RMID, NULL) == -1) { printf("denied\n"); return 0; }
    printf("allowed\n");
    return 0;
}
EOF
cc -o "$TEST_CONFIG/msg" "$TEST_CONFIG/msg.c" 2>/dev/null
if ./sandbash bash -c "$TEST_CONFIG/msg" 2>/dev/null | grep -q 'denied'; then
    echo "  ✓ PASS: SysV message queues denied"
    inc_pass
else
    echo "  ✗ FAIL: SysV message queues should remain denied"
    inc_fail
fi
teardown_config
echo

# Summary
echo "=== Test Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo

if [ $FAIL -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
