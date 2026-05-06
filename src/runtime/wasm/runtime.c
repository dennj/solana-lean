/*
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Embedder shim for wasm32-wasip1: provides `lean_freestanding_log` /
`lean_freestanding_panic` over raw WASI imports (`fd_write`, `proc_exit`),
plus `initialize_Std_Wasm`. The freestanding runtime is reused as-is.
*/

#include <stdint.h>
#include <stddef.h>

typedef struct {
    int      m_rc;
    unsigned m_cs_sz:16;
    unsigned m_other:8;
    unsigned m_tag:8;
} lean_object;

typedef struct {
    lean_object m_header;
    size_t      m_size;
    size_t      m_capacity;
    size_t      m_length;
    char        m_data[];
} lean_string_object;

/* WASI snapshot preview 1 imports — raw, no wasi-libc. The
   __import_module__ / __import_name__ attributes tell wasm-ld which
   namespace + symbol to import from the embedder. */

typedef struct {
    const void *buf;
    uint32_t    buf_len;
} wasi_iovec_t;

__attribute__((import_module("wasi_snapshot_preview1"),
               import_name("fd_write")))
extern uint32_t wasi_fd_write(uint32_t fd, const wasi_iovec_t *iovs,
                              uint32_t iovs_len, uint32_t *out_nwritten);

__attribute__((import_module("wasi_snapshot_preview1"),
               import_name("proc_exit"),
               noreturn))
extern void wasi_proc_exit(uint32_t code);

__attribute__((import_module("wasi_snapshot_preview1"),
               import_name("fd_read")))
extern uint32_t wasi_fd_read(uint32_t fd, const wasi_iovec_t *iovs,
                             uint32_t iovs_len, uint32_t *out_nread);

__attribute__((import_module("wasi_snapshot_preview1"),
               import_name("args_sizes_get")))
extern uint32_t wasi_args_sizes_get(uint32_t *out_argc, uint32_t *out_argv_buf_size);

__attribute__((import_module("wasi_snapshot_preview1"),
               import_name("args_get")))
extern uint32_t wasi_args_get(uint8_t **argv, uint8_t *argv_buf);

/* ===========================================================================
   Embedder hooks for the freestanding runtime
   =========================================================================*/

extern uint64_t lean_strlen(const char *s);

void lean_freestanding_log(const char *msg, uint64_t len) {
    /* Write to stderr (fd 2). One iovec, single buffer. */
    wasi_iovec_t iov = { .buf = msg, .buf_len = (uint32_t)len };
    uint32_t nwritten = 0;
    /* Best-effort; we don't propagate errors here. */
    (void)wasi_fd_write(2, &iov, 1, &nwritten);
}

void lean_freestanding_panic(const char *what, uint64_t a, uint64_t b) {
    /* Format: "<what> a=<a> b=<b>\n" — match the spirit of sbf's
       panic but stay libc-free. We emit `what` as-is, then a fixed
       suffix, then exit non-zero. */
    (void)a; (void)b;
    lean_freestanding_log(what, lean_strlen(what));
    lean_freestanding_log("\n", 1);
    wasi_proc_exit(1);
    __builtin_unreachable();
}

/* ===========================================================================
   Module initialiser: Std.Wasm
   ===========================================================================
   Mirrors `initialize_Std_Solana` — Lean's emit calls this when the
   user program imports `Std.Wasm`. No host-side state; return the
   IO ok sentinel. */

extern void *lean_io_result_mk_ok(void *value);
extern void *lean_box(size_t n);

void *initialize_Std_Wasm(uint8_t builtin, void *world) {
    (void)builtin; (void)world;
    return lean_io_result_mk_ok(lean_box(0));
}

/* ===========================================================================
   Std.Wasm.log (the WASM analogue of Std.Solana.msg)
   ===========================================================================
   Forward a Lean `String` to WASI fd_write on stderr. Same shape as
   `lean_sol_log` in sbf/runtime.c.
*/

/* `Std.Wasm.log : String → BaseIO Unit`. Lean's emit lowers
   `BaseIO Unit` as a one-arg function taking the world token, so the
   full lowered shape of this opaque is `void *(s, world)`: write the
   bytes, then return `IO.Result.ok ()`. The world arg is opaque to
   us and ignored. */
void *lean_wasm_log(void *s, void *world) {
    (void)world;
    lean_string_object *str = (lean_string_object *)s;
    uint64_t bytes = str->m_size > 0 ? str->m_size - 1 : 0;
    lean_freestanding_log(str->m_data, bytes);
    lean_freestanding_log("\n", 1);
    return lean_io_result_mk_ok(lean_box(0));
}

static void wasm_write_to_fd(uint32_t fd, const char *data, uint32_t len) {
    wasi_iovec_t iov = { .buf = data, .buf_len = len };
    uint32_t nwritten = 0;
    (void)wasi_fd_write(fd, &iov, 1, &nwritten);
}

void *lean_wasm_print(void *s, void *world) {
    (void)world;
    lean_string_object *str = (lean_string_object *)s;
    uint32_t bytes = str->m_size > 0 ? (uint32_t)(str->m_size - 1) : 0;
    wasm_write_to_fd(1, str->m_data, bytes);
    return lean_io_result_mk_ok(lean_box(0));
}

extern void *lean_freestanding_make_byte_array(const uint8_t *data, size_t len);

void *lean_wasm_read_stdin(size_t cap, void *world) {
    (void)world;
    if (cap == 0) {
        return lean_io_result_mk_ok(lean_freestanding_make_byte_array((const uint8_t *)"", 0));
    }
    /* Bounded scratch buffer; bigger reads can be issued in a loop by the
       caller. 4 KiB matches the wasm32 default page size. */
    uint8_t buf[4096];
    if (cap > sizeof(buf)) cap = sizeof(buf);
    wasi_iovec_t iov = { .buf = buf, .buf_len = (uint32_t)cap };
    uint32_t nread = 0;
    (void)wasi_fd_read(0, &iov, 1, &nread);
    return lean_io_result_mk_ok(lean_freestanding_make_byte_array(buf, nread));
}

extern uint64_t lean_strlen(const char *s);
extern void *lean_mk_string_from_bytes(const char *s, size_t sz);

static uint8_t  wasm_argv_buf[4096];
static uint8_t *wasm_argv[256];
static uint32_t wasm_argc_cached = 0;
static int      wasm_args_loaded = 0;

static void wasm_load_args_once(void) {
    if (wasm_args_loaded) return;
    wasm_args_loaded = 1;
    uint32_t argc = 0;
    uint32_t buf_size = 0;
    if (wasi_args_sizes_get(&argc, &buf_size) != 0) return;
    if (argc > 256) argc = 256;
    if (buf_size > sizeof(wasm_argv_buf)) return;
    if (wasi_args_get(wasm_argv, wasm_argv_buf) != 0) return;
    wasm_argc_cached = argc;
}

void *lean_wasm_argc(void *unit, void *world) {
    (void)unit; (void)world;
    wasm_load_args_once();
    return lean_io_result_mk_ok(lean_box((size_t)wasm_argc_cached));
}

void *lean_wasm_arg(size_t idx, void *world) {
    (void)world;
    wasm_load_args_once();
    if (idx >= wasm_argc_cached) {
        return lean_io_result_mk_ok(lean_mk_string_from_bytes("", 0));
    }
    const char *s = (const char *)wasm_argv[idx];
    return lean_io_result_mk_ok(lean_mk_string_from_bytes(s, lean_strlen(s)));
}

void *lean_wasm_exit(uint32_t code, void *world) {
    (void)world;
    wasi_proc_exit(code);
    __builtin_unreachable();
}
