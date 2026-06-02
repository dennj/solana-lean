/*
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Trap shims for Lean runtime symbols the SBF target must link cleanly against
but does not implement on-chain. Calling one halts the VM via `sol_panic_`
with a diagnostic naming the symbol.
*/

#include <stdint.h>
#include <stddef.h>

extern void sol_log_(const char *, uint64_t);
extern void sol_panic_(const char *, uint64_t, uint64_t, uint64_t);

static uint64_t sol_strlen(const char *s) {
    uint64_t n = 0;
    while (s[n]) ++n;
    return n;
}

#define LEAN_SBF_TRAP(name)                                                  \
    do {                                                                     \
        const char *_msg = "lean-sbf: unsupported Lean runtime symbol: " name; \
        sol_log_(_msg, sol_strlen(_msg));                                    \
        sol_panic_(name, sizeof(name) - 1, 0, 0);                            \
        __builtin_unreachable();                                             \
    } while (0)

#define LEAN_SBF_TRAP_FN0(name, ret)                                         \
    ret name(void) { LEAN_SBF_TRAP(#name); }
#define LEAN_SBF_TRAP_FN1(name, ret, t1)                                     \
    ret name(t1 a) { (void)a; LEAN_SBF_TRAP(#name); }
#define LEAN_SBF_TRAP_FN2(name, ret, t1, t2)                                 \
    ret name(t1 a, t2 b) { (void)a; (void)b; LEAN_SBF_TRAP(#name); }
#define LEAN_SBF_TRAP_FN3(name, ret, t1, t2, t3)                             \
    ret name(t1 a, t2 b, t3 c) { (void)a; (void)b; (void)c; LEAN_SBF_TRAP(#name); }

/* IO scaffolding / module init not provided on SBF. */
LEAN_SBF_TRAP_FN1(lean_io_result_show_error,         void,     void *)
LEAN_SBF_TRAP_FN1(lean_initialize_runtime_module,    void *,   void *)

/* Host-runtime decls deny-listed for sbf-* (see src/Std/Solana/Unsupported.lean). */
LEAN_SBF_TRAP_FN1(lean_get_stdout,         void *,   void *)
LEAN_SBF_TRAP_FN1(lean_setup_args,         void,     void *)
LEAN_SBF_TRAP_FN1(lean_set_panic_messages, void,     uint8_t)
