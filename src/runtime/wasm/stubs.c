/*
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Trap shims for runtime symbols the wasm32 target must link against but does
not implement. Calling one halts the module via WASI `proc_exit(1)` after
logging a diagnostic. Mirrors `src/runtime/sbf/stubs.c`.
*/

#include <stdint.h>
#include <stddef.h>

extern void lean_freestanding_log(const char *msg, uint64_t len);
extern void lean_freestanding_panic(const char *what, uint64_t a, uint64_t b);
extern uint64_t lean_strlen(const char *s);

#define LEAN_WASM_TRAP(name)                                                 \
    do {                                                                     \
        const char *_msg = "lean-wasm: unsupported runtime symbol: " name;   \
        lean_freestanding_log(_msg, lean_strlen(_msg));                      \
        lean_freestanding_panic(name, 0, 0);                                 \
        __builtin_unreachable();                                             \
    } while (0)

#define LEAN_WASM_TRAP_FN0(name, ret)                                        \
    ret name(void) { LEAN_WASM_TRAP(#name); }
#define LEAN_WASM_TRAP_FN1(name, ret, t1)                                    \
    ret name(t1 a) { (void)a; LEAN_WASM_TRAP(#name); }
#define LEAN_WASM_TRAP_FN2(name, ret, t1, t2)                                \
    ret name(t1 a, t2 b) { (void)a; (void)b; LEAN_WASM_TRAP(#name); }
#define LEAN_WASM_TRAP_FN3(name, ret, t1, t2, t3)                            \
    ret name(t1 a, t2 b, t3 c) { (void)a; (void)b; (void)c; LEAN_WASM_TRAP(#name); }

/* IO scaffolding / module init not provided on wasm32. */
LEAN_WASM_TRAP_FN1(lean_io_result_show_error,         void,     void *)
LEAN_WASM_TRAP_FN1(lean_initialize_runtime_module,    void *,   void *)
LEAN_WASM_TRAP_FN0(lean_init_task_manager,            void)
LEAN_WASM_TRAP_FN0(lean_finalize_task_manager,        void)

/* Host-runtime decls deny-listed for wasm32-* (see src/Std/Wasm/Unsupported.lean). */
LEAN_WASM_TRAP_FN1(lean_get_stdout,         void *,   void *)
LEAN_WASM_TRAP_FN1(lean_setup_args,         void,     void *)
LEAN_WASM_TRAP_FN1(lean_set_panic_messages, void,     uint8_t)
