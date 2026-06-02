/*
 * Hermetic shim that compiles the freestanding runtime into the test
 * binary. Defines the freestanding heap, the embedder hooks
 * (`lean_freestanding_log` / `lean_freestanding_panic`), and then
 * `#include`s runtime.c.
 *
 * This TU intentionally pulls in NO libc headers beyond <stdint.h> and
 * <stddef.h>. The runtime defines its own `memcpy`, `memset`,
 * `memmove`, which would clash with the fortified-libc macros pulled in
 * by `<string.h>` (and transitively by `<stdio.h>`/`<stdlib.h>`) on
 * macOS. The test harness lives in test_cow.c and links against the
 * runtime's public symbols defined here.
 *
 * Panic handler: write a short banner via __builtin_trap so the harness
 * exits non-zero and the parent script reports the failure. We avoid
 * write(2)/_exit(2) for the same hermeticity reason -- `<unistd.h>` also
 * brings in some `_common.h` machinery on recent macOS SDKs.
 */

#include <stdint.h>
#include <stddef.h>

/* 1 MiB freestanding heap. BSS-initialised so `*bp == 0` on first
   allocation primes the allocator cursor past the prefix. */
uint8_t lean_test_heap[1u << 20];

#define LEAN_FREESTANDING_HEAP_BASE   ((uintptr_t)lean_test_heap)
#define LEAN_FREESTANDING_HEAP_BYTES  ((uintptr_t)sizeof(lean_test_heap))
#define LEAN_FREESTANDING_HEAP_PREFIX ((uintptr_t)64)

/* Set by the test harness so a runtime panic surfaces as an explicit
   failure rather than just a trap. Not strictly needed for correctness
   -- __builtin_trap alone would still fail the test -- but it's nice to
   know which runtime invariant fired. */
const char *lean_test_panic_what = 0;
uint64_t    lean_test_panic_a    = 0;
uint64_t    lean_test_panic_b    = 0;

void lean_freestanding_log(const char *msg, uint64_t len) {
    (void)msg; (void)len;
    /* Drop runtime log lines; the harness has its own reporting. */
}

void lean_freestanding_panic(const char *what, uint64_t a, uint64_t b) {
    lean_test_panic_what = what;
    lean_test_panic_a    = a;
    lean_test_panic_b    = b;
    __builtin_trap();
}

/* Bring the runtime in. */
#include "../../src/runtime/freestanding/runtime.c"
