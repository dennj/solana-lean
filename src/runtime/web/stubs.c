/*
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
*/

#include <stdint.h>
#include <stddef.h>

extern void lean_freestanding_log(const char *msg, uint64_t len);
extern void lean_freestanding_panic(const char *what, uint64_t a, uint64_t b);
extern uint64_t lean_strlen(const char *s);

#define LEAN_WEB_TRAP(name)                                                 \
    do {                                                                    \
        const char *_msg = "lean-web: unsupported runtime symbol: " name;   \
        lean_freestanding_log(_msg, lean_strlen(_msg));                     \
        lean_freestanding_panic(name, 0, 0);                                \
        __builtin_unreachable();                                            \
    } while (0)

#define LEAN_WEB_TRAP_FN0(name, ret)                                        \
    ret name(void) { LEAN_WEB_TRAP(#name); }
#define LEAN_WEB_TRAP_FN1(name, ret, t1)                                    \
    ret name(t1 a) { (void)a; LEAN_WEB_TRAP(#name); }

LEAN_WEB_TRAP_FN1(lean_io_result_show_error,      void,   void *)
LEAN_WEB_TRAP_FN1(lean_initialize_runtime_module, void *, void *)

LEAN_WEB_TRAP_FN0(lean_get_stdout,         void *)
LEAN_WEB_TRAP_FN1(lean_setup_args,         void,   void *)
LEAN_WEB_TRAP_FN1(lean_set_panic_messages, void,   uint8_t)
