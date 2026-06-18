/*
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
*/

#include <cstdio>
#include <lean/lean.h>

namespace lean {
extern "C" {

LEAN_EXPORT lean_object * lean_web_console_log(b_lean_obj_arg s) {
    size_t sz = lean_string_size(s);
    if (sz > 0) {
        std::fwrite(lean_string_cstr(s), 1, sz - 1, stderr);
        std::fputc('\n', stderr);
    }
    return lean_box(0);
}

LEAN_EXPORT lean_object * lean_web_set_text(b_lean_obj_arg id, b_lean_obj_arg text) {
    (void)id; (void)text;
    std::fputs("lean-host: Std.Web.setText called (no-op on host)\n", stderr);
    return lean_box(0);
}

LEAN_EXPORT lean_object * lean_web_set_html(b_lean_obj_arg id, b_lean_obj_arg html) {
    (void)id; (void)html;
    std::fputs("lean-host: Std.Web.setHtml called (no-op on host)\n", stderr);
    return lean_box(0);
}

LEAN_EXPORT lean_object * lean_web_get_value(b_lean_obj_arg id) {
    (void)id;
    std::fputs("lean-host: Std.Web.getValue called (empty on host)\n", stderr);
    return lean_mk_string("");
}

LEAN_EXPORT lean_object * lean_web_set_value(b_lean_obj_arg id, b_lean_obj_arg value) {
    (void)id; (void)value;
    std::fputs("lean-host: Std.Web.setValue called (no-op on host)\n", stderr);
    return lean_box(0);
}

} // extern "C"
} // namespace lean
