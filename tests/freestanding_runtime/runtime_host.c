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

/* The CoW harness exercises real reference counting + reclamation. The
   runtime defaults to arena lifetime (dec is no-op); opt in here so the
   probes actually decrement, reclaim, and re-use freed blocks. */
#define LEAN_FREESTANDING_RECLAIMING_RC 1

/* Stubs for Lean stdlib externs that the freestanding runtime references
   for Expr / Name specializations (DHashMap-over-Expr, DTreeMap-over-Name).
   The CoW probes here exercise array invariants only and never reach these
   code paths; if a stub is ever called, trap with a clear marker. */
static void lean_test_unreachable_extern_stub(void) { __builtin_trap(); }
void *lean_expr_mk_bvar(void *idx)                          { (void)idx; lean_test_unreachable_extern_stub(); return 0; }
void *lean_expr_mk_fvar(void *fvarId)                       { (void)fvarId; lean_test_unreachable_extern_stub(); return 0; }
void *lean_expr_mk_mvar(void *mvarId)                       { (void)mvarId; lean_test_unreachable_extern_stub(); return 0; }
void *lean_expr_mk_sort(void *u)                            { (void)u; lean_test_unreachable_extern_stub(); return 0; }
void *lean_expr_mk_const(void *c, void *lvls)               { (void)c; (void)lvls; lean_test_unreachable_extern_stub(); return 0; }
void *lean_expr_mk_app(void *f, void *a)                    { (void)f; (void)a; lean_test_unreachable_extern_stub(); return 0; }
void *lean_expr_mk_lambda(void *n, void *d, void *b, uint8_t bi)
                                                            { (void)n; (void)d; (void)b; (void)bi; lean_test_unreachable_extern_stub(); return 0; }
void *lean_expr_mk_forall(void *n, void *d, void *b, uint8_t bi)
                                                            { (void)n; (void)d; (void)b; (void)bi; lean_test_unreachable_extern_stub(); return 0; }
void *lean_expr_mk_let(void *n, void *t, void *v, void *b, uint8_t nondep)
                                                            { (void)n; (void)t; (void)v; (void)b; (void)nondep; lean_test_unreachable_extern_stub(); return 0; }
void *lean_expr_mk_lit(void *l)                             { (void)l; lean_test_unreachable_extern_stub(); return 0; }
void *lean_expr_mk_mdata(void *m, void *e)                  { (void)m; (void)e; lean_test_unreachable_extern_stub(); return 0; }
void *lean_expr_mk_proj(void *s, void *idx, void *e)        { (void)s; (void)idx; (void)e; lean_test_unreachable_extern_stub(); return 0; }
uint8_t l___private_Lean_Data_Name_0__Lean_Name_quickCmpImpl(void *a, void *b)
                                                            { (void)a; (void)b; lean_test_unreachable_extern_stub(); return 0; }

/* Bring the runtime in. */
#include "../../src/runtime/freestanding/runtime.c"
