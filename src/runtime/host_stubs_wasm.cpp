/*
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
*/

#include <cstdio>
#include <cstdlib>
#include <lean/lean.h>

namespace lean {
extern "C" {

LEAN_EXPORT lean_object * lean_wasm_log(b_lean_obj_arg s) {
    size_t sz = lean_string_size(s);
    if (sz > 0) {
        std::fwrite(lean_string_cstr(s), 1, sz - 1, stderr);
        std::fputc('\n', stderr);
    }
    return lean_box(0);
}

LEAN_EXPORT lean_object * lean_wasm_print(b_lean_obj_arg s) {
    size_t sz = lean_string_size(s);
    if (sz > 0) {
        std::fwrite(lean_string_cstr(s), 1, sz - 1, stdout);
    }
    return lean_box(0);
}

LEAN_EXPORT lean_object * lean_wasm_read_stdin(size_t cap) {
    (void)cap;
    return lean_alloc_sarray(1, 0, 0);
}

LEAN_EXPORT size_t lean_wasm_argc(b_lean_obj_arg unit) {
    (void)unit;
    return 0;
}

LEAN_EXPORT lean_object * lean_wasm_arg(size_t idx) {
    (void)idx;
    return lean_mk_string("");
}

LEAN_EXPORT lean_object * lean_wasm_exit(uint32_t code) {
    std::exit(static_cast<int>(code));
    return lean_box(0);
}

} // extern "C"
} // namespace lean
