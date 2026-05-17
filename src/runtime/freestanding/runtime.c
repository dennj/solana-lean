/*
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Freestanding subset of the Lean runtime for cross-compile targets that
ship without libc and without the host's `lean.h.bc` runtime: bump
allocator, single-threaded refcount metadata, boxing primitives, ctor allocation/accessors,
IO-result wrappers, strings, arrays, scalar arrays, and a bounded
small-Nat / Int subset.

This file is shared across all freestanding cross-compile targets.
Target-specific embedder code (syscalls, entrypoint, panic / log routing,
heap layout constants) lives under `src/runtime/<target>/`, with one
sibling per target. Each adapter provides the `lean_freestanding_*`
externs declared below.

Embedder configuration. Each consuming target must supply heap layout
via one of:

  LEAN_FREESTANDING_HEAP_SYMBOLS enable linker-symbol heap layout:
                                 __lean_heap_start / __lean_heap_end
                                 (HEAP_PREFIX defaults to 8 in this mode)
  LEAN_FREESTANDING_HEAP_BASE    base virtual address of the heap region
  LEAN_FREESTANDING_HEAP_BYTES   size of the heap region in bytes
  LEAN_FREESTANDING_HEAP_PREFIX  bytes reserved at the start for embedder
                                 metadata; bump-pointer occupies [0..8).
                                 Must be >= 8.

This file has no built-in defaults: at least one of HEAP_SYMBOLS or the
explicit BASE/BYTES/PREFIX triple must be defined at compile time.
*/

#include <stdint.h>
#include <stddef.h>
#include "lean_freestanding.h"

#ifdef LEAN_FREESTANDING_HEAP_SYMBOLS
extern char __lean_heap_start[];
extern char __lean_heap_end[];
#ifndef LEAN_FREESTANDING_HEAP_BASE
#define LEAN_FREESTANDING_HEAP_BASE ((uintptr_t)__lean_heap_start)
#endif
#ifndef LEAN_FREESTANDING_HEAP_BYTES
#define LEAN_FREESTANDING_HEAP_BYTES ((uintptr_t)__lean_heap_end - (uintptr_t)__lean_heap_start)
#endif
#ifndef LEAN_FREESTANDING_HEAP_PREFIX
#define LEAN_FREESTANDING_HEAP_PREFIX 8
#endif
#endif

#if !defined(LEAN_FREESTANDING_HEAP_BASE) || \
    !defined(LEAN_FREESTANDING_HEAP_BYTES) || \
    !defined(LEAN_FREESTANDING_HEAP_PREFIX)
#error "freestanding/runtime.c: target must define LEAN_FREESTANDING_HEAP_{BASE,BYTES,PREFIX} (or LEAN_FREESTANDING_HEAP_SYMBOLS) — see file header for details"
#endif

/* Embedder-provided diagnostics. The freestanding runtime never calls
   libc panics directly; all fatal paths go through the embedder so the
   target's panic semantics (e.g. `sol_panic_` on SBF, kernel oops on a
   kernel target) are preserved. */
extern void lean_freestanding_panic(const char *what, uint64_t a, uint64_t b);
extern void lean_freestanding_log(const char *msg, uint64_t len);

#define LEAN_FREESTANDING_MAX_SMALL_NAT ((uint64_t)((uintptr_t)-1 >> 1))
static void lean_freestanding_nat_panic(const char *what);
static int  lean_freestanding_is_scalar(void *o);
void *lean_box_uint32(uint32_t v);

uint64_t lean_strlen(const char *s) {
    uint64_t n = 0;
    while (s[n]) ++n;
    return n;
}

typedef struct {
    lean_object   m_header;
    void *        m_fun;
    uint16_t      m_arity;
    uint16_t      m_num_fixed;
    lean_object * m_objs[];
} lean_closure_object;

#define LEAN_MAX_CTOR_TAG 244
#define LEAN_TAG_CLOSURE 245

/* ===========================================================================
   libc-free `mem*` primitives
   ===========================================================================
   Clang lowers byte-copy / fill loops to `memcpy` / `memset` calls under
   `-O2`. Restricted-runtime targets typically don't link libc, so we
   provide trivial loop-based versions ourselves. They are intentionally
   simple (one byte per iteration); micro-optimising memmoves is a polish
   concern, not a correctness one.
*/

void *memcpy(void *dst, const void *src, size_t n) {
    char *d = (char *)dst;
    const char *s = (const char *)src;
    for (size_t i = 0; i < n; ++i) d[i] = s[i];
    return dst;
}

void *memset(void *dst, int c, size_t n) {
    char *d = (char *)dst;
    for (size_t i = 0; i < n; ++i) d[i] = (char)c;
    return dst;
}

void *memmove(void *dst, const void *src, size_t n) {
    char *d = (char *)dst;
    const char *s = (const char *)src;
    if (d < s || d >= s + n) {
        for (size_t i = 0; i < n; ++i) d[i] = s[i];
    } else {
        for (size_t i = n; i > 0; --i) d[i - 1] = s[i - 1];
    }
    return dst;
}

/* ===========================================================================
   Bump allocator over the embedder-supplied heap region
   ===========================================================================
   The embedder reserves a heap region at [HEAP_BASE, HEAP_BASE+HEAP_BYTES).
   Bytes [0..8) of the heap hold the bump-pointer cursor; [8..PREFIX) is
   embedder metadata (e.g. on SBF: loader-input pointer at [8..16),
   account-table pointer at [16..24)).

   Restricted-runtime targets typically zero-initialise the heap on every
   program invocation, so the first allocation observes `*bp == 0` and
   primes the cursor past the prefix.
*/

#define LEAN_FREESTANDING_HEAP_END (LEAN_FREESTANDING_HEAP_BASE + LEAN_FREESTANDING_HEAP_BYTES)

uintptr_t *lean_freestanding_bump_pointer_storage(void) {
    return (uintptr_t *)LEAN_FREESTANDING_HEAP_BASE;
}

void *bump_alloc(size_t size) {
    uintptr_t *bp = lean_freestanding_bump_pointer_storage();
    if (*bp == 0) {
        *bp = LEAN_FREESTANDING_HEAP_BASE + LEAN_FREESTANDING_HEAP_PREFIX;
    }
    /* 8-byte alignment is sufficient for all Lean object types. */
    size_t aligned = (size + 7) & ~(size_t)7;
    if (*bp + aligned > LEAN_FREESTANDING_HEAP_END) {
        const char *m = "lean-freestanding: heap exhausted";
        lean_freestanding_log(m, lean_strlen(m));
        lean_freestanding_panic("oom", 0, 0);
        __builtin_unreachable();
    }
    void *p = (void *)*bp;
    *bp += aligned;
    return p;
}

/* ===========================================================================
   Allocation primitives
   =========================================================================*/

/* Mirrors lean.h's malloc-path layout: 8-byte size word before the object so
   `lean_small_mem_size` can recover it. */
void *lean_alloc_object(size_t sz) {
    size_t *p = (size_t *)bump_alloc(sizeof(size_t) + sz);
    *p = sz;
    return p + 1;
}

void *lean_alloc_small(unsigned sz, unsigned slot_idx) {
    (void)slot_idx;
    return bump_alloc(sz);
}

void lean_free_small(void *p) { (void)p; }

unsigned lean_small_mem_size(void *p) {
    return (unsigned)*((size_t *)p - 1);
}

void lean_inc_heartbeat(void) { /* no-op: restricted targets enforce compute budget externally */ }

/* ===========================================================================
   Pointer-tagged scalars
   =========================================================================*/

void *lean_box(size_t n) {
    return (void *)((n << 1) | 1);
}

uint64_t lean_unbox(void *o) {
    return ((uintptr_t)o) >> 1;
}

/* ===========================================================================
   Boxed UInt64
   =========================================================================*/

void *lean_box_uint64(uint64_t v) {
    /* Ctor with 0 obj fields and 8 bytes of scalar storage. */
    lean_object *o = (lean_object *)bump_alloc(sizeof(lean_ctor_object) + sizeof(uint64_t));
    o->m_rc = 1;
    o->m_cs_sz = 0;
    o->m_other = 0;
    o->m_tag = 0;
    *(uint64_t *)((char *)o + sizeof(lean_ctor_object)) = v;
    return o;
}

uint64_t lean_unbox_uint64(void *o) {
    return *(uint64_t *)((char *)o + sizeof(lean_ctor_object));
}

/* ===========================================================================
   Ctor allocation and accessors
   =========================================================================*/

void *lean_alloc_ctor(unsigned tag, unsigned num_objs, unsigned scalar_sz) {
    size_t sz = sizeof(lean_ctor_object) + sizeof(void *) * num_objs + scalar_sz;
    lean_object *o = (lean_object *)bump_alloc(sz);
    o->m_rc = 1;
    o->m_cs_sz = 0;
    o->m_other = (unsigned)(num_objs & 0xFF);
    o->m_tag = (unsigned)(tag & 0xFF);
    return o;
}

void *lean_ctor_get(void *o, unsigned i) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    return c->m_objs[i];
}

void lean_ctor_set(void *o, unsigned i, void *v) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    c->m_objs[i] = (lean_object *)v;
}

void lean_ctor_set_tag(void *o, unsigned tag) {
    ((lean_object *)o)->m_tag = (unsigned)(tag & 0xFF);
}

/* Scalar-field offsets match lean.h: byte offsets from m_objs. */
uint64_t lean_ctor_get_uint64(void *o, unsigned offset) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    return *(uint64_t *)((char *)c->m_objs + offset);
}

void lean_ctor_set_uint64(void *o, unsigned offset, uint64_t v) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    *(uint64_t *)((char *)c->m_objs + offset) = v;
}

uint32_t lean_ctor_get_uint32(void *o, unsigned offset) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    return *(uint32_t *)((char *)c->m_objs + offset);
}

void lean_ctor_set_uint32(void *o, unsigned offset, uint32_t v) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    *(uint32_t *)((char *)c->m_objs + offset) = v;
}

uint16_t lean_ctor_get_uint16(void *o, unsigned offset) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    return *(uint16_t *)((char *)c->m_objs + offset);
}

void lean_ctor_set_uint16(void *o, unsigned offset, uint16_t v) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    *(uint16_t *)((char *)c->m_objs + offset) = v;
}

uint8_t lean_ctor_get_uint8(void *o, unsigned offset) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    return *(uint8_t *)((char *)c->m_objs + offset);
}

void lean_ctor_set_uint8(void *o, unsigned offset, uint8_t v) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    *(uint8_t *)((char *)c->m_objs + offset) = v;
}

unsigned lean_obj_tag(void *o) {
    if ((uintptr_t)o & 1) {
        /* Tag-encoded scalar: low bit set. The "tag" of a boxed Nat-like
           scalar is the unboxed value itself. */
        return (unsigned)((uintptr_t)o >> 1);
    }
    return ((lean_object *)o)->m_tag;
}

/* ===========================================================================
   Reference counting
   ===========================================================================
   Freestanding targets still use a bump allocator, so unreachable objects are
   not returned to the heap. We nevertheless maintain Lean's single-threaded RC
   metadata and recursively drop owned references when an object's RC reaches
   zero. This preserves the ownership/exclusivity invariant used by generated
   code for copy-on-write arrays, byte arrays, and future linear structures.
*/

static void lean_freestanding_dec_ref_cold(void *o);
static void lean_freestanding_mark_persistent_rec(void *o);

uint8_t lean_is_scalar(void *o) {
    return lean_freestanding_is_scalar(o) ? 1 : 0;
}

void lean_inc_ref_n(void *o, size_t n) {
    if (o == 0 || n == 0) return;
    lean_object *obj = (lean_object *)o;
    if (obj->m_rc > 0) obj->m_rc += (int)n;
}

void lean_inc_ref(void *o) {
    lean_inc_ref_n(o, 1);
}

void lean_inc_n(void *o, size_t n) {
    if (!lean_freestanding_is_scalar(o)) lean_inc_ref_n(o, n);
}

void lean_inc(void *o) {
    if (!lean_freestanding_is_scalar(o)) lean_inc_ref(o);
}

void lean_dec_ref(void *o) {
    if (o == 0) return;
    lean_object *obj = (lean_object *)o;
    if (obj->m_rc > 1) {
        obj->m_rc--;
    } else if (obj->m_rc == 1) {
        lean_freestanding_dec_ref_cold(o);
    }
}

void lean_dec(void *o) {
    if (!lean_freestanding_is_scalar(o)) lean_dec_ref(o);
}

void lean_mark_persistent(void *o) {
    if (o != 0 && !lean_freestanding_is_scalar(o)) lean_freestanding_mark_persistent_rec(o);
}

uint8_t lean_is_exclusive(void *o) {
    if (o == 0) return 0;
    if (lean_freestanding_is_scalar(o)) return 0;
    return ((lean_object *)o)->m_rc == 1;
}

uint8_t lean_is_exclusive_obj(void *o) {
    return lean_is_exclusive(o);
}

uint8_t lean_is_shared(void *o) {
    if (o == 0) return 0;
    if (lean_freestanding_is_scalar(o)) return 0;
    return ((lean_object *)o)->m_rc > 1;
}

void lean_del_object(void *o) { (void)o; }

static void lean_freestanding_dec_ref_cold(void *o) {
    lean_object *obj = (lean_object *)o;
    obj->m_rc = 0;
    if (obj->m_tag <= LEAN_MAX_CTOR_TAG) {
        lean_ctor_object *c = (lean_ctor_object *)o;
        for (unsigned i = 0; i < obj->m_other; ++i) lean_dec(c->m_objs[i]);
    } else if (obj->m_tag == LEAN_TAG_ARRAY) {
        lean_array_object *a = (lean_array_object *)o;
        for (size_t i = 0; i < a->m_size; ++i) lean_dec(a->m_data[i]);
    } else if (obj->m_tag == LEAN_TAG_CLOSURE) {
        lean_closure_object *c = (lean_closure_object *)o;
        for (uint16_t i = 0; i < c->m_num_fixed; ++i) lean_dec(c->m_objs[i]);
    }
}

static void lean_freestanding_mark_persistent_rec(void *o) {
    lean_object *obj = (lean_object *)o;
    if (obj->m_rc == 0) return;
    obj->m_rc = 0;
    if (obj->m_tag <= LEAN_MAX_CTOR_TAG) {
        lean_ctor_object *c = (lean_ctor_object *)o;
        for (unsigned i = 0; i < obj->m_other; ++i) {
            if (!lean_freestanding_is_scalar(c->m_objs[i])) {
                lean_freestanding_mark_persistent_rec(c->m_objs[i]);
            }
        }
    } else if (obj->m_tag == LEAN_TAG_ARRAY) {
        lean_array_object *a = (lean_array_object *)o;
        for (size_t i = 0; i < a->m_size; ++i) {
            if (!lean_freestanding_is_scalar(a->m_data[i])) {
                lean_freestanding_mark_persistent_rec(a->m_data[i]);
            }
        }
    } else if (obj->m_tag == LEAN_TAG_CLOSURE) {
        lean_closure_object *c = (lean_closure_object *)o;
        for (uint16_t i = 0; i < c->m_num_fixed; ++i) {
            if (!lean_freestanding_is_scalar(c->m_objs[i])) {
                lean_freestanding_mark_persistent_rec(c->m_objs[i]);
            }
        }
    }
}

/* ===========================================================================
   IO result types
   ===========================================================================
   IO results are tagged ctor objects: tag 0 = ok (with one object payload),
   tag 1 = error. `lean_io_mk_world` returns a sentinel pointer; the world
   token is opaque to user code.
*/

void *lean_io_mk_world(void) {
    return lean_box(0);
}

void *lean_io_result_mk_ok(void *value) {
    void *r = lean_alloc_ctor(0, 1, 0);
    lean_ctor_set(r, 0, value);
    return r;
}

uint8_t lean_io_result_is_error(void *o) {
    return ((lean_object *)o)->m_tag != 0;
}

uint8_t lean_io_result_is_ok(void *o) {
    return ((lean_object *)o)->m_tag == 0;
}

void lean_io_mark_end_initialization(void) { /* no-op */ }

/* ===========================================================================
   Module initialiser: Init
   ===========================================================================
   `initialize_Init` is Lean's stdlib `Init` module initialiser. On the host
   it sets up panic-message handling, task manager, etc. — none of which
   apply on restricted-runtime targets. We surface a successful IO result
   so any user-module initialiser chain (`initialize_<UserMod>` →
   `initialize_Init`) sees a clean result.
*/

/* Lean's emit calls module initialisers as `initialize_<Mod>(uint8_t
   builtin, void *io_world)` and expects an IO-result-shaped return.
   The second argument is the world token, opaque to us. */
void *initialize_Init(uint8_t builtin, void *world) {
    (void)builtin; (void)world;
    return lean_io_result_mk_ok(lean_box(0));
}

/* Implicit deny-list import injected by `--target=...`; the module is
   pure data (env-extension entries) so its module-init has nothing to do. */
void *initialize_Std_Freestanding_Unsupported(uint8_t builtin, void *world) {
    (void)builtin; (void)world;
    return lean_io_result_mk_ok(lean_box(0));
}

#define LEAN_FREESTANDING_MAX_CLOSURE_ARITY 8

void *lean_alloc_closure(void *fun, unsigned arity, unsigned num_fixed) {
    if (arity > LEAN_FREESTANDING_MAX_CLOSURE_ARITY) {
        lean_freestanding_panic("closure arity exceeds freestanding cap (8)",
                                arity, 0);
        __builtin_unreachable();
    }
    size_t sz = sizeof(lean_closure_object) + sizeof(void *) * arity;
    lean_closure_object *c = (lean_closure_object *)bump_alloc(sz);
    c->m_header.m_rc = 1;
    c->m_header.m_cs_sz = 0;
    c->m_header.m_other = 0;
    c->m_header.m_tag = LEAN_TAG_CLOSURE;
    c->m_fun = fun;
    c->m_arity = (uint16_t)arity;
    c->m_num_fixed = (uint16_t)num_fixed;
    for (unsigned i = 0; i < arity; ++i) c->m_objs[i] = (lean_object *)0;
    return c;
}

void lean_closure_set(void *c, unsigned i, void *v) {
    ((lean_closure_object *)c)->m_objs[i] = (lean_object *)v;
}

void *lean_closure_get(void *c, unsigned i) {
    return ((lean_closure_object *)c)->m_objs[i];
}

uint32_t lean_closure_arity(void *c) {
    return (uint32_t)((lean_closure_object *)c)->m_arity;
}

uint32_t lean_closure_num_fixed(void *c) {
    return (uint32_t)((lean_closure_object *)c)->m_num_fixed;
}

typedef void *(*lean_fn1)(void *);
typedef void *(*lean_fn2)(void *, void *);
typedef void *(*lean_fn3)(void *, void *, void *);
typedef void *(*lean_fn4)(void *, void *, void *, void *);
typedef void *(*lean_fn5)(void *, void *, void *, void *, void *);
typedef void *(*lean_fn6)(void *, void *, void *, void *, void *, void *);
typedef void *(*lean_fn7)(void *, void *, void *, void *, void *, void *, void *);
typedef void *(*lean_fn8)(void *, void *, void *, void *, void *, void *, void *, void *);

static void *lean_freestanding_invoke(lean_closure_object *c) {
    void * const *xs = (void * const *)c->m_objs;
    switch (c->m_arity) {
    case 1: return ((lean_fn1)c->m_fun)(xs[0]);
    case 2: return ((lean_fn2)c->m_fun)(xs[0], xs[1]);
    case 3: return ((lean_fn3)c->m_fun)(xs[0], xs[1], xs[2]);
    case 4: return ((lean_fn4)c->m_fun)(xs[0], xs[1], xs[2], xs[3]);
    case 5: return ((lean_fn5)c->m_fun)(xs[0], xs[1], xs[2], xs[3], xs[4]);
    case 6: return ((lean_fn6)c->m_fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5]);
    case 7: return ((lean_fn7)c->m_fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6]);
    case 8: return ((lean_fn8)c->m_fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6], xs[7]);
    default:
        lean_freestanding_panic("invalid closure arity", c->m_arity, 0);
        __builtin_unreachable();
    }
}

static void *lean_freestanding_extend(lean_closure_object *c, unsigned new_args,
                                      void * const *args) {
    unsigned total = c->m_num_fixed + new_args;
    void *nc = lean_alloc_closure(c->m_fun, c->m_arity, total);
    lean_closure_object *ec = (lean_closure_object *)nc;
    for (unsigned i = 0; i < c->m_num_fixed; ++i) ec->m_objs[i] = c->m_objs[i];
    for (unsigned i = 0; i < new_args; ++i)
        ec->m_objs[c->m_num_fixed + i] = (lean_object *)args[i];
    return nc;
}

static void *lean_freestanding_apply(void *c, unsigned new_args, void * const *args) {
    lean_closure_object *cl = (lean_closure_object *)c;
    unsigned needed = cl->m_arity - cl->m_num_fixed;
    if (new_args < needed) {
        return lean_freestanding_extend(cl, new_args, args);
    }
    void *nc = lean_alloc_closure(cl->m_fun, cl->m_arity, cl->m_arity);
    lean_closure_object *fc = (lean_closure_object *)nc;
    for (unsigned i = 0; i < cl->m_num_fixed; ++i) fc->m_objs[i] = cl->m_objs[i];
    for (unsigned i = 0; i < needed; ++i)
        fc->m_objs[cl->m_num_fixed + i] = (lean_object *)args[i];
    void *result = lean_freestanding_invoke(fc);
    if (new_args > needed) {
        return lean_freestanding_apply(result, new_args - needed, args + needed);
    }
    return result;
}

void *lean_apply_1(void *c, void *a1) {
    void *args[1] = { a1 };
    return lean_freestanding_apply(c, 1, args);
}
void *lean_apply_2(void *c, void *a1, void *a2) {
    void *args[2] = { a1, a2 };
    return lean_freestanding_apply(c, 2, args);
}
void *lean_apply_3(void *c, void *a1, void *a2, void *a3) {
    void *args[3] = { a1, a2, a3 };
    return lean_freestanding_apply(c, 3, args);
}
void *lean_apply_4(void *c, void *a1, void *a2, void *a3, void *a4) {
    void *args[4] = { a1, a2, a3, a4 };
    return lean_freestanding_apply(c, 4, args);
}
void *lean_apply_5(void *c, void *a1, void *a2, void *a3, void *a4, void *a5) {
    void *args[5] = { a1, a2, a3, a4, a5 };
    return lean_freestanding_apply(c, 5, args);
}
void *lean_apply_6(void *c, void *a1, void *a2, void *a3, void *a4, void *a5,
                   void *a6) {
    void *args[6] = { a1, a2, a3, a4, a5, a6 };
    return lean_freestanding_apply(c, 6, args);
}
void *lean_apply_7(void *c, void *a1, void *a2, void *a3, void *a4, void *a5,
                   void *a6, void *a7) {
    void *args[7] = { a1, a2, a3, a4, a5, a6, a7 };
    return lean_freestanding_apply(c, 7, args);
}
void *lean_apply_8(void *c, void *a1, void *a2, void *a3, void *a4, void *a5,
                   void *a6, void *a7, void *a8) {
    void *args[8] = { a1, a2, a3, a4, a5, a6, a7, a8 };
    return lean_freestanding_apply(c, 8, args);
}

void *l_List_lengthTR___redArg(void *xs) {
    size_t n = 0;
    while (1) {
        if ((uintptr_t)xs & 1u) break;
        lean_object *o = (lean_object *)xs;
        if (o->m_tag == 0) break;
        n += 1;
        xs = ((lean_ctor_object *)o)->m_objs[1];
    }
    return lean_box(n);
}

void *l_outOfBounds___redArg(void *def) {
    return def;
}

void *lean_cstr_to_nat(const char *s) {
    uint64_t n = 0;
    while (*s) {
        char c = *s++;
        if (c < '0' || c > '9') {
            lean_freestanding_nat_panic("lean-freestanding: cstr_to_nat: non-digit");
        }
        uint64_t d = (uint64_t)(c - '0');
        if (n > (LEAN_FREESTANDING_MAX_SMALL_NAT - d) / 10) {
            lean_freestanding_nat_panic("lean-freestanding: cstr_to_nat: exceeds small-Nat cap");
        }
        n = n * 10 + d;
    }
    return lean_box((size_t)n);
}

uint8_t  _init_l_instInhabitedUInt8(void)  { return 0; }
uint16_t _init_l_instInhabitedUInt16(void) { return 0; }
uint32_t _init_l_instInhabitedUInt32(void) { return 0; }
uint64_t _init_l_instInhabitedUInt64(void) { return 0; }

/* Solana SBF rejects programs with any writable section (.data/.bss),
 * so we cannot use a writable file-scope static as a lazy cache here.
 * Always allocate a fresh empty `ByteArray` from the bump heap; the
 * heap is per-invocation in freestanding targets, so caching across
 * calls would not even compose. */
void *_init_l_ByteArray_empty(void) {
    lean_sarray_object *o = (lean_sarray_object *)lean_alloc_object(
        sizeof(lean_sarray_object));
    o->m_header.m_rc = 1;
    o->m_header.m_cs_sz = 0;
    o->m_header.m_other = 1;
    o->m_header.m_tag = LEAN_TAG_SCALAR_ARRAY;
    o->m_size = 0;
    o->m_capacity = 0;
    return (void *)o;
}

/* ===========================================================================
   Strings
   ===========================================================================
   Lean strings are UTF-8 byte buffers with a separately-tracked character
   count. String literals in user code are emitted as static `lean_string_object`
   instances by Lean (with `m_rc = 0` so they're treated as non-heap), so the
   runtime only needs to handle dynamic construction and modification.
*/

/* Count UTF-8 code points in a NUL-terminated buffer of `n` bytes (excluding
   the terminator). Bytes whose top two bits are `10` are continuation bytes
   and don't count. */
static size_t lean_freestanding_utf8_strlen(const char *s, size_t n) {
    size_t count = 0;
    for (size_t i = 0; i < n; ++i) {
        if (((unsigned char)s[i] & 0xC0) != 0x80) ++count;
    }
    return count;
}

static lean_string_object *lean_freestanding_alloc_string(size_t size, size_t capacity, size_t len) {
    lean_string_object *o = (lean_string_object *)lean_alloc_object(sizeof(lean_string_object) + capacity);
    o->m_header.m_rc = 1;
    o->m_header.m_cs_sz = 0;
    o->m_header.m_other = 0;
    o->m_header.m_tag = LEAN_TAG_STRING;
    o->m_size = size;
    o->m_capacity = capacity;
    o->m_length = len;
    return o;
}

void *lean_mk_string_unchecked(const char *s, size_t sz, size_t len) {
    /* `sz` is the byte length without the terminator; on-disk layout
       reserves sz+1 bytes including the trailing NUL, matching the
       host runtime's convention. */
    size_t capacity = sz + 1;
    lean_string_object *o = lean_freestanding_alloc_string(sz + 1, capacity, len);
    for (size_t i = 0; i < sz; ++i) o->m_data[i] = s[i];
    o->m_data[sz] = '\0';
    return o;
}

void *lean_mk_string_from_bytes_unchecked(const char *s, size_t sz) {
    return lean_mk_string_unchecked(s, sz, lean_freestanding_utf8_strlen(s, sz));
}

void *lean_mk_string_from_bytes(const char *s, size_t sz) {
    /* The "checked" version normally validates UTF-8; for restricted
       runtimes we accept the bytes as-is (programs constructing
       malformed UTF-8 either know what they're doing or will surface
       the issue at use). */
    return lean_mk_string_from_bytes_unchecked(s, sz);
}

void *lean_mk_string(const char *s) {
    size_t sz = 0;
    while (s[sz]) ++sz;
    return lean_mk_string_from_bytes_unchecked(s, sz);
}

void *lean_mk_ascii_string_unchecked(const char *s) {
    size_t sz = 0;
    while (s[sz]) ++sz;
    return lean_mk_string_unchecked(s, sz, sz);
}

/* Encode a Unicode code point as UTF-8 into `dst`. Returns byte count. */
static unsigned lean_freestanding_utf8_encode(uint32_t c, char dst[4]) {
    if (c < 0x80) {
        dst[0] = (char)c;
        return 1;
    } else if (c < 0x800) {
        dst[0] = (char)(0xC0 | (c >> 6));
        dst[1] = (char)(0x80 | (c & 0x3F));
        return 2;
    } else if (c < 0x10000) {
        dst[0] = (char)(0xE0 | (c >> 12));
        dst[1] = (char)(0x80 | ((c >> 6) & 0x3F));
        dst[2] = (char)(0x80 | (c & 0x3F));
        return 3;
    } else {
        dst[0] = (char)(0xF0 | (c >> 18));
        dst[1] = (char)(0x80 | ((c >> 12) & 0x3F));
        dst[2] = (char)(0x80 | ((c >> 6) & 0x3F));
        dst[3] = (char)(0x80 | (c & 0x3F));
        return 4;
    }
}

void *lean_string_push(void *s, uint32_t c) {
    lean_string_object *src = (lean_string_object *)s;
    char encoded[4];
    unsigned enc_len = lean_freestanding_utf8_encode(c, encoded);
    /* old m_size includes the '\0' terminator; new payload is
       (m_size - 1) old bytes + enc_len new bytes + '\0'. */
    size_t old_payload = src->m_size - 1;
    size_t new_payload = old_payload + enc_len;
    lean_string_object *dst = lean_freestanding_alloc_string(new_payload + 1, new_payload + 1,
                                                             src->m_length + 1);
    for (size_t i = 0; i < old_payload; ++i) dst->m_data[i] = src->m_data[i];
    for (unsigned i = 0; i < enc_len; ++i) dst->m_data[old_payload + i] = encoded[i];
    dst->m_data[new_payload] = '\0';
    return dst;
}

void *lean_string_append(void *s1, void *s2) {
    lean_string_object *a = (lean_string_object *)s1;
    lean_string_object *b = (lean_string_object *)s2;
    size_t a_payload = a->m_size - 1;
    size_t b_payload = b->m_size - 1;
    size_t total_payload = a_payload + b_payload;
    lean_string_object *dst = lean_freestanding_alloc_string(total_payload + 1, total_payload + 1,
                                                             a->m_length + b->m_length);
    for (size_t i = 0; i < a_payload; ++i) dst->m_data[i] = a->m_data[i];
    for (size_t i = 0; i < b_payload; ++i) dst->m_data[a_payload + i] = b->m_data[i];
    dst->m_data[total_payload] = '\0';
    return dst;
}

/* `String.length s` on the host inlines to `lean_box(m_length)` from
   `lean.h`. Lean's bitcode emit bypasses that inlining when the callee
   is an `@[extern]` or referenced through a non-inlined path, so we
   provide an extern equivalent here. Returns the boxed character count
   (m_length, not m_size — the latter is the byte length including the
   trailing NUL). */
void *lean_string_length(void *s) {
    lean_string_object *str = (lean_string_object *)s;
    return lean_box(str->m_length);
}

static void *lean_freestanding_string_data_helper(const char *p, const char *end) {
    if (p >= end) {
        return lean_alloc_ctor(0, 0, 0);
    }
    uint32_t cp;
    unsigned len;
    unsigned char c0 = (unsigned char)*p;
    if (c0 < 0x80) {
        cp = c0; len = 1;
    } else if (c0 < 0xC0) {
        cp = 0xFFFD; len = 1;
    } else if (c0 < 0xE0) {
        cp = ((c0 & 0x1F) << 6) | ((unsigned char)p[1] & 0x3F);
        len = 2;
    } else if (c0 < 0xF0) {
        cp = ((c0 & 0x0F) << 12) |
             (((unsigned char)p[1] & 0x3F) << 6) |
             ((unsigned char)p[2] & 0x3F);
        len = 3;
    } else {
        cp = ((c0 & 0x07) << 18) |
             (((unsigned char)p[1] & 0x3F) << 12) |
             (((unsigned char)p[2] & 0x3F) << 6) |
             ((unsigned char)p[3] & 0x3F);
        len = 4;
    }
    void *tail = lean_freestanding_string_data_helper(p + len, end);
    void *head = lean_box_uint32(cp);
    void *cons = lean_alloc_ctor(1, 2, 0);
    lean_ctor_set(cons, 0, head);
    lean_ctor_set(cons, 1, tail);
    return cons;
}

void *lean_string_data(void *s) {
    lean_string_object *str = (lean_string_object *)s;
    size_t payload = str->m_size == 0 ? 0 : str->m_size - 1;
    return lean_freestanding_string_data_helper(str->m_data, str->m_data + payload);
}

uint8_t lean_string_validate_utf8(void *bytes) {
    lean_sarray_object *ba = (lean_sarray_object *)bytes;
    size_t i = 0;
    while (i < ba->m_size) {
        unsigned char c = ba->m_data[i];
        unsigned cont;
        if (c < 0x80)        cont = 0;
        else if (c < 0xC0)   return 0;
        else if (c < 0xE0)   cont = 1;
        else if (c < 0xF0)   cont = 2;
        else if (c < 0xF8)   cont = 3;
        else                 return 0;
        if (i + cont >= ba->m_size) return 0;
        for (unsigned k = 1; k <= cont; ++k) {
            if ((ba->m_data[i + k] & 0xC0) != 0x80) return 0;
        }
        i += 1 + cont;
    }
    return 1;
}

void *lean_string_from_utf8_unchecked(void *bytes) {
    lean_sarray_object *ba = (lean_sarray_object *)bytes;
    return lean_mk_string_from_bytes_unchecked((const char *)ba->m_data, ba->m_size);
}

/* ===========================================================================
   Trivially-correct scalar helpers
   ===========================================================================
   These are the generic-arithmetic and bit-twiddling operations that
   Lean's emit lowers to extern calls. They have no allocation, no
   panic path, and are identical across every freestanding target —
   moved here from `sbf/stubs.c` so the WASM, eBPF, kernel, etc. ports
   pick them up automatically without duplication.
*/

uint64_t lean_uint64_add(uint64_t a, uint64_t b) { return a + b; }
uint64_t lean_uint64_sub(uint64_t a, uint64_t b) { return a - b; }
uint64_t lean_uint64_mul(uint64_t a, uint64_t b) { return a * b; }
uint64_t lean_uint64_div(uint64_t a, uint64_t b) { return b == 0 ? 0 : a / b; }
uint64_t lean_uint64_mod(uint64_t a, uint64_t b) { return b == 0 ? a : a % b; }
uint64_t lean_uint64_xor(uint64_t a, uint64_t b) { return a ^ b; }
uint64_t lean_uint64_lor(uint64_t a, uint64_t b) { return a | b; }
uint64_t lean_uint64_land(uint64_t a, uint64_t b) { return a & b; }
uint64_t lean_uint64_shift_left(uint64_t a, uint64_t b) { return a << (b & 63); }
uint64_t lean_uint64_shift_right(uint64_t a, uint64_t b) { return a >> (b & 63); }
uint8_t  lean_uint64_dec_eq(uint64_t a, uint64_t b) { return a == b; }
uint8_t  lean_uint64_dec_lt(uint64_t a, uint64_t b) { return a < b; }
uint8_t  lean_uint64_dec_le(uint64_t a, uint64_t b) { return a <= b; }
uint8_t  lean_uint64_to_uint8(uint64_t a) { return (uint8_t)a; }
uint64_t lean_uint8_to_uint64(uint8_t a) { return (uint64_t)a; }
uint8_t  lean_uint8_dec_eq(uint8_t a, uint8_t b) { return a == b; }
uint8_t  lean_uint8_dec_lt(uint8_t a, uint8_t b) { return a < b; }
uint8_t  lean_uint8_dec_le(uint8_t a, uint8_t b) { return a <= b; }
uint8_t  lean_uint8_add(uint8_t a, uint8_t b) { return a + b; }
uint8_t  lean_uint8_sub(uint8_t a, uint8_t b) { return a - b; }
uint8_t  lean_uint8_mul(uint8_t a, uint8_t b) { return a * b; }
uint8_t  lean_uint8_div(uint8_t a, uint8_t b) { return b == 0 ? 0 : a / b; }
uint8_t  lean_uint8_mod(uint8_t a, uint8_t b) { return b == 0 ? a : a % b; }
uint8_t  lean_uint8_xor(uint8_t a, uint8_t b) { return a ^ b; }
uint8_t  lean_uint8_land(uint8_t a, uint8_t b) { return a & b; }
uint8_t  lean_uint8_lor (uint8_t a, uint8_t b) { return a | b; }
uint8_t  lean_uint8_shift_left (uint8_t a, uint8_t b) { return (uint8_t)(a << (b & 7)); }
uint8_t  lean_uint8_shift_right(uint8_t a, uint8_t b) { return (uint8_t)(a >> (b & 7)); }
/* `usize` is target-dependent (`size_t` in C terms): 64-bit on host/sbf,
   32-bit on wasm32. The bitcode-side ABI matches whatever the target's
   data layout says, so use `size_t` to track the target's pointer width
   without hardcoding i64. Same for the value-of-Nat returns below. */
static int lean_freestanding_is_scalar(void *o) {
    return ((uintptr_t)o & 1u) == 1u;
}

static void lean_freestanding_nat_panic(const char *what) {
    lean_freestanding_log(what, lean_strlen(what));
    lean_freestanding_panic("lean_nat", 0, 0);
    __builtin_unreachable();
}

size_t  lean_usize_add(size_t a, size_t b) { return a + b; }
size_t  lean_usize_sub(size_t a, size_t b) { return a - b; }
size_t  lean_usize_mul(size_t a, size_t b) { return a * b; }
uint8_t lean_usize_dec_eq(size_t a, size_t b) { return a == b; }
uint8_t lean_usize_dec_lt(size_t a, size_t b) { return a <  b; }
uint8_t lean_usize_dec_le(size_t a, size_t b) { return a <= b; }

uint8_t  lean_usize_to_uint8 (size_t a) { return (uint8_t)a; }
uint16_t lean_usize_to_uint16(size_t a) { return (uint16_t)a; }
uint32_t lean_usize_to_uint32(size_t a) { return (uint32_t)a; }
uint64_t lean_usize_to_uint64(size_t a) { return (uint64_t)a; }
size_t lean_uint8_to_usize  (uint8_t  a) { return (size_t)a; }
size_t lean_uint16_to_usize (uint16_t a) { return (size_t)a; }
size_t lean_uint32_to_usize (uint32_t a) { return (size_t)a; }
size_t lean_uint64_to_usize (uint64_t a) { return (size_t)a; }

/* UInt32 arithmetic / comparison set (mirrors host lean.h inline defs). */
uint32_t lean_uint32_add(uint32_t a, uint32_t b) { return a + b; }
uint32_t lean_uint32_sub(uint32_t a, uint32_t b) { return a - b; }
uint32_t lean_uint32_mul(uint32_t a, uint32_t b) { return a * b; }
uint32_t lean_uint32_div(uint32_t a, uint32_t b) { return b == 0 ? 0  : a / b; }
uint32_t lean_uint32_mod(uint32_t a, uint32_t b) { return b == 0 ? a  : a % b; }
uint32_t lean_uint32_land(uint32_t a, uint32_t b) { return a & b; }
uint32_t lean_uint32_lor (uint32_t a, uint32_t b) { return a | b; }
uint32_t lean_uint32_xor (uint32_t a, uint32_t b) { return a ^ b; }
uint32_t lean_uint32_shift_left (uint32_t a, uint32_t b) { return a << (b & 31); }
uint32_t lean_uint32_shift_right(uint32_t a, uint32_t b) { return a >> (b & 31); }
uint8_t  lean_uint32_dec_eq(uint32_t a, uint32_t b) { return a == b; }
uint8_t  lean_uint32_dec_lt(uint32_t a, uint32_t b) { return a <  b; }
uint8_t  lean_uint32_dec_le(uint32_t a, uint32_t b) { return a <= b; }
uint8_t  lean_uint32_to_uint8 (uint32_t a) { return (uint8_t)a; }
uint16_t lean_uint32_to_uint16(uint32_t a) { return (uint16_t)a; }
uint64_t lean_uint32_to_uint64(uint32_t a) { return (uint64_t)a; }

uint64_t lean_uint16_to_uint64(uint16_t a) { return (uint64_t)a; }
uint32_t lean_uint16_to_uint32(uint16_t a) { return (uint32_t)a; }
uint8_t  lean_uint16_to_uint8 (uint16_t a) { return (uint8_t)a; }
uint16_t lean_uint8_to_uint16 (uint8_t  a) { return (uint16_t)a; }
uint16_t lean_uint64_to_uint16(uint64_t a) { return (uint16_t)a; }
uint32_t lean_uint64_to_uint32(uint64_t a) { return (uint32_t)a; }

/* Tagged-scalar box / unbox for `usize` and `uint32`. We don't use the
   host's ctor-tail layout because the freestanding runtime caps small-Nat
   values to fit in the tagged-scalar payload (`(uintptr_t)-1 >> 1`); the
   bound check in `lean_uint64_to_nat` etc. ensures safety. */
void *lean_box_usize(size_t v) {
    if ((uint64_t)v > LEAN_FREESTANDING_MAX_SMALL_NAT) {
        lean_freestanding_nat_panic("lean-freestanding: usize value exceeds small-Nat cap");
    }
    return lean_box(v);
}

size_t lean_unbox_usize(void *p) {
    return (size_t)lean_unbox(p);
}

void *lean_box_uint32(uint32_t v) {
    /* On wasm32 the small-Nat cap is 2^31-1, so values >= 2^31 don't fit. */
    if ((uint64_t)v > LEAN_FREESTANDING_MAX_SMALL_NAT) {
        lean_freestanding_nat_panic("lean-freestanding: uint32 value exceeds small-Nat cap");
    }
    return lean_box((size_t)v);
}

uint32_t lean_unbox_uint32(void *p) {
    return (uint32_t)lean_unbox(p);
}

uint8_t lean_string_dec_eq(void *s1, void *s2) {
    if (s1 == s2) return 1;
    lean_string_object *a = (lean_string_object *)s1;
    lean_string_object *b = (lean_string_object *)s2;
    if (a->m_size != b->m_size) return 0;
    for (size_t i = 0; i + 1 < a->m_size; ++i) {
        if (a->m_data[i] != b->m_data[i]) return 0;
    }
    return 1;
}

/* ===========================================================================
   Arrays
   ===========================================================================
   `Array α` is a heap-allocated growable buffer of `lean_object *` slots.
   Mutating operations follow Lean's standard copy-on-write discipline:
   modify in place only when the array is exclusive, otherwise copy first.
*/

static lean_array_object *lean_freestanding_alloc_array(size_t size, size_t capacity) {
    lean_array_object *o = (lean_array_object *)bump_alloc(sizeof(lean_array_object) + sizeof(void *) * capacity);
    o->m_header.m_rc = 1;
    o->m_header.m_cs_sz = 0;
    o->m_header.m_other = 0;
    o->m_header.m_tag = LEAN_TAG_ARRAY;
    o->m_size = size;
    o->m_capacity = capacity;
    return o;
}

size_t lean_array_size(void *a) {
    return ((lean_array_object *)a)->m_size;
}

size_t lean_array_capacity(void *a) {
    return ((lean_array_object *)a)->m_capacity;
}

void *lean_alloc_array(size_t size, size_t capacity) {
    return lean_freestanding_alloc_array(size, capacity);
}

void *lean_mk_empty_array(void) {
    return lean_freestanding_alloc_array(0, 0);
}

void *lean_mk_empty_array_with_capacity(void *capacity_box) {
    /* `capacity_box` is a tag-encoded boxed Nat; lean_unbox extracts the
       small payload. */
    size_t cap = lean_unbox(capacity_box);
    return lean_freestanding_alloc_array(0, cap);
}

void *lean_array_get_size(void *a) {
    return lean_box(((lean_array_object *)a)->m_size);
}

void *lean_array_fget(void *a, void *i) {
    lean_object *r = ((lean_array_object *)a)->m_data[lean_unbox(i)];
    lean_inc(r);
    return r;
}

void *lean_array_fget_borrowed(void *a, void *i) {
    return ((lean_array_object *)a)->m_data[lean_unbox(i)];
}

void *lean_array_get(void *fallback, void *a, void *i) {
    if (lean_freestanding_is_scalar(i)) {
        size_t idx = lean_unbox(i);
        lean_array_object *arr = (lean_array_object *)a;
        if (idx < arr->m_size) {
            lean_object *r = arr->m_data[idx];
            lean_inc(r);
            return r;
        }
    }
    lean_inc(fallback);
    return fallback;
}

void *lean_array_get_borrowed(void *fallback, void *a, void *i) {
    if (lean_freestanding_is_scalar(i)) {
        size_t idx = lean_unbox(i);
        lean_array_object *arr = (lean_array_object *)a;
        if (idx < arr->m_size) return arr->m_data[idx];
    }
    return fallback;
}

void *lean_array_uget_borrowed(void *a, size_t i) {
    return ((lean_array_object *)a)->m_data[i];
}

void *lean_array_uget(void *a, size_t i) {
    lean_object *r = ((lean_array_object *)a)->m_data[i];
    lean_inc(r);
    return r;
}

void *lean_copy_expand_array(void *a, uint8_t expand) {
    lean_array_object *src = (lean_array_object *)a;
    size_t new_cap = src->m_capacity;
    if (expand) new_cap = (new_cap + 1) * 2;
    if (new_cap < src->m_size) new_cap = src->m_size;
    lean_array_object *dst = lean_freestanding_alloc_array(src->m_size, new_cap);
    if (lean_is_exclusive(a)) {
        for (size_t i = 0; i < src->m_size; ++i) dst->m_data[i] = src->m_data[i];
        src->m_header.m_rc = 0;
    } else {
        for (size_t i = 0; i < src->m_size; ++i) {
            dst->m_data[i] = src->m_data[i];
            lean_inc(dst->m_data[i]);
        }
        lean_dec(a);
    }
    return dst;
}

void *lean_copy_expand_array_nonlinear(void *a, uint8_t expand) {
    return lean_copy_expand_array(a, expand);
}

static lean_array_object *lean_freestanding_ensure_exclusive_array(void *a) {
    if (lean_is_exclusive(a)) return (lean_array_object *)a;
    return (lean_array_object *)lean_copy_expand_array_nonlinear(a, 0);
}

void *lean_array_uset(void *a, size_t i, void *v) {
    lean_array_object *r = lean_freestanding_ensure_exclusive_array(a);
    lean_dec(r->m_data[i]);
    r->m_data[i] = (lean_object *)v;
    return r;
}

void *lean_array_fset(void *a, void *i, void *v) {
    return lean_array_uset(a, lean_unbox(i), v);
}

void *lean_array_set(void *a, void *i, void *v) {
    if (!lean_freestanding_is_scalar(i)) {
        lean_dec(v);
        return a;
    }
    size_t idx = lean_unbox(i);
    if (idx >= ((lean_array_object *)a)->m_size) {
        lean_dec(v);
        return a;
    }
    return lean_array_uset(a, idx, v);
}

void *lean_array_pop(void *a) {
    lean_array_object *r = lean_freestanding_ensure_exclusive_array(a);
    if (r->m_size == 0) return r;
    r->m_size--;
    lean_dec(r->m_data[r->m_size]);
    return r;
}

void *lean_array_uswap(void *a, size_t i, size_t j) {
    lean_array_object *r = lean_freestanding_ensure_exclusive_array(a);
    lean_object *tmp = r->m_data[i];
    r->m_data[i] = r->m_data[j];
    r->m_data[j] = tmp;
    return r;
}

void *lean_array_fswap(void *a, void *i, void *j) {
    return lean_array_uswap(a, lean_unbox(i), lean_unbox(j));
}

void *lean_array_swap(void *a, void *i, void *j) {
    if (!lean_freestanding_is_scalar(i) || !lean_freestanding_is_scalar(j)) return a;
    size_t ui = lean_unbox(i);
    size_t uj = lean_unbox(j);
    lean_array_object *arr = (lean_array_object *)a;
    if (ui >= arr->m_size || uj >= arr->m_size) return a;
    return lean_array_uswap(a, ui, uj);
}

void *lean_mk_array(void *n, void *v) {
    if (!lean_freestanding_is_scalar(n)) {
        lean_freestanding_nat_panic("lean-freestanding: mk_array size exceeds small-Nat cap");
    }
    size_t cnt = lean_unbox(n);
    lean_array_object *dst = lean_freestanding_alloc_array(cnt, cnt);
    for (size_t k = 0; k < cnt; ++k) dst->m_data[k] = (lean_object *)v;
    if (cnt == 0) {
        lean_dec(v);
    } else if (cnt > 1) {
        lean_inc_n(v, cnt - 1);
    }
    return dst;
}

void *lean_array_push(void *a, void *v) {
    lean_array_object *src = (lean_array_object *)a;
    lean_array_object *r;
    if (lean_is_exclusive(a)) {
        r = src->m_capacity > src->m_size
            ? src
            : (lean_array_object *)lean_copy_expand_array(a, 1);
    } else {
        uint8_t expand = src->m_capacity < 2 * src->m_size + 1;
        r = (lean_array_object *)lean_copy_expand_array_nonlinear(a, expand);
    }
    if (r->m_capacity <= r->m_size) {
        lean_freestanding_panic("array_push capacity invariant", r->m_capacity, r->m_size);
    }
    r->m_data[r->m_size] = (lean_object *)v;
    r->m_size++;
    return r;
}

/* ===========================================================================
   Scalar arrays / ByteArray
   ===========================================================================
   `lean_sarray_object` is the packed-bytes counterpart to `lean_array_object`.
   It is the underlying type for both `ByteArray` (elem_size = 1) and
   `FloatArray` (elem_size = 8). The element size is stashed in the
   header's `m_other` byte by the host runtime; we follow the same
   convention so accessors that pull it via `lean_ptr_other` keep working.
*/

static lean_sarray_object *lean_freestanding_alloc_sarray(unsigned elem_size, size_t size, size_t capacity) {
    lean_sarray_object *o = (lean_sarray_object *)bump_alloc(sizeof(lean_sarray_object) + elem_size * capacity);
    o->m_header.m_rc = 1;
    o->m_header.m_cs_sz = 0;
    o->m_header.m_other = (unsigned)(elem_size & 0xFF);
    o->m_header.m_tag = LEAN_TAG_SCALAR_ARRAY;
    o->m_size = size;
    o->m_capacity = capacity;
    return o;
}

static unsigned lean_freestanding_sarray_elem_size(void *a) {
    unsigned elem_size = ((lean_object *)a)->m_other;
    return elem_size == 0 ? 1 : elem_size;
}

size_t lean_sarray_size(void *a) {
    return ((lean_sarray_object *)a)->m_size;
}

size_t lean_sarray_capacity(void *a) {
    return ((lean_sarray_object *)a)->m_capacity;
}

void *lean_alloc_sarray(unsigned elem_size, size_t size, size_t capacity) {
    return lean_freestanding_alloc_sarray(elem_size, size, capacity);
}

void *lean_copy_sarray(void *a, size_t capacity) {
    lean_sarray_object *src = (lean_sarray_object *)a;
    unsigned elem_size = lean_freestanding_sarray_elem_size(a);
    if (capacity < src->m_size) capacity = src->m_size;
    lean_sarray_object *dst = lean_freestanding_alloc_sarray(elem_size, src->m_size, capacity);
    size_t byte_size = elem_size * src->m_size;
    for (size_t i = 0; i < byte_size; ++i) dst->m_data[i] = src->m_data[i];
    if (lean_is_exclusive(a)) {
        src->m_header.m_rc = 0;
    } else {
        lean_dec(a);
    }
    return dst;
}

void *lean_sarray_ensure_capacity(void *a, size_t min_capacity, uint8_t exact) {
    size_t capacity = lean_sarray_capacity(a);
    if (min_capacity <= capacity) return a;
    size_t new_capacity = exact ? min_capacity : min_capacity * 2;
    if (new_capacity < min_capacity) new_capacity = min_capacity;
    return lean_copy_sarray(a, new_capacity);
}

static lean_sarray_object *lean_freestanding_ensure_exclusive_sarray(void *a) {
    if (lean_is_exclusive(a)) return (lean_sarray_object *)a;
    return (lean_sarray_object *)lean_copy_sarray(a, lean_sarray_capacity(a));
}

uint8_t lean_sarray_dec_eq(void *a1, void *a2) {
    if (a1 == a2) return 1;
    lean_sarray_object *x = (lean_sarray_object *)a1;
    lean_sarray_object *y = (lean_sarray_object *)a2;
    unsigned elem_size = lean_freestanding_sarray_elem_size(a1);
    if (elem_size != lean_freestanding_sarray_elem_size(a2)) return 0;
    if (x->m_size != y->m_size) return 0;
    size_t byte_size = elem_size * x->m_size;
    for (size_t i = 0; i < byte_size; ++i) {
        if (x->m_data[i] != y->m_data[i]) return 0;
    }
    return 1;
}

void *lean_mk_empty_byte_array(void *capacity_box) {
    size_t cap = lean_unbox(capacity_box);
    return lean_freestanding_alloc_sarray(1, 0, cap);
}

void *lean_byte_array_mk(void *array) {
    /* Convert an `Array UInt8` (whose elements are tag-encoded boxed
       UInt8 scalars) into a packed `ByteArray`. */
    lean_array_object *a = (lean_array_object *)array;
    lean_sarray_object *r = lean_freestanding_alloc_sarray(1, a->m_size, a->m_size);
    for (size_t i = 0; i < a->m_size; ++i) {
        r->m_data[i] = (uint8_t)(lean_unbox(a->m_data[i]) & 0xFF);
    }
    lean_dec(array);
    return r;
}

void *lean_byte_array_data(void *a) {
    lean_sarray_object *src = (lean_sarray_object *)a;
    lean_array_object *r = lean_freestanding_alloc_array(src->m_size, src->m_size);
    for (size_t i = 0; i < src->m_size; ++i) {
        r->m_data[i] = (lean_object *)lean_box(src->m_data[i]);
    }
    lean_dec(a);
    return r;
}

void *lean_byte_array_size(void *a) {
    return lean_box(((lean_sarray_object *)a)->m_size);
}

uint8_t lean_byte_array_uget(void *a, size_t i) {
    return ((lean_sarray_object *)a)->m_data[i];
}

uint8_t lean_byte_array_fget(void *a, void *i) {
    return lean_byte_array_uget(a, lean_unbox(i));
}

/* Bounds-checked byte access. The host runtime returns 0 for out-of-bounds
   or non-scalar (i.e. arbitrarily-large) indices. */
uint8_t lean_byte_array_get(void *a, void *i) {
    if (lean_freestanding_is_scalar(i)) {
        size_t idx = lean_unbox(i);
        lean_sarray_object *sa = (lean_sarray_object *)a;
        return idx < sa->m_size ? sa->m_data[idx] : 0;
    }
    return 0;
}

void *lean_byte_array_uset(void *a, size_t i, uint8_t v) {
    lean_sarray_object *r = lean_freestanding_ensure_exclusive_sarray(a);
    r->m_data[i] = v;
    return r;
}

void *lean_byte_array_fset(void *a, void *i, uint8_t v) {
    return lean_byte_array_uset(a, lean_unbox(i), v);
}

void *lean_byte_array_set(void *a, void *i, uint8_t v) {
    if (!lean_freestanding_is_scalar(i)) return a;
    size_t idx = lean_unbox(i);
    if (idx >= ((lean_sarray_object *)a)->m_size) return a;
    return lean_byte_array_uset(a, idx, v);
}

void *lean_byte_array_push(void *a, uint8_t v) {
    lean_sarray_object *r = (lean_sarray_object *)lean_sarray_ensure_capacity(
        a, ((lean_sarray_object *)a)->m_size + 1, 0);
    r = lean_freestanding_ensure_exclusive_sarray(r);
    r->m_data[r->m_size] = v;
    r->m_size++;
    return r;
}

void *lean_copy_byte_array(void *a) {
    return lean_copy_sarray(a, lean_sarray_capacity(a));
}

static size_t lean_freestanding_nat_to_size(void *n, const char *context) {
    if (!lean_freestanding_is_scalar(n)) lean_freestanding_nat_panic(context);
    return lean_unbox(n);
}

void *lean_byte_array_copy_slice(void *src_obj, void *src_off_obj, void *dest_obj,
                                 void *dest_off_obj, void *len_obj, uint8_t exact) {
    lean_sarray_object *src = (lean_sarray_object *)src_obj;
    lean_sarray_object *dest = (lean_sarray_object *)dest_obj;
    size_t src_off = lean_freestanding_nat_to_size(src_off_obj,
        "lean-freestanding: byte_array_copy_slice source offset exceeds small-Nat cap");
    if (src_off > src->m_size) return dest_obj;
    size_t len = lean_freestanding_nat_to_size(len_obj,
        "lean-freestanding: byte_array_copy_slice length exceeds small-Nat cap");
    if (len > src->m_size - src_off) len = src->m_size - src_off;
    size_t dest_off = lean_freestanding_nat_to_size(dest_off_obj,
        "lean-freestanding: byte_array_copy_slice destination offset exceeds small-Nat cap");
    if (dest_off > dest->m_size) dest_off = dest->m_size;
    size_t new_size = dest->m_size;
    if (dest_off + len > new_size) new_size = dest_off + len;
    lean_sarray_object *r = (lean_sarray_object *)lean_sarray_ensure_capacity(dest_obj, new_size, exact);
    r = lean_freestanding_ensure_exclusive_sarray(r);
    r->m_size = new_size;
    memmove(r->m_data + dest_off, src->m_data + src_off, len);
    return r;
}

uint64_t lean_byte_array_hash(void *a) {
    lean_sarray_object *src = (lean_sarray_object *)a;
    const uint64_t m = 0xc6a4a7935bd1e995ull;
    const unsigned r = 47;
    uint64_t h = 11ull ^ (src->m_size * m);
    size_t i = 0;
    while (i + 8 <= src->m_size) {
        uint64_t k = 0;
        for (unsigned j = 0; j < 8; ++j) k |= ((uint64_t)src->m_data[i + j]) << (8 * j);
        i += 8;
        k *= m;
        k ^= k >> r;
        k *= m;
        h ^= k;
        h *= m;
    }
    const uint8_t *tail = src->m_data + i;
    size_t rem = src->m_size & 7;
    if (rem >= 7) h ^= (uint64_t)tail[6] << 48;
    if (rem >= 6) h ^= (uint64_t)tail[5] << 40;
    if (rem >= 5) h ^= (uint64_t)tail[4] << 32;
    if (rem >= 4) h ^= (uint64_t)tail[3] << 24;
    if (rem >= 3) h ^= (uint64_t)tail[2] << 16;
    if (rem >= 2) h ^= (uint64_t)tail[1] << 8;
    if (rem >= 1) {
        h ^= (uint64_t)tail[0];
        h *= m;
    }
    h ^= h >> r;
    h *= m;
    h ^= h >> r;
    return h;
}

void *lean_box_float(double v) {
    lean_ctor_object *o = (lean_ctor_object *)lean_alloc_ctor(0, 0, sizeof(double));
    *(double *)((char *)o + sizeof(lean_ctor_object)) = v;
    return o;
}

double lean_unbox_float(void *o) {
    return *(double *)((char *)o + sizeof(lean_ctor_object));
}

void *lean_mk_empty_float_array(void *capacity_box) {
    size_t cap = lean_unbox(capacity_box);
    return lean_freestanding_alloc_sarray(sizeof(double), 0, cap);
}

void *lean_copy_float_array(void *a) {
    return lean_copy_sarray(a, lean_sarray_capacity(a));
}

static double *lean_freestanding_float_array_cptr(void *a) {
    return (double *)((lean_sarray_object *)a)->m_data;
}

void *lean_float_array_mk(void *array) {
    lean_array_object *a = (lean_array_object *)array;
    lean_sarray_object *r = lean_freestanding_alloc_sarray(sizeof(double), a->m_size, a->m_size);
    double *dst = (double *)r->m_data;
    for (size_t i = 0; i < a->m_size; ++i) dst[i] = lean_unbox_float(a->m_data[i]);
    lean_dec(array);
    return r;
}

void *lean_float_array_data(void *a) {
    lean_sarray_object *src = (lean_sarray_object *)a;
    lean_array_object *r = lean_freestanding_alloc_array(src->m_size, src->m_size);
    double *src_data = (double *)src->m_data;
    for (size_t i = 0; i < src->m_size; ++i) r->m_data[i] = (lean_object *)lean_box_float(src_data[i]);
    lean_dec(a);
    return r;
}

void *lean_float_array_push(void *a, double v) {
    lean_sarray_object *r = (lean_sarray_object *)lean_sarray_ensure_capacity(
        a, ((lean_sarray_object *)a)->m_size + 1, 0);
    r = lean_freestanding_ensure_exclusive_sarray(r);
    lean_freestanding_float_array_cptr(r)[r->m_size] = v;
    r->m_size++;
    return r;
}

void *lean_float_array_size(void *a) {
    return lean_box(((lean_sarray_object *)a)->m_size);
}

double lean_float_array_uget(void *a, size_t i) {
    return lean_freestanding_float_array_cptr(a)[i];
}

double lean_float_array_fget(void *a, void *i) {
    return lean_float_array_uget(a, lean_unbox(i));
}

double lean_float_array_get(void *a, void *i) {
    if (!lean_freestanding_is_scalar(i)) return 0.0;
    size_t idx = lean_unbox(i);
    return idx < ((lean_sarray_object *)a)->m_size ? lean_float_array_uget(a, idx) : 0.0;
}

void *lean_float_array_uset(void *a, size_t i, double v) {
    lean_sarray_object *r = lean_freestanding_ensure_exclusive_sarray(a);
    lean_freestanding_float_array_cptr(r)[i] = v;
    return r;
}

void *lean_float_array_fset(void *a, void *i, double v) {
    return lean_float_array_uset(a, lean_unbox(i), v);
}

void *lean_float_array_set(void *a, void *i, double v) {
    if (!lean_freestanding_is_scalar(i)) return a;
    size_t idx = lean_unbox(i);
    if (idx >= ((lean_sarray_object *)a)->m_size) return a;
    return lean_float_array_uset(a, idx, v);
}

void *lean_freestanding_make_byte_array(const uint8_t *data, size_t len) {
    lean_sarray_object *r = lean_freestanding_alloc_sarray(1, len, len);
    for (size_t i = 0; i < len; ++i) r->m_data[i] = data[i];
    return r;
}

/* `String.toUTF8 s : ByteArray` — copy the string's payload (excluding
   the trailing NUL) into a fresh ByteArray. Mirrors the host
   `lean_string_to_utf8` in `runtime/object.cpp`. */
void *lean_string_to_utf8(void *s) {
    lean_string_object *str = (lean_string_object *)s;
    size_t sz = str->m_size > 0 ? str->m_size - 1 : 0;
    lean_sarray_object *r = lean_freestanding_alloc_sarray(1, sz, sz);
    for (size_t i = 0; i < sz; ++i) r->m_data[i] = (uint8_t)str->m_data[i];
    return r;
}

/* ===========================================================================
   Bounded Nat / Int subset
   ===========================================================================
   Lean's host runtime keeps `Nat` values as either tagged-scalar small values
   (up to `(SIZE_MAX >> 1)`) or heap-allocated GMP big-nats. Freestanding
   doesn't ship GMP: only the tagged small form is supported, and any conversion
   or arithmetic that would exceed `LEAN_FREESTANDING_MAX_SMALL_NAT` panics. */

void *lean_unsigned_to_nat(uint32_t n) {
    if ((uint64_t)n > LEAN_FREESTANDING_MAX_SMALL_NAT) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (unsigned_to_nat exceeds small-Nat cap)");
    }
    return lean_box((size_t)n);
}

void *lean_uint64_to_nat(uint64_t n) {
    if (n > LEAN_FREESTANDING_MAX_SMALL_NAT) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (uint64_to_nat exceeds small-Nat cap)");
    }
    return lean_box((size_t)n);
}

void *lean_uint8_to_nat(uint8_t n) {
    return lean_uint64_to_nat((uint64_t)n);
}

void *lean_uint16_to_nat(uint16_t n) {
    return lean_uint64_to_nat((uint64_t)n);
}

void *lean_uint32_to_nat(uint32_t n) {
    return lean_uint64_to_nat((uint64_t)n);
}

/* `usize` is target-pointer-sized (`size_t` in C). On wasm32 that's
   uint32_t; on sbf/host it's uint64_t. Bitcode-side these calls use
   the target's `i32`/`i64` per the data layout, so the C signatures
   must use `size_t` not `uint64_t` to match. Mismatches cause silent
   wasm-ld signature warnings + runtime traps. */
void *lean_usize_to_nat(size_t n) {
    return lean_uint64_to_nat((uint64_t)n);
}

uint64_t lean_uint64_of_nat(void *n) {
    if (!lean_freestanding_is_scalar(n)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (uint64_of_nat on big-Nat)");
    }
    return lean_unbox(n);
}

uint32_t lean_uint32_of_nat(void *n) {
    if (!lean_freestanding_is_scalar(n)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (uint32_of_nat on big-Nat)");
    }
    return (uint32_t)lean_unbox(n);
}

uint16_t lean_uint16_of_nat(void *n) {
    if (!lean_freestanding_is_scalar(n)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (uint16_of_nat on big-Nat)");
    }
    return (uint16_t)lean_unbox(n);
}

uint8_t lean_uint8_of_nat(void *n) {
    if (!lean_freestanding_is_scalar(n)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (uint8_of_nat on big-Nat)");
    }
    return (uint8_t)lean_unbox(n);
}

size_t lean_usize_of_nat(void *n) {
    if (!lean_freestanding_is_scalar(n)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (usize_of_nat on big-Nat)");
    }
    return (size_t)lean_unbox(n);
}

void *lean_nat_add(void *a, void *b) {
    if (!lean_freestanding_is_scalar(a) || !lean_freestanding_is_scalar(b)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (add on big-Nat)");
    }
    uint64_t av = lean_unbox(a);
    uint64_t bv = lean_unbox(b);
    if (av > LEAN_FREESTANDING_MAX_SMALL_NAT - bv) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (add result exceeds small-Nat cap)");
    }
    return lean_box(av + bv);
}

void *lean_nat_sub(void *a, void *b) {
    if (!lean_freestanding_is_scalar(a) || !lean_freestanding_is_scalar(b)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (sub on big-Nat)");
    }
    uint64_t av = lean_unbox(a);
    uint64_t bv = lean_unbox(b);
    /* Lean's `Nat` saturates: m - n with m < n yields 0. */
    return lean_box(av < bv ? 0 : av - bv);
}

void *lean_nat_mul(void *a, void *b) {
    if (!lean_freestanding_is_scalar(a) || !lean_freestanding_is_scalar(b)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (mul on big-Nat)");
    }
    uint64_t av = lean_unbox(a);
    uint64_t bv = lean_unbox(b);
    if (av != 0 && bv > LEAN_FREESTANDING_MAX_SMALL_NAT / av) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (mul result exceeds small-Nat cap)");
    }
    return lean_box(av * bv);
}

void *lean_nat_div(void *a, void *b) {
    if (!lean_freestanding_is_scalar(a) || !lean_freestanding_is_scalar(b)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (div on big-Nat)");
    }
    uint64_t bv = lean_unbox(b);
    /* Lean's `Nat` defines `n / 0 = 0`. */
    return lean_box(bv == 0 ? 0 : lean_unbox(a) / bv);
}

void *lean_nat_mod(void *a, void *b) {
    if (!lean_freestanding_is_scalar(a) || !lean_freestanding_is_scalar(b)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (mod on big-Nat)");
    }
    uint64_t av = lean_unbox(a);
    uint64_t bv = lean_unbox(b);
    return lean_box(bv == 0 ? av : av % bv);
}

void *lean_nat_shiftr(void *a, void *b) {
    if (!lean_freestanding_is_scalar(a) || !lean_freestanding_is_scalar(b)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (shiftr on big-Nat)");
    }
    uint64_t av = lean_unbox(a);
    uint64_t bv = lean_unbox(b);
    return lean_box(bv < 64 ? av >> bv : 0);
}

uint8_t lean_nat_dec_lt(void *a, void *b) {
    if (!lean_freestanding_is_scalar(a) || !lean_freestanding_is_scalar(b)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (dec_lt on big-Nat)");
    }
    return lean_unbox(a) < lean_unbox(b);
}

uint8_t lean_nat_dec_le(void *a, void *b) {
    if (!lean_freestanding_is_scalar(a) || !lean_freestanding_is_scalar(b)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (dec_le on big-Nat)");
    }
    return lean_unbox(a) <= lean_unbox(b);
}

uint8_t lean_nat_dec_eq(void *a, void *b) {
    if (!lean_freestanding_is_scalar(a) || !lean_freestanding_is_scalar(b)) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (dec_eq on big-Nat)");
    }
    return lean_unbox(a) == lean_unbox(b);
}
