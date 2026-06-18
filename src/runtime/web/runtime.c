/*
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
*/

#include <stdint.h>
#include <stddef.h>
#include "lean_freestanding.h"

__attribute__((import_module("lean_web"), import_name("log")))
extern void lean_web_import_log(const char *ptr, uint32_t len);

__attribute__((import_module("lean_web"), import_name("panic")))
extern void lean_web_import_panic(const char *ptr, uint32_t len);

__attribute__((import_module("lean_web"), import_name("dom_set_text")))
extern void lean_web_import_dom_set_text(const char *id_ptr, uint32_t id_len,
                                         const char *text_ptr, uint32_t text_len);

__attribute__((import_module("lean_web"), import_name("dom_set_html")))
extern void lean_web_import_dom_set_html(const char *id_ptr, uint32_t id_len,
                                         const char *html_ptr, uint32_t html_len);

__attribute__((import_module("lean_web"), import_name("dom_get_value_len")))
extern uint32_t lean_web_import_dom_get_value_len(const char *id_ptr, uint32_t id_len);

__attribute__((import_module("lean_web"), import_name("dom_get_value")))
extern uint32_t lean_web_import_dom_get_value(const char *id_ptr, uint32_t id_len,
                                              char *dst_ptr, uint32_t dst_len);

__attribute__((import_module("lean_web"), import_name("dom_set_value")))
extern void lean_web_import_dom_set_value(const char *id_ptr, uint32_t id_len,
                                          const char *value_ptr, uint32_t value_len);

extern uint64_t lean_strlen(const char *s);
extern void *lean_io_result_mk_ok(void *value);
extern void *lean_box(size_t n);
extern void *lean_mk_string_from_bytes(const char *s, size_t sz);
extern void *bump_alloc(size_t size);

static uint32_t lean_web_string_size(void *s) {
    lean_string_object *str = (lean_string_object *)s;
    return str->m_size > 0 ? (uint32_t)(str->m_size - 1) : 0;
}

static const char *lean_web_string_data_ptr(void *s) {
    lean_string_object *str = (lean_string_object *)s;
    return str->m_data;
}

void lean_freestanding_log(const char *msg, uint64_t len) {
    lean_web_import_log(msg, (uint32_t)len);
}

void lean_freestanding_panic(const char *what, uint64_t a, uint64_t b) {
    (void)a; (void)b;
    lean_web_import_panic(what, (uint32_t)lean_strlen(what));
    __builtin_trap();
}

void *initialize_Std_Web(uint8_t builtin, void *world) {
    (void)builtin; (void)world;
    return lean_io_result_mk_ok(lean_box(0));
}

void *lean_web_console_log(void *s, void *world) {
    (void)world;
    lean_web_import_log(lean_web_string_data_ptr(s), lean_web_string_size(s));
    return lean_io_result_mk_ok(lean_box(0));
}

void *lean_web_set_text(void *id, void *text, void *world) {
    (void)world;
    lean_web_import_dom_set_text(
        lean_web_string_data_ptr(id), lean_web_string_size(id),
        lean_web_string_data_ptr(text), lean_web_string_size(text));
    return lean_io_result_mk_ok(lean_box(0));
}

void *lean_web_set_html(void *id, void *html, void *world) {
    (void)world;
    lean_web_import_dom_set_html(
        lean_web_string_data_ptr(id), lean_web_string_size(id),
        lean_web_string_data_ptr(html), lean_web_string_size(html));
    return lean_io_result_mk_ok(lean_box(0));
}

void *lean_web_get_value(void *id, void *world) {
    (void)world;
    const char *id_ptr = lean_web_string_data_ptr(id);
    uint32_t id_len = lean_web_string_size(id);
    uint32_t len = lean_web_import_dom_get_value_len(id_ptr, id_len);
    if (len == 0) {
        return lean_io_result_mk_ok(lean_mk_string_from_bytes("", 0));
    }
    char *buf = (char *)bump_alloc((size_t)len);
    uint32_t copied = lean_web_import_dom_get_value(id_ptr, id_len, buf, len);
    if (copied > len) copied = len;
    return lean_io_result_mk_ok(lean_mk_string_from_bytes(buf, (size_t)copied));
}

void *lean_web_set_value(void *id, void *value, void *world) {
    (void)world;
    lean_web_import_dom_set_value(
        lean_web_string_data_ptr(id), lean_web_string_size(id),
        lean_web_string_data_ptr(value), lean_web_string_size(value));
    return lean_io_result_mk_ok(lean_box(0));
}

uint32_t lean_web_string_byte_size(void *s) {
    return lean_web_string_size(s);
}

uint32_t lean_web_string_data(void *s) {
    return (uint32_t)(uintptr_t)lean_web_string_data_ptr(s);
}

uint32_t lean_web_alloc_bytes(uint32_t len) {
    return (uint32_t)(uintptr_t)bump_alloc((size_t)len);
}

void *lean_web_mk_string_from_bytes(uint32_t ptr, uint32_t len) {
    return lean_mk_string_from_bytes((const char *)(uintptr_t)ptr, (size_t)len);
}
