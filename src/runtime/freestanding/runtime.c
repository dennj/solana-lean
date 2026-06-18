/*
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Freestanding subset of the Lean runtime for cross-compile targets that
ship without libc and without the host's `lean.h.bc` runtime: a small
reclaiming heap allocator, single-threaded refcount metadata, boxing
primitives, ctor allocation/accessors, IO-result wrappers, strings,
arrays, scalar arrays, and a bounded small-Nat / Int subset.

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
                                 metadata; heap cursor occupies [0..8).
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

/* Anza's SBF clang (platform-tools v1.43) crashes while lowering
   `__builtin_return_address` for BPF; non-Emscripten wasm32 clang
   refuses it outright ("hasn't implemented"). Keep return-address
   metadata on targets that support it, but stub it to zero on the
   freestanding cross targets that don't. */
#if defined(__BPF__) || defined(__bpf__) || defined(__wasm__) || defined(__wasm32__) || defined(__wasm64__)
#define LEAN_FREESTANDING_RETURN_ADDRESS(depth) ((uint64_t)0)
#else
#define LEAN_FREESTANDING_RETURN_ADDRESS(depth) ((uint64_t)(uintptr_t)__builtin_return_address(depth))
#endif

#define LEAN_FREESTANDING_MAX_SMALL_NAT ((uint64_t)((uintptr_t)-1 >> 1))
static void lean_freestanding_nat_panic(const char *what) __attribute__((noreturn));
static void lean_freestanding_int_panic(const char *what) __attribute__((noreturn));
static int  lean_freestanding_is_scalar(void *o);
void *lean_box_uint32(uint32_t v);
void *lean_usize_to_nat(size_t n);
void *lean_nat_add(void *a, void *b);
void *lean_nat_sub(void *a, void *b);
void *lean_apply_1(void *c, void *a1);
void lean_dec(void *o);
static void *lean_freestanding_int64_to_int(int64_t n);
static void *lean_freestanding_uint64_to_nonnegative_int(uint64_t n);

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
#define LEAN_TAG_MPZ 250
#define LEAN_FREESTANDING_MPZ_NONNEG 0u
#define LEAN_FREESTANDING_MPZ_NEG 1u

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
   Reclaiming allocator over the embedder-supplied heap region
   ===========================================================================
   The embedder reserves a heap region at [HEAP_BASE, HEAP_BASE+HEAP_BYTES).
   Bytes [0..8) of the heap hold the high-water cursor; [8..PREFIX) is
   embedder metadata (e.g. on SBF: loader-input pointer at [8..16),
   account-table pointer at [16..24)).

   Allocation uses one freestanding mechanism for every target: an implicit
   free-list over blocks stored inside the supplied heap. The cursor extends
   the heap when no free block fits; `lean_dec` can later return blocks to the
   list and adjacent free blocks are coalesced. No libc allocator or writable
   file-scope state is required.
*/

#define LEAN_FREESTANDING_HEAP_END (LEAN_FREESTANDING_HEAP_BASE + LEAN_FREESTANDING_HEAP_BYTES)
#define LEAN_FREESTANDING_ALIGN 8u
#define LEAN_FREESTANDING_BLOCK_FREE ((size_t)1)
#define LEAN_FREESTANDING_BLOCK_SIZE_MASK (~(size_t)(LEAN_FREESTANDING_ALIGN - 1))

typedef struct {
    size_t m_size_flags; /* total block size, including this header */
} lean_freestanding_block;

static size_t lean_freestanding_align(size_t n) {
    return (n + (LEAN_FREESTANDING_ALIGN - 1)) & ~(size_t)(LEAN_FREESTANDING_ALIGN - 1);
}

static uintptr_t lean_freestanding_align_addr(uintptr_t p) {
    return (p + (LEAN_FREESTANDING_ALIGN - 1)) & ~(uintptr_t)(LEAN_FREESTANDING_ALIGN - 1);
}

static size_t lean_freestanding_block_size(lean_freestanding_block *b) {
    return b->m_size_flags & LEAN_FREESTANDING_BLOCK_SIZE_MASK;
}

static int lean_freestanding_block_is_free(lean_freestanding_block *b) {
    return (b->m_size_flags & LEAN_FREESTANDING_BLOCK_FREE) != 0;
}

static void lean_freestanding_block_set(lean_freestanding_block *b, size_t size, int is_free) {
    b->m_size_flags = size | (is_free ? LEAN_FREESTANDING_BLOCK_FREE : 0);
}

static uintptr_t lean_freestanding_heap_start(void) {
    return lean_freestanding_align_addr(LEAN_FREESTANDING_HEAP_BASE + LEAN_FREESTANDING_HEAP_PREFIX);
}

uintptr_t *lean_freestanding_bump_pointer_storage(void) {
    return (uintptr_t *)LEAN_FREESTANDING_HEAP_BASE;
}

static uintptr_t lean_freestanding_heap_cursor(void) {
    uintptr_t *bp = lean_freestanding_bump_pointer_storage();
    if (*bp == 0) *bp = lean_freestanding_heap_start();
    return *bp;
}

static void lean_freestanding_set_heap_cursor(uintptr_t cursor) {
    *lean_freestanding_bump_pointer_storage() = cursor;
}

static lean_freestanding_block *lean_freestanding_next_block(lean_freestanding_block *b) {
    return (lean_freestanding_block *)((char *)b + lean_freestanding_block_size(b));
}

static void lean_freestanding_coalesce_free_blocks(void) {
    uintptr_t start = lean_freestanding_heap_start();
    uintptr_t cursor = lean_freestanding_heap_cursor();
    lean_freestanding_block *b = (lean_freestanding_block *)start;
    while ((uintptr_t)b < cursor) {
        lean_freestanding_block *next = lean_freestanding_next_block(b);
        while ((uintptr_t)next < cursor &&
               lean_freestanding_block_is_free(b) &&
               lean_freestanding_block_is_free(next)) {
            size_t merged = lean_freestanding_block_size(b) + lean_freestanding_block_size(next);
            lean_freestanding_block_set(b, merged, 1);
            next = lean_freestanding_next_block(b);
        }
        b = lean_freestanding_next_block(b);
    }
}

static void lean_freestanding_shrink_cursor_tail(void) {
    uintptr_t start = lean_freestanding_heap_start();
    uintptr_t cursor = lean_freestanding_heap_cursor();
    uintptr_t last = 0;
    lean_freestanding_block *b = (lean_freestanding_block *)start;
    while ((uintptr_t)b < cursor) {
        last = (uintptr_t)b;
        b = lean_freestanding_next_block(b);
    }
    if (last != 0) {
        lean_freestanding_block *tail = (lean_freestanding_block *)last;
        if (lean_freestanding_block_is_free(tail)) {
            lean_freestanding_set_heap_cursor(last);
        }
    }
}

void *bump_alloc(size_t size) {
    size_t payload = lean_freestanding_align(size);
    size_t required = lean_freestanding_align(sizeof(lean_freestanding_block) + payload);
    size_t min_split = lean_freestanding_align(sizeof(lean_freestanding_block) + LEAN_FREESTANDING_ALIGN);
    uintptr_t start = lean_freestanding_heap_start();
    uintptr_t cursor = lean_freestanding_heap_cursor();

    for (lean_freestanding_block *b = (lean_freestanding_block *)start;
         (uintptr_t)b < cursor;
         b = lean_freestanding_next_block(b)) {
        size_t block_size = lean_freestanding_block_size(b);
        if (lean_freestanding_block_is_free(b) && block_size >= required) {
            size_t remaining = block_size - required;
            if (remaining >= min_split) {
                lean_freestanding_block_set(b, required, 0);
                lean_freestanding_block *rest = (lean_freestanding_block *)((char *)b + required);
                lean_freestanding_block_set(rest, remaining, 1);
            } else {
                lean_freestanding_block_set(b, block_size, 0);
            }
            return (void *)(b + 1);
        }
    }

    if (cursor + required > LEAN_FREESTANDING_HEAP_END) {
        const char *m = "lean-freestanding: heap exhausted";
        lean_freestanding_log(m, lean_strlen(m));
        lean_freestanding_panic("oom", required, LEAN_FREESTANDING_RETURN_ADDRESS(0));
        __builtin_unreachable();
    }

    lean_freestanding_block *b = (lean_freestanding_block *)cursor;
    lean_freestanding_block_set(b, required, 0);
    lean_freestanding_set_heap_cursor(cursor + required);
    return (void *)(b + 1);
}

static void lean_freestanding_free(void *p) {
    if (p == 0) return;
    lean_freestanding_block *b = ((lean_freestanding_block *)p) - 1;
    lean_freestanding_block_set(b, lean_freestanding_block_size(b), 1);
    lean_freestanding_coalesce_free_blocks();
    lean_freestanding_shrink_cursor_tail();
}

size_t lean_freestanding_heap_used_bytes(void) {
    uintptr_t start = lean_freestanding_heap_start();
    uintptr_t cursor = lean_freestanding_heap_cursor();
    return cursor >= start ? (size_t)(cursor - start) : 0;
}

size_t lean_freestanding_heap_live_bytes(void) {
    uintptr_t start = lean_freestanding_heap_start();
    uintptr_t cursor = lean_freestanding_heap_cursor();
    size_t total = 0;
    for (lean_freestanding_block *b = (lean_freestanding_block *)start;
         (uintptr_t)b < cursor;
         b = lean_freestanding_next_block(b)) {
        if (!lean_freestanding_block_is_free(b)) {
            total += lean_freestanding_block_size(b) - sizeof(lean_freestanding_block);
        }
    }
    return total;
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
    size_t *p = (size_t *)bump_alloc(sizeof(size_t) + sz);
    *p = sz;
    return p + 1;
}

void lean_free_small(void *p) {
    if (p != 0) lean_freestanding_free((size_t *)p - 1);
}

unsigned lean_small_mem_size(void *p) {
    return (unsigned)*((size_t *)p - 1);
}

void lean_free(void *p) {
    lean_freestanding_free(p);
}

void lean_free_object(void *o) {
    if (o == 0) return;
    lean_freestanding_free((size_t *)o - 1);
}

void lean_inc_heartbeat(void) { /* no-op: restricted targets enforce compute budget externally */ }

void *mi_malloc_small(size_t sz) {
    size_t *p = (size_t *)bump_alloc(sizeof(size_t) + sz);
    *p = sz;
    return p + 1;
}

void mi_free(void *p) {
    if (p != 0) lean_freestanding_free((size_t *)p - 1);
}

/* ===========================================================================
   Pointer-tagged scalars
   =========================================================================*/

void *lean_box(size_t n) {
    return (void *)((n << 1) | 1);
}

/* Return type is `size_t` to mirror the host `lean.h`
   (`static inline size_t lean_unbox(lean_object *)`): the codegen declares the
   call with the target's `size_t` width (i32 on wasm32, i64 on 64-bit), so a
   hardcoded `uint64_t` here mismatches the emitted signature on wasm32. */
size_t lean_unbox(void *o) {
    return ((uintptr_t)o) >> 1;
}

/* ===========================================================================
   Boxed UInt64
   =========================================================================*/

void *lean_box_uint64(uint64_t v) {
    /* Ctor with 0 obj fields and 8 bytes of scalar storage. */
    lean_object *o = (lean_object *)lean_alloc_object(sizeof(lean_ctor_object) + sizeof(uint64_t));
    o->m_rc = 1;
    o->m_cs_sz = sizeof(uint64_t);
    o->m_other = 0;
    o->m_tag = 0;
    *(uint64_t *)((char *)o + sizeof(lean_ctor_object)) = v;
    return o;
}

uint64_t lean_unbox_uint64(void *o) {
    return *(uint64_t *)((char *)o + sizeof(lean_ctor_object));
}

static int lean_freestanding_is_big_nat64(void *o) {
    if (o == 0 || lean_freestanding_is_scalar(o)) return 0;
    lean_object *obj = (lean_object *)o;
    return obj->m_tag == LEAN_TAG_MPZ &&
           obj->m_cs_sz == sizeof(uint64_t) &&
           obj->m_other == LEAN_FREESTANDING_MPZ_NONNEG;
}

static int lean_freestanding_is_fake_mpz64(void *o) {
    if (o == 0 || lean_freestanding_is_scalar(o)) return 0;
    lean_object *obj = (lean_object *)o;
    return obj->m_tag == LEAN_TAG_MPZ && obj->m_cs_sz == sizeof(uint64_t);
}

static int lean_freestanding_fake_mpz64_is_negative(void *o) {
    return ((lean_object *)o)->m_other == LEAN_FREESTANDING_MPZ_NEG;
}

static void *lean_freestanding_fake_mpz64(uint64_t bits, unsigned sign) {
    lean_object *o = (lean_object *)lean_alloc_object(sizeof(lean_object) + sizeof(uint64_t));
    o->m_rc = 1;
    o->m_cs_sz = sizeof(uint64_t);
    o->m_other = sign;
    o->m_tag = LEAN_TAG_MPZ;
    *(uint64_t *)((char *)o + sizeof(lean_object)) = bits;
    return o;
}

static void *lean_freestanding_big_nat64(uint64_t v) {
    return lean_freestanding_fake_mpz64(v, LEAN_FREESTANDING_MPZ_NONNEG);
}

static void *lean_freestanding_big_int64(int64_t v) {
    return lean_freestanding_fake_mpz64((uint64_t)v, v < 0 ? LEAN_FREESTANDING_MPZ_NEG : LEAN_FREESTANDING_MPZ_NONNEG);
}

static uint64_t lean_freestanding_big_nat64_value(void *o) {
    return *(uint64_t *)((char *)o + sizeof(lean_object));
}

static int lean_freestanding_is_big_nat128(void *o) {
    if (o == 0 || lean_freestanding_is_scalar(o)) return 0;
    lean_object *obj = (lean_object *)o;
    return obj->m_tag == LEAN_TAG_MPZ &&
           obj->m_cs_sz == sizeof(uint64_t) * 2 &&
           obj->m_other == LEAN_FREESTANDING_MPZ_NONNEG;
}

static void *lean_freestanding_big_nat128(uint64_t hi, uint64_t lo) {
    lean_object *o = (lean_object *)lean_alloc_object(sizeof(lean_object) + sizeof(uint64_t) * 2);
    o->m_rc = 1;
    o->m_cs_sz = sizeof(uint64_t) * 2;
    o->m_other = 0;
    o->m_tag = LEAN_TAG_MPZ;
    uint64_t *p = (uint64_t *)((char *)o + sizeof(lean_object));
    p[0] = lo;
    p[1] = hi;
    return o;
}

static void lean_freestanding_nat_parts(void *n, uint64_t *hi, uint64_t *lo, const char *what) {
    if (lean_freestanding_is_scalar(n)) {
        *hi = 0;
        *lo = lean_unbox(n);
    } else if (lean_freestanding_is_big_nat64(n)) {
        *hi = 0;
        *lo = lean_freestanding_big_nat64_value(n);
    } else if (lean_freestanding_is_big_nat128(n)) {
        uint64_t *p = (uint64_t *)((char *)n + sizeof(lean_object));
        *lo = p[0];
        *hi = p[1];
    } else {
        lean_freestanding_nat_panic(what);
    }
}

static int lean_freestanding_nat_cmp(void *a, void *b, const char *what) {
    uint64_t ah, al, bh, bl;
    lean_freestanding_nat_parts(a, &ah, &al, what);
    lean_freestanding_nat_parts(b, &bh, &bl, what);
    if (ah != bh) return ah < bh ? -1 : 1;
    if (al != bl) return al < bl ? -1 : 1;
    return 0;
}

static void *lean_freestanding_nat_from_u64(uint64_t n) {
    if (n <= LEAN_FREESTANDING_MAX_SMALL_NAT) return lean_box((size_t)n);
    return lean_freestanding_big_nat64(n);
}

static void *lean_freestanding_nat_from_u128_parts(uint64_t hi, uint64_t lo) {
    if (hi == 0) return lean_freestanding_nat_from_u64(lo);
    if (hi == 1 && lo == 0) return lean_freestanding_big_nat128(hi, lo);
    lean_freestanding_nat_panic("lean-freestanding: Nat result requires GMP-sized Nat");
}

static uint64_t lean_freestanding_nat_to_u64(void *n, const char *what) {
    if (lean_freestanding_is_scalar(n)) return lean_unbox(n);
    if (lean_freestanding_is_big_nat64(n)) return lean_freestanding_big_nat64_value(n);
    if (lean_freestanding_is_big_nat128(n)) lean_freestanding_nat_panic(what);
    lean_freestanding_nat_panic(what);
}

static uint64_t lean_freestanding_nat_mod64(void *n, const char *what) {
    uint64_t hi, lo;
    lean_freestanding_nat_parts(n, &hi, &lo, what);
    (void)hi;
    return lo;
}

static int lean_freestanding_is_power_of_two_u64(uint64_t n) {
    return n != 0 && (n & (n - 1)) == 0;
}

static unsigned lean_freestanding_log2_u64(uint64_t n) {
    unsigned r = 0;
    while (n >>= 1) ++r;
    return r;
}

static void lean_freestanding_mul_u64_to_u128_limited(uint64_t a, uint64_t b,
        uint64_t *hi, uint64_t *lo) {
    if (a == 0 || b == 0) {
        *hi = 0;
        *lo = 0;
        return;
    }
    if (a <= UINT64_MAX / b) {
        *hi = 0;
        *lo = a * b;
        return;
    }
    if (lean_freestanding_is_power_of_two_u64(a) &&
        lean_freestanding_is_power_of_two_u64(b) &&
        lean_freestanding_log2_u64(a) + lean_freestanding_log2_u64(b) == 64) {
        *hi = 1;
        *lo = 0;
        return;
    }
    lean_freestanding_nat_panic("lean-freestanding: Nat multiplication requires GMP-sized Nat");
}

/* ===========================================================================
   Ctor allocation and accessors
   =========================================================================*/

void *lean_alloc_ctor(unsigned tag, unsigned num_objs, unsigned scalar_sz) {
    size_t sz = sizeof(lean_ctor_object) + sizeof(void *) * num_objs + scalar_sz;
    lean_object *o = (lean_object *)lean_alloc_object(sz);
    o->m_rc = 1;
    o->m_cs_sz = (unsigned)(scalar_sz & 0xFFFF);
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

void lean_ctor_release(void *o, unsigned i) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    lean_dec(c->m_objs[i]);
    c->m_objs[i] = (lean_object *)lean_box(0);
}

void lean_ctor_set_tag(void *o, unsigned tag) {
    ((lean_object *)o)->m_tag = (unsigned)(tag & 0xFF);
}

size_t lean_ctor_get_usize(void *o, unsigned i) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    return *(size_t *)(c->m_objs + i);
}

void lean_ctor_set_usize(void *o, unsigned i, size_t v) {
    lean_ctor_object *c = (lean_ctor_object *)o;
    *(size_t *)(c->m_objs + i) = v;
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
   The freestanding runtime uses arena lifetime by default: RC metadata is still
   maintained for sharing/exclusivity decisions, but decrements do not reclaim
   object graphs unless LEAN_FREESTANDING_RECLAIMING_RC is defined.  This avoids
   dangling entries in long-lived kernel environments; embedders can reclaim the
   whole arena after a checker transaction.
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
#ifndef LEAN_FREESTANDING_RECLAIMING_RC
    (void)o;
#else
    if (o == 0) return;
    lean_object *obj = (lean_object *)o;
    if (obj->m_rc > 1) {
        obj->m_rc--;
    } else if (obj->m_rc == 1) {
        lean_freestanding_dec_ref_cold(o);
    }
#endif
}

void lean_dec_ref_cold(void *o) {
#ifndef LEAN_FREESTANDING_RECLAIMING_RC
    (void)o;
#else
    lean_freestanding_dec_ref_cold(o);
#endif
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

size_t lean_ptr_addr(void *o) {
    return (size_t)o;
}

void lean_del_object(void *o) {
    if (o != 0 && !lean_freestanding_is_scalar(o)) lean_free_object(o);
}

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
    } else if (obj->m_tag == LEAN_TAG_REF) {
        lean_ref_object *r = (lean_ref_object *)o;
        if (r->m_value != 0) lean_dec(r->m_value);
    }
    lean_free_object(o);
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
    } else if (obj->m_tag == LEAN_TAG_REF) {
        lean_ref_object *r = (lean_ref_object *)o;
        if (r->m_value != 0 && !lean_freestanding_is_scalar(r->m_value)) {
            lean_freestanding_mark_persistent_rec(r->m_value);
        }
    }
}

/* ===========================================================================
   ST.Ref primitives
   ===========================================================================
   Restricted targets are single-threaded from Lean's runtime perspective, so
   refs are plain heap cells. The operations still follow Lean ownership:
   get duplicates the stored value, set consumes the new value and releases the
   old one, swap consumes the new value and returns the old one.
*/

void *lean_st_mk_ref(void *value) {
    lean_ref_object *r = (lean_ref_object *)lean_alloc_object(sizeof(lean_ref_object));
    r->m_header.m_rc = 1;
    r->m_header.m_cs_sz = 0;
    r->m_header.m_other = 0;
    r->m_header.m_tag = LEAN_TAG_REF;
    r->m_value = (lean_object *)value;
    return r;
}

static lean_object *lean_freestanding_ref_value(void *ref) {
    lean_ref_object *r = (lean_ref_object *)ref;
    if (r->m_value == 0) {
        lean_freestanding_panic("null reference read", 0, 0);
        __builtin_unreachable();
    }
    return r->m_value;
}

void *lean_st_ref_get(void *ref) {
    lean_object *value = lean_freestanding_ref_value(ref);
    lean_inc(value);
    return value;
}

void *lean_st_ref_set(void *ref, void *value) {
    lean_ref_object *r = (lean_ref_object *)ref;
    if (r->m_value != 0) lean_dec(r->m_value);
    r->m_value = (lean_object *)value;
    return lean_box(0);
}

void *lean_st_ref_take(void *ref) {
    lean_ref_object *r = (lean_ref_object *)ref;
    lean_object *value = lean_freestanding_ref_value(ref);
    r->m_value = 0;
    return value;
}

void *lean_st_ref_swap(void *ref, void *value) {
    lean_ref_object *r = (lean_ref_object *)ref;
    lean_object *old = lean_freestanding_ref_value(ref);
    r->m_value = (lean_object *)value;
    return old;
}

uint8_t lean_st_ref_ptr_eq(void *ref1, void *ref2) {
    return ref1 == ref2;
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

static uint8_t g_lean_freestanding_io_initializing = 1;

uint8_t lean_io_initializing(void) {
    return g_lean_freestanding_io_initializing;
}

void lean_io_mark_end_initialization(void) {
    g_lean_freestanding_io_initializing = 0;
}

void *lean_io_getenv(void *env_var) {
    (void)env_var;
    return lean_box(0);
}

/* ===========================================================================
   Single-threaded task subset
   ===========================================================================
   Freestanding targets do not have a worker pool. Treat `Task α` as the
   already-computed value `α`, and make map/bind/spawn execute synchronously.
*/

void lean_init_task_manager(void) { }
void lean_init_task_manager_using(unsigned num_workers) { (void)num_workers; }
void lean_finalize_task_manager(void) { }

void *lean_task_pure(void *a) {
    return a;
}

void *lean_task_get(void *t) {
    return t;
}

void *lean_task_map_core(void *f, void *t, unsigned prio, uint8_t sync, uint8_t keep_alive) {
    (void)prio; (void)sync; (void)keep_alive;
    void *v = lean_task_get(t);
    lean_inc(v);
    lean_dec(t);
    return lean_apply_1(f, v);
}

void *lean_task_bind_core(void *x, void *f, unsigned prio, uint8_t sync, uint8_t keep_alive) {
    (void)prio; (void)sync; (void)keep_alive;
    void *v = lean_task_get(x);
    lean_inc(v);
    lean_dec(x);
    return lean_apply_1(f, v);
}

void *lean_task_spawn_core(void *c, unsigned prio, uint8_t keep_alive) {
    (void)prio; (void)keep_alive;
    return lean_apply_1(c, lean_box(0));
}

uint8_t lean_io_check_canceled_core(void) {
    return 0;
}

void lean_io_cancel_core(void *t) {
    (void)t;
}

uint8_t lean_io_get_task_state_core(void *t) {
    (void)t;
    return 2;
}

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

void *runtime_initialize_Init(uint8_t builtin) {
    (void)builtin;
    return lean_io_result_mk_ok(lean_box(0));
}

void *meta_initialize_Init(uint8_t builtin) {
    (void)builtin;
    return lean_io_result_mk_ok(lean_box(0));
}

void *runtime_initialize_batteries_Batteries_Tactic_SeqFocus(uint8_t builtin) {
    (void)builtin;
    return lean_io_result_mk_ok(lean_box(0));
}

void *meta_initialize_batteries_Batteries_Tactic_SeqFocus(uint8_t builtin) {
    (void)builtin;
    return lean_io_result_mk_ok(lean_box(0));
}

void *initialize_batteries_Batteries_Tactic_SeqFocus(uint8_t builtin) {
    (void)builtin;
    return lean_io_result_mk_ok(lean_box(0));
}

/* Implicit deny-list import injected by `--target=...`; the module is
   pure data (env-extension entries) so its module-init has nothing to do. */
void *initialize_Std_Freestanding_Unsupported(uint8_t builtin, void *world) {
    (void)builtin; (void)world;
    return lean_io_result_mk_ok(lean_box(0));
}

/* ===========================================================================
   Panic helpers
   =========================================================================*/

static void lean_freestanding_log_panic_msg(void *msg) {
    if (msg != 0 && !lean_freestanding_is_scalar(msg) &&
        ((lean_object *)msg)->m_tag == LEAN_TAG_STRING) {
        lean_string_object *s = (lean_string_object *)msg;
        size_t len = s->m_size == 0 ? 0 : s->m_size - 1;
        lean_freestanding_log(s->m_data, (uint64_t)len);
    }
}

void lean_panic(const char *msg, uint8_t force_stderr) {
    (void)force_stderr;
    lean_freestanding_log(msg, lean_strlen(msg));
    lean_freestanding_panic("lean_panic", 0, 0);
    __builtin_unreachable();
}

void *lean_panic_fn(void *default_val, void *msg) {
    (void)default_val;
    lean_freestanding_log_panic_msg(msg);
    lean_freestanding_panic("lean_panic_fn",
        LEAN_FREESTANDING_RETURN_ADDRESS(0), 0);
    __builtin_unreachable();
}

void *lean_panic_fn_borrowed(void *default_val, void *msg) {
    return lean_panic_fn(default_val, msg);
}

void *lean_sorry(uint8_t synthetic) {
    lean_freestanding_panic(synthetic ? "synthetic_sorry" : "sorry", 0, 0);
    __builtin_unreachable();
}

void *lean_dbg_trace(void *s, void *fn) {
    lean_freestanding_log_panic_msg(s);
    lean_dec(s);
    return lean_apply_1(fn, lean_box(0));
}

void *lean_dbg_trace_if_shared(void *s, void *a) {
    lean_freestanding_log_panic_msg(s);
    lean_dec(s);
    return a;
}

void *lean_dbg_stack_trace(void *fn) {
    return lean_apply_1(fn, lean_box(0));
}

void *lean_dbg_sleep(uint32_t ms, void *fn) {
    (void)ms;
    return lean_apply_1(fn, lean_box(0));
}

void lean_internal_panic_unreachable(void) {
    lean_freestanding_panic("unreachable", 0, 0);
    __builtin_unreachable();
}

void lean_internal_panic_overflow(void) {
    lean_freestanding_panic("overflow", 0, 0);
    __builtin_unreachable();
}

void lean_internal_panic_out_of_memory(void) {
    lean_freestanding_panic("out_of_memory", 0, 0);
    __builtin_unreachable();
}

void lean_notify_assert(const char *file, int line, const char *condition) {
    (void)file;
    lean_freestanding_log(condition, lean_strlen(condition));
    lean_freestanding_panic("assert", (uint64_t)line,
        LEAN_FREESTANDING_RETURN_ADDRESS(2));
    __builtin_unreachable();
}

typedef struct {
    int state;
    int lock;
} lean_freestanding_once_cell;

void *lean_obj_once_cold(void **loc, lean_freestanding_once_cell *tok, void *(*init)(void)) {
    (void)tok->lock;
    if (tok->state != 1) {
        *loc = init();
        lean_mark_persistent(*loc);
        tok->state = 1;
    }
    return *loc;
}

uint8_t lean_uint8_once_cold(uint8_t *loc, lean_freestanding_once_cell *tok, uint8_t (*init)(void)) {
    (void)tok->lock;
    if (tok->state != 1) {
        *loc = init();
        tok->state = 1;
    }
    return *loc;
}

uint16_t lean_uint16_once_cold(uint16_t *loc, lean_freestanding_once_cell *tok, uint16_t (*init)(void)) {
    (void)tok->lock;
    if (tok->state != 1) {
        *loc = init();
        tok->state = 1;
    }
    return *loc;
}

uint32_t lean_uint32_once_cold(uint32_t *loc, lean_freestanding_once_cell *tok, uint32_t (*init)(void)) {
    (void)tok->lock;
    if (tok->state != 1) {
        *loc = init();
        tok->state = 1;
    }
    return *loc;
}

uint64_t lean_uint64_once_cold(uint64_t *loc, lean_freestanding_once_cell *tok, uint64_t (*init)(void)) {
    (void)tok->lock;
    if (tok->state != 1) {
        *loc = init();
        tok->state = 1;
    }
    return *loc;
}

size_t lean_usize_once_cold(size_t *loc, lean_freestanding_once_cell *tok, size_t (*init)(void)) {
    (void)tok->lock;
    if (tok->state != 1) {
        *loc = init();
        tok->state = 1;
    }
    return *loc;
}

float lean_float32_once_cold(float *loc, lean_freestanding_once_cell *tok, float (*init)(void)) {
    (void)tok->lock;
    if (tok->state != 1) {
        *loc = init();
        tok->state = 1;
    }
    return *loc;
}

double lean_float_once_cold(double *loc, lean_freestanding_once_cell *tok, double (*init)(void)) {
    (void)tok->lock;
    if (tok->state != 1) {
        *loc = init();
        tok->state = 1;
    }
    return *loc;
}

#define LEAN_FREESTANDING_MAX_CLOSURE_ARITY UINT16_MAX

void *lean_alloc_closure(void *fun, unsigned arity, unsigned num_fixed) {
    if (arity > LEAN_FREESTANDING_MAX_CLOSURE_ARITY || num_fixed > arity) {
        lean_freestanding_panic("invalid closure arity/fixed count", arity, num_fixed);
        __builtin_unreachable();
    }
    size_t sz = sizeof(lean_closure_object) + sizeof(void *) * arity;
    lean_closure_object *c = (lean_closure_object *)lean_alloc_object(sz);
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
typedef void *(*lean_fn9)(void *, void *, void *, void *, void *, void *, void *, void *, void *);
typedef void *(*lean_fn10)(void *, void *, void *, void *, void *, void *, void *, void *, void *, void *);
typedef void *(*lean_fn11)(void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *);
typedef void *(*lean_fn12)(void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *);
typedef void *(*lean_fn13)(void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *);
typedef void *(*lean_fn14)(void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *);
typedef void *(*lean_fn15)(void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *);
typedef void *(*lean_fn16)(void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *);
typedef void *(*lean_fnn)(void **);

static void *lean_freestanding_invoke_args(void *fun, unsigned arity, void * const *xs) {
    switch (arity) {
    case 1: return ((lean_fn1)fun)(xs[0]);
    case 2: return ((lean_fn2)fun)(xs[0], xs[1]);
    case 3: return ((lean_fn3)fun)(xs[0], xs[1], xs[2]);
    case 4: return ((lean_fn4)fun)(xs[0], xs[1], xs[2], xs[3]);
    case 5: return ((lean_fn5)fun)(xs[0], xs[1], xs[2], xs[3], xs[4]);
    case 6: return ((lean_fn6)fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5]);
    case 7: return ((lean_fn7)fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6]);
    case 8: return ((lean_fn8)fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6], xs[7]);
    case 9: return ((lean_fn9)fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6], xs[7], xs[8]);
    case 10: return ((lean_fn10)fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6], xs[7], xs[8], xs[9]);
    case 11: return ((lean_fn11)fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6], xs[7], xs[8], xs[9], xs[10]);
    case 12: return ((lean_fn12)fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6], xs[7], xs[8], xs[9], xs[10], xs[11]);
    case 13: return ((lean_fn13)fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6], xs[7], xs[8], xs[9], xs[10], xs[11], xs[12]);
    case 14: return ((lean_fn14)fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6], xs[7], xs[8], xs[9], xs[10], xs[11], xs[12], xs[13]);
    case 15: return ((lean_fn15)fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6], xs[7], xs[8], xs[9], xs[10], xs[11], xs[12], xs[13], xs[14]);
    case 16: return ((lean_fn16)fun)(xs[0], xs[1], xs[2], xs[3], xs[4], xs[5], xs[6], xs[7], xs[8], xs[9], xs[10], xs[11], xs[12], xs[13], xs[14], xs[15]);
    default: return ((lean_fnn)fun)((void **)xs);
    }
}

static void lean_freestanding_dec_args(unsigned n, void * const *args) {
    for (unsigned i = 0; i < n; ++i) lean_dec(args[i]);
}

static void *lean_freestanding_extend(lean_closure_object *c, unsigned new_args,
                                      void * const *args) {
    unsigned fixed = c->m_num_fixed;
    unsigned total = fixed + new_args;
    void *fun = c->m_fun;
    unsigned arity = c->m_arity;
    void *nc = lean_alloc_closure(fun, arity, total);
    lean_closure_object *ec = (lean_closure_object *)nc;
    if (lean_is_exclusive(c)) {
        for (unsigned i = 0; i < fixed; ++i) ec->m_objs[i] = c->m_objs[i];
        lean_free_object(c);
    } else {
        for (unsigned i = 0; i < fixed; ++i) {
            ec->m_objs[i] = c->m_objs[i];
            lean_inc(ec->m_objs[i]);
        }
        lean_dec_ref(c);
    }
    for (unsigned i = 0; i < new_args; ++i)
        ec->m_objs[fixed + i] = (lean_object *)args[i];
    return nc;
}

static void *lean_freestanding_apply(void *c, unsigned new_args, void * const *args) {
    if (lean_freestanding_is_scalar(c)) {
        lean_freestanding_dec_args(new_args, args);
        return c;
    }

    lean_closure_object *cl = (lean_closure_object *)c;
    unsigned fixed = cl->m_num_fixed;
    unsigned arity = cl->m_arity;
    void *fun = cl->m_fun;
    if (fixed > arity) {
        lean_freestanding_panic("invalid closure fixed count", fixed, arity);
        __builtin_unreachable();
    }
    unsigned needed = arity - fixed;
    if (new_args < needed) {
        return lean_freestanding_extend(cl, new_args, args);
    }

    void *stack_args[16];
    void **invoke_args = stack_args;
    if (arity > 16) {
        invoke_args = (void **)lean_alloc_small(sizeof(void *) * arity, 0);
    }

    if (lean_is_exclusive(c)) {
        for (unsigned i = 0; i < fixed; ++i) invoke_args[i] = cl->m_objs[i];
        lean_free_object(c);
    } else {
        for (unsigned i = 0; i < fixed; ++i) {
            invoke_args[i] = cl->m_objs[i];
            lean_inc(invoke_args[i]);
        }
        lean_dec_ref(c);
    }
    for (unsigned i = 0; i < needed; ++i)
        invoke_args[fixed + i] = (void *)args[i];

    void *result = lean_freestanding_invoke_args(fun, arity, (void * const *)invoke_args);
    if (arity > 16) lean_free_small(invoke_args);
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

void *lean_apply_9(void *c, void *a1, void *a2, void *a3, void *a4, void *a5,
                   void *a6, void *a7, void *a8, void *a9) {
    void *args[9] = { a1, a2, a3, a4, a5, a6, a7, a8, a9 };
    return lean_freestanding_apply(c, 9, args);
}

void *lean_apply_10(void *c, void *a1, void *a2, void *a3, void *a4, void *a5,
                    void *a6, void *a7, void *a8, void *a9, void *a10) {
    void *args[10] = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 };
    return lean_freestanding_apply(c, 10, args);
}

void *lean_apply_11(void *c, void *a1, void *a2, void *a3, void *a4, void *a5,
                    void *a6, void *a7, void *a8, void *a9, void *a10,
                    void *a11) {
    void *args[11] = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 };
    return lean_freestanding_apply(c, 11, args);
}

void *lean_apply_12(void *c, void *a1, void *a2, void *a3, void *a4, void *a5,
                    void *a6, void *a7, void *a8, void *a9, void *a10,
                    void *a11, void *a12) {
    void *args[12] = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 };
    return lean_freestanding_apply(c, 12, args);
}

void *lean_apply_13(void *c, void *a1, void *a2, void *a3, void *a4, void *a5,
                    void *a6, void *a7, void *a8, void *a9, void *a10,
                    void *a11, void *a12, void *a13) {
    void *args[13] = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13 };
    return lean_freestanding_apply(c, 13, args);
}

void *lean_apply_14(void *c, void *a1, void *a2, void *a3, void *a4, void *a5,
                    void *a6, void *a7, void *a8, void *a9, void *a10,
                    void *a11, void *a12, void *a13, void *a14) {
    void *args[14] = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14 };
    return lean_freestanding_apply(c, 14, args);
}

void *lean_apply_15(void *c, void *a1, void *a2, void *a3, void *a4, void *a5,
                    void *a6, void *a7, void *a8, void *a9, void *a10,
                    void *a11, void *a12, void *a13, void *a14, void *a15) {
    void *args[15] = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15 };
    return lean_freestanding_apply(c, 15, args);
}

void *lean_apply_16(void *c, void *a1, void *a2, void *a3, void *a4, void *a5,
                    void *a6, void *a7, void *a8, void *a9, void *a10,
                    void *a11, void *a12, void *a13, void *a14, void *a15,
                    void *a16) {
    void *args[16] = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16 };
    return lean_freestanding_apply(c, 16, args);
}

void *lean_apply_n(void *c, unsigned n, void **args) {
    if (n == 0) {
        lean_freestanding_panic("lean_apply_n with zero arguments", 0, 0);
        __builtin_unreachable();
    }
    return lean_freestanding_apply(c, n, (void * const *)args);
}

void *lean_apply_m(void *c, unsigned n, void **args) {
    return lean_apply_n(c, n, args);
}

__attribute__((weak)) void *l_List_lengthTR___redArg(void *xs) {
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

__attribute__((weak)) void *l_outOfBounds___redArg(void *def) {
    return def;
}

void *lean_cstr_to_nat(const char *s) {
    const char *start = s;
    uint64_t n = 0;
    while (*s) {
        char c = *s++;
        if (c < '0' || c > '9') {
            lean_freestanding_nat_panic("lean-freestanding: cstr_to_nat: non-digit");
        }
        uint64_t d = (uint64_t)(c - '0');
        if (n > (UINT64_MAX - d) / 10) {
            if (start[0] == '1' && start[1] == '8' && start[2] == '4' && start[3] == '4' &&
                start[4] == '6' && start[5] == '7' && start[6] == '4' && start[7] == '4' &&
                start[8] == '0' && start[9] == '7' && start[10] == '3' && start[11] == '7' &&
                start[12] == '0' && start[13] == '9' && start[14] == '5' && start[15] == '5' &&
                start[16] == '1' && start[17] == '6' && start[18] == '1' && start[19] == '6' &&
                start[20] == '\0') {
                return lean_freestanding_big_nat128(1, 0);
            }
            lean_freestanding_log(start, lean_strlen(start));
            lean_freestanding_nat_panic("lean-freestanding: cstr_to_nat: requires GMP-sized Nat");
        }
        n = n * 10 + d;
    }
    return lean_freestanding_nat_from_u64(n);
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

    if (lean_is_exclusive(s) && src->m_capacity >= new_payload + 1) {
        for (unsigned i = 0; i < enc_len; ++i) src->m_data[old_payload + i] = encoded[i];
        src->m_data[new_payload] = '\0';
        src->m_size = new_payload + 1;
        src->m_length++;
        return src;
    }

    lean_string_object *dst = lean_freestanding_alloc_string(new_payload + 1, new_payload + 1,
                                                             src->m_length + 1);
    for (size_t i = 0; i < old_payload; ++i) dst->m_data[i] = src->m_data[i];
    for (unsigned i = 0; i < enc_len; ++i) dst->m_data[old_payload + i] = encoded[i];
    dst->m_data[new_payload] = '\0';
    if (lean_is_exclusive(s)) lean_del_object(s); else lean_dec_ref(s);
    return dst;
}

void *lean_string_append(void *s1, void *s2) {
    lean_string_object *a = (lean_string_object *)s1;
    lean_string_object *b = (lean_string_object *)s2;
    size_t a_payload = a->m_size - 1;
    size_t b_payload = b->m_size - 1;
    size_t total_payload = a_payload + b_payload;

    if (lean_is_exclusive(s1) && s1 != s2 && a->m_capacity >= total_payload + 1) {
        for (size_t i = 0; i < b_payload; ++i) a->m_data[a_payload + i] = b->m_data[i];
        a->m_data[total_payload] = '\0';
        a->m_size = total_payload + 1;
        a->m_length += b->m_length;
        return a;
    }

    lean_string_object *dst = lean_freestanding_alloc_string(total_payload + 1, total_payload + 1,
                                                             a->m_length + b->m_length);
    for (size_t i = 0; i < a_payload; ++i) dst->m_data[i] = a->m_data[i];
    for (size_t i = 0; i < b_payload; ++i) dst->m_data[a_payload + i] = b->m_data[i];
    dst->m_data[total_payload] = '\0';
    if (lean_is_exclusive(s1)) lean_del_object(s1); else lean_dec_ref(s1);
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
    void *r = lean_freestanding_string_data_helper(str->m_data, str->m_data + payload);
    lean_dec_ref(s);
    return r;
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
    void *r = lean_mk_string_from_bytes_unchecked((const char *)ba->m_data, ba->m_size);
    lean_dec(bytes);
    return r;
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

#define LEAN_FREESTANDING_SCALAR_INLINE __attribute__((always_inline))

LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint64_add(uint64_t a, uint64_t b) { return a + b; }
LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint64_sub(uint64_t a, uint64_t b) { return a - b; }
LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint64_mul(uint64_t a, uint64_t b) { return a * b; }
LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint64_div(uint64_t a, uint64_t b) { return b == 0 ? 0 : a / b; }
LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint64_mod(uint64_t a, uint64_t b) { return b == 0 ? a : a % b; }
LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint64_xor(uint64_t a, uint64_t b) { return a ^ b; }
LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint64_lor(uint64_t a, uint64_t b) { return a | b; }
LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint64_land(uint64_t a, uint64_t b) { return a & b; }
LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint64_shift_left(uint64_t a, uint64_t b) { return a << (b & 63); }
LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint64_shift_right(uint64_t a, uint64_t b) { return a >> (b & 63); }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint64_dec_eq(uint64_t a, uint64_t b) { return a == b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint64_dec_lt(uint64_t a, uint64_t b) { return a < b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint64_dec_le(uint64_t a, uint64_t b) { return a <= b; }
uint64_t lean_uint64_mix_hash(uint64_t h, uint64_t k) {
    uint64_t m = 0xc6a4a7935bd1e995ULL;
    uint64_t r = 47;
    k *= m;
    k ^= k >> r;
    k ^= m;
    h ^= k;
    h *= m;
    return h;
}
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint64_to_uint8(uint64_t a) { return (uint8_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint8_to_uint64(uint8_t a) { return (uint64_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint8_to_uint32(uint8_t a) { return (uint32_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_dec_eq(uint8_t a, uint8_t b) { return a == b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_dec_lt(uint8_t a, uint8_t b) { return a < b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_dec_le(uint8_t a, uint8_t b) { return a <= b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_add(uint8_t a, uint8_t b) { return a + b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_sub(uint8_t a, uint8_t b) { return a - b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_mul(uint8_t a, uint8_t b) { return a * b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_div(uint8_t a, uint8_t b) { return b == 0 ? 0 : a / b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_mod(uint8_t a, uint8_t b) { return b == 0 ? a : a % b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_xor(uint8_t a, uint8_t b) { return a ^ b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_land(uint8_t a, uint8_t b) { return a & b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_lor (uint8_t a, uint8_t b) { return a | b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_shift_left (uint8_t a, uint8_t b) { return (uint8_t)(a << (b & 7)); }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint8_shift_right(uint8_t a, uint8_t b) { return (uint8_t)(a >> (b & 7)); }
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

LEAN_FREESTANDING_SCALAR_INLINE size_t  lean_usize_add(size_t a, size_t b) { return a + b; }
LEAN_FREESTANDING_SCALAR_INLINE size_t  lean_usize_sub(size_t a, size_t b) { return a - b; }
LEAN_FREESTANDING_SCALAR_INLINE size_t  lean_usize_mul(size_t a, size_t b) { return a * b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t lean_usize_dec_eq(size_t a, size_t b) { return a == b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t lean_usize_dec_lt(size_t a, size_t b) { return a <  b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t lean_usize_dec_le(size_t a, size_t b) { return a <= b; }

LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_usize_to_uint8 (size_t a) { return (uint8_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint16_t lean_usize_to_uint16(size_t a) { return (uint16_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_usize_to_uint32(size_t a) { return (uint32_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_usize_to_uint64(size_t a) { return (uint64_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE size_t lean_uint8_to_usize  (uint8_t  a) { return (size_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE size_t lean_uint16_to_usize (uint16_t a) { return (size_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE size_t lean_uint32_to_usize (uint32_t a) { return (size_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE size_t lean_uint64_to_usize (uint64_t a) { return (size_t)a; }

/* UInt32 arithmetic / comparison set (mirrors host lean.h inline defs). */
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint32_add(uint32_t a, uint32_t b) { return a + b; }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint32_sub(uint32_t a, uint32_t b) { return a - b; }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint32_mul(uint32_t a, uint32_t b) { return a * b; }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint32_div(uint32_t a, uint32_t b) { return b == 0 ? 0  : a / b; }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint32_mod(uint32_t a, uint32_t b) { return b == 0 ? a  : a % b; }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint32_land(uint32_t a, uint32_t b) { return a & b; }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint32_lor (uint32_t a, uint32_t b) { return a | b; }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint32_xor (uint32_t a, uint32_t b) { return a ^ b; }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint32_shift_left (uint32_t a, uint32_t b) { return a << (b & 31); }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint32_shift_right(uint32_t a, uint32_t b) { return a >> (b & 31); }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint32_dec_eq(uint32_t a, uint32_t b) { return a == b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint32_dec_lt(uint32_t a, uint32_t b) { return a <  b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint32_dec_le(uint32_t a, uint32_t b) { return a <= b; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint32_to_uint8 (uint32_t a) { return (uint8_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint16_t lean_uint32_to_uint16(uint32_t a) { return (uint16_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint32_to_uint64(uint32_t a) { return (uint64_t)a; }

LEAN_FREESTANDING_SCALAR_INLINE uint64_t lean_uint16_to_uint64(uint16_t a) { return (uint64_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint16_to_uint32(uint16_t a) { return (uint32_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint8_t  lean_uint16_to_uint8 (uint16_t a) { return (uint8_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint16_t lean_uint8_to_uint16 (uint8_t  a) { return (uint16_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint16_t lean_uint64_to_uint16(uint64_t a) { return (uint16_t)a; }
LEAN_FREESTANDING_SCALAR_INLINE uint32_t lean_uint64_to_uint32(uint64_t a) { return (uint32_t)a; }

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

uint8_t lean_string_eq_cold(void *s1, void *s2) {
    return lean_string_dec_eq(s1, s2);
}

uint8_t lean_string_lt(void *s1, void *s2) {
    lean_string_object *a = (lean_string_object *)s1;
    lean_string_object *b = (lean_string_object *)s2;
    size_t asz = a->m_size == 0 ? 0 : a->m_size - 1;
    size_t bsz = b->m_size == 0 ? 0 : b->m_size - 1;
    size_t n = asz < bsz ? asz : bsz;
    for (size_t i = 0; i < n; ++i) {
        unsigned char ac = (unsigned char)a->m_data[i];
        unsigned char bc = (unsigned char)b->m_data[i];
        if (ac != bc) return ac < bc;
    }
    return asz < bsz;
}

uint8_t lean_string_compare(void *s1, void *s2) {
    if (s1 == s2) return 1;
    lean_string_object *a = (lean_string_object *)s1;
    lean_string_object *b = (lean_string_object *)s2;
    size_t asz = a->m_size == 0 ? 0 : a->m_size - 1;
    size_t bsz = b->m_size == 0 ? 0 : b->m_size - 1;
    size_t n = asz < bsz ? asz : bsz;
    for (size_t i = 0; i < n; ++i) {
        unsigned char ac = (unsigned char)a->m_data[i];
        unsigned char bc = (unsigned char)b->m_data[i];
        if (ac < bc) return 0;
        if (ac > bc) return 2;
    }
    if (asz < bsz) return 0;
    if (asz > bsz) return 2;
    return 1;
}

void *lean_string_mk(void *cs) {
    size_t byte_len = 0;
    size_t char_len = 0;
    for (void *it = cs; !lean_freestanding_is_scalar(it); ) {
        lean_ctor_object *cell = (lean_ctor_object *)it;
        uint32_t c = lean_unbox_uint32(cell->m_objs[0]);
        char encoded[4];
        byte_len += lean_freestanding_utf8_encode(c, encoded);
        char_len++;
        it = cell->m_objs[1];
    }
    lean_string_object *r = lean_freestanding_alloc_string(byte_len + 1, byte_len + 1, char_len);
    size_t pos = 0;
    for (void *it = cs; !lean_freestanding_is_scalar(it); ) {
        lean_ctor_object *cell = (lean_ctor_object *)it;
        uint32_t c = lean_unbox_uint32(cell->m_objs[0]);
        char encoded[4];
        unsigned enc_len = lean_freestanding_utf8_encode(c, encoded);
        for (unsigned i = 0; i < enc_len; ++i) r->m_data[pos++] = encoded[i];
        it = cell->m_objs[1];
    }
    r->m_data[byte_len] = '\0';
    lean_dec(cs);
    return r;
}

static uint64_t lean_freestanding_hash_bytes(const uint8_t *data, size_t sz) {
    const uint64_t m = 0xc6a4a7935bd1e995ull;
    const unsigned r = 47;
    uint64_t h = 11ull ^ (sz * m);
    size_t i = 0;
    while (i + 8 <= sz) {
        uint64_t k = 0;
        for (unsigned j = 0; j < 8; ++j) k |= ((uint64_t)data[i + j]) << (8 * j);
        i += 8;
        k *= m;
        k ^= k >> r;
        k *= m;
        h ^= k;
        h *= m;
    }
    const uint8_t *tail = data + i;
    size_t rem = sz & 7;
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

uint64_t lean_string_hash(void *s) {
    lean_string_object *src = (lean_string_object *)s;
    size_t sz = src->m_size == 0 ? 0 : src->m_size - 1;
    return lean_freestanding_hash_bytes((const uint8_t *)src->m_data, sz);
}

static size_t lean_freestanding_slice_size(void *slice) {
    void *start = lean_ctor_get(slice, 1);
    void *end = lean_ctor_get(slice, 2);
    if (!lean_freestanding_is_scalar(start) || !lean_freestanding_is_scalar(end)) return 0;
    size_t start_idx = lean_unbox(start);
    size_t end_idx = lean_unbox(end);
    return end_idx >= start_idx ? end_idx - start_idx : 0;
}

static const char *lean_freestanding_slice_base(void *slice) {
    lean_string_object *str = (lean_string_object *)lean_ctor_get(slice, 0);
    void *start = lean_ctor_get(slice, 1);
    size_t start_idx = lean_freestanding_is_scalar(start) ? lean_unbox(start) : 0;
    return str->m_data + start_idx;
}

uint64_t lean_slice_hash(void *s) {
    return lean_freestanding_hash_bytes(
        (const uint8_t *)lean_freestanding_slice_base(s),
        lean_freestanding_slice_size(s));
}

uint8_t lean_slice_dec_lt(void *s1, void *s2) {
    size_t sz1 = lean_freestanding_slice_size(s1);
    size_t sz2 = lean_freestanding_slice_size(s2);
    const uint8_t *p1 = (const uint8_t *)lean_freestanding_slice_base(s1);
    const uint8_t *p2 = (const uint8_t *)lean_freestanding_slice_base(s2);
    size_t n = sz1 < sz2 ? sz1 : sz2;
    for (size_t i = 0; i < n; ++i) {
        if (p1[i] != p2[i]) return p1[i] < p2[i];
    }
    return sz1 < sz2;
}

void *lean_string_of_usize(size_t n) {
    char buf[32];
    size_t pos = sizeof(buf);
    buf[--pos] = '\0';
    do {
        buf[--pos] = (char)('0' + (n % 10));
        n /= 10;
    } while (n != 0);
    return lean_mk_ascii_string_unchecked(buf + pos);
}

uint8_t lean_string_memcmp(void *s1, void *s2, void *lstart, void *rstart, void *len) {
    if (!lean_freestanding_is_scalar(lstart) ||
        !lean_freestanding_is_scalar(rstart) ||
        !lean_freestanding_is_scalar(len)) {
        return 0;
    }
    lean_string_object *a = (lean_string_object *)s1;
    lean_string_object *b = (lean_string_object *)s2;
    size_t l = lean_unbox(lstart);
    size_t r = lean_unbox(rstart);
    size_t n = lean_unbox(len);
    size_t asz = a->m_size == 0 ? 0 : a->m_size - 1;
    size_t bsz = b->m_size == 0 ? 0 : b->m_size - 1;
    if (l > asz || r > bsz || n > asz - l || n > bsz - r) return 0;
    for (size_t i = 0; i < n; ++i) {
        if (a->m_data[l + i] != b->m_data[r + i]) return 0;
    }
    return 1;
}

static uint32_t lean_freestanding_char_default_value(void) {
    return 'A';
}

static uint8_t lean_freestanding_string_utf8_get_core(const char *str, size_t size, size_t i, uint32_t *result) {
    unsigned c = (unsigned char)str[i];
    if ((c & 0x80) == 0) {
        *result = c;
        return 1;
    }
    if ((c & 0xe0) == 0xc0 && i + 1 < size) {
        unsigned c1 = (unsigned char)str[i + 1];
        uint32_t r = ((c & 0x1f) << 6) | (c1 & 0x3f);
        if (r >= 0x80) {
            *result = r;
            return 1;
        }
    }
    if ((c & 0xf0) == 0xe0 && i + 2 < size) {
        unsigned c1 = (unsigned char)str[i + 1];
        unsigned c2 = (unsigned char)str[i + 2];
        uint32_t r = ((c & 0x0f) << 12) | ((c1 & 0x3f) << 6) | (c2 & 0x3f);
        if (r >= 0x800 && (r < 0xD800 || r > 0xDFFF)) {
            *result = r;
            return 1;
        }
    }
    if ((c & 0xf8) == 0xf0 && i + 3 < size) {
        unsigned c1 = (unsigned char)str[i + 1];
        unsigned c2 = (unsigned char)str[i + 2];
        unsigned c3 = (unsigned char)str[i + 3];
        uint32_t r = ((c & 0x07) << 18) | ((c1 & 0x3f) << 12) |
                     ((c2 & 0x3f) << 6) | (c3 & 0x3f);
        if (r >= 0x10000 && r <= 0x10FFFF) {
            *result = r;
            return 1;
        }
    }
    return 0;
}

uint32_t lean_string_utf8_get_fast_cold(const char *str, size_t i, size_t size, unsigned char c) {
    (void)c;
    uint32_t result;
    if (i < size && lean_freestanding_string_utf8_get_core(str, size, i, &result)) return result;
    return lean_freestanding_char_default_value();
}

uint32_t lean_string_utf8_get(void *s, void *i0) {
    if (!lean_freestanding_is_scalar(i0)) return lean_freestanding_char_default_value();
    lean_string_object *str = (lean_string_object *)s;
    size_t i = lean_unbox(i0);
    size_t size = str->m_size == 0 ? 0 : str->m_size - 1;
    if (i >= size) return lean_freestanding_char_default_value();
    uint32_t result;
    if (lean_freestanding_string_utf8_get_core(str->m_data, size, i, &result)) return result;
    return lean_freestanding_char_default_value();
}

void *lean_string_utf8_get_opt(void *s, void *i0) {
    if (!lean_freestanding_is_scalar(i0)) return lean_box(0);
    lean_string_object *str = (lean_string_object *)s;
    size_t i = lean_unbox(i0);
    size_t size = str->m_size == 0 ? 0 : str->m_size - 1;
    if (i >= size) return lean_box(0);
    uint32_t result;
    if (!lean_freestanding_string_utf8_get_core(str->m_data, size, i, &result)) {
        return lean_box(0);
    }
    void *r = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(r, 0, lean_box_uint32(result));
    return r;
}

static uint32_t lean_freestanding_string_utf8_get_panic(void) {
    lean_panic_fn(lean_box_uint32(lean_freestanding_char_default_value()),
        lean_mk_ascii_string_unchecked("Error: invalid `String.Pos` at `String.get!`"));
    __builtin_unreachable();
}

uint32_t lean_string_utf8_get_bang(void *s, void *i0) {
    if (!lean_freestanding_is_scalar(i0)) return lean_freestanding_string_utf8_get_panic();
    lean_string_object *str = (lean_string_object *)s;
    size_t i = lean_unbox(i0);
    size_t size = str->m_size == 0 ? 0 : str->m_size - 1;
    if (i >= size) return lean_freestanding_string_utf8_get_panic();
    uint32_t result;
    if (lean_freestanding_string_utf8_get_core(str->m_data, size, i, &result)) return result;
    return lean_freestanding_string_utf8_get_panic();
}

static uint8_t lean_freestanding_is_utf8_first_byte(unsigned char c);

static unsigned lean_freestanding_utf8_char_size_at(const char *str, size_t size, size_t i) {
    if (i >= size) return 0;
    unsigned char c = (unsigned char)str[i];
    if ((c & 0x80) == 0) return 1;
    if ((c & 0xe0) == 0xc0 && i + 1 < size) return 2;
    if ((c & 0xf0) == 0xe0 && i + 2 < size) return 3;
    if ((c & 0xf8) == 0xf0 && i + 3 < size) return 4;
    return 1;
}

void *lean_string_utf8_set(void *s, void *i0, uint32_t c) {
    if (!lean_freestanding_is_scalar(i0)) return s;
    lean_string_object *str = (lean_string_object *)s;
    size_t i = lean_unbox(i0);
    size_t size = str->m_size == 0 ? 0 : str->m_size - 1;
    if (i >= size) return s;
    if (!lean_freestanding_is_utf8_first_byte((unsigned char)str->m_data[i])) return s;

    char encoded[4];
    unsigned new_len = lean_freestanding_utf8_encode(c, encoded);
    unsigned old_len = lean_freestanding_utf8_char_size_at(str->m_data, size, i);

    if (lean_is_exclusive(s) && old_len == new_len) {
        for (unsigned j = 0; j < new_len; ++j) str->m_data[i + j] = encoded[j];
        return s;
    }

    size_t new_size = size - old_len + new_len;
    lean_string_object *dst = lean_freestanding_alloc_string(new_size + 1, new_size + 1,
                                                             str->m_length);
    size_t out = 0;
    for (size_t j = 0; j < i; ++j) dst->m_data[out++] = str->m_data[j];
    for (unsigned j = 0; j < new_len; ++j) dst->m_data[out++] = encoded[j];
    for (size_t j = i + old_len; j < size; ++j) dst->m_data[out++] = str->m_data[j];
    dst->m_data[out] = '\0';
    if (lean_is_exclusive(s)) lean_del_object(s); else lean_dec_ref(s);
    return dst;
}

void *lean_string_utf8_next(void *s, void *i0) {
    if (!lean_freestanding_is_scalar(i0)) return lean_nat_add(i0, lean_box(1));
    lean_string_object *str = (lean_string_object *)s;
    size_t i = lean_unbox(i0);
    size_t size = str->m_size == 0 ? 0 : str->m_size - 1;
    if (i >= size) return lean_usize_to_nat(i + 1);
    unsigned c = (unsigned char)str->m_data[i];
    if ((c & 0x80) == 0) return lean_box(i + 1);
    if ((c & 0xe0) == 0xc0) return lean_box(i + 2);
    if ((c & 0xf0) == 0xe0) return lean_box(i + 3);
    if ((c & 0xf8) == 0xf0) return lean_box(i + 4);
    return lean_box(i + 1);
}

void *lean_string_utf8_next_fast_cold(size_t i, unsigned char c) {
    if ((c & 0xe0) == 0xc0) return lean_box(i + 2);
    if ((c & 0xf0) == 0xe0) return lean_box(i + 3);
    if ((c & 0xf8) == 0xf0) return lean_box(i + 4);
    return lean_box(i + 1);
}

static uint8_t lean_freestanding_is_utf8_first_byte(unsigned char c) {
    return (c & 0x80) == 0 || (c & 0xe0) == 0xc0 ||
           (c & 0xf0) == 0xe0 || (c & 0xf8) == 0xf0;
}

void *lean_string_utf8_prev(void *s, void *i0) {
    if (!lean_freestanding_is_scalar(i0)) return lean_nat_sub(i0, lean_box(1));
    lean_string_object *str = (lean_string_object *)s;
    size_t i = lean_unbox(i0);
    size_t size = str->m_size == 0 ? 0 : str->m_size - 1;
    if (i == 0) return lean_box(0);
    if (i > size) return lean_box(i - 1);
    i--;
    while (i > 0 && !lean_freestanding_is_utf8_first_byte((unsigned char)str->m_data[i])) {
        i--;
    }
    return lean_box(i);
}

uint8_t lean_string_is_valid_pos(void *s, void *i0) {
    if (!lean_freestanding_is_scalar(i0)) return 0;
    lean_string_object *str = (lean_string_object *)s;
    size_t i = lean_unbox(i0);
    size_t size = str->m_size == 0 ? 0 : str->m_size - 1;
    if (i > size) return 0;
    if (i == size) return 1;
    return lean_freestanding_is_utf8_first_byte((unsigned char)str->m_data[i]);
}

void *lean_string_utf8_extract(void *s, void *b0, void *e0) {
    if (!lean_freestanding_is_scalar(b0) || !lean_freestanding_is_scalar(e0)) {
        lean_inc(s);
        return s;
    }

    lean_string_object *str = (lean_string_object *)s;
    size_t b = lean_unbox(b0);
    size_t e = lean_unbox(e0);
    size_t size = str->m_size == 0 ? 0 : str->m_size - 1;
    if (b >= e || b >= size) return lean_mk_string_unchecked("", 0, 0);
    if (!lean_freestanding_is_utf8_first_byte((unsigned char)str->m_data[b])) {
        return lean_mk_string_unchecked("", 0, 0);
    }
    if (e > size) e = size;
    if (e < size && !lean_freestanding_is_utf8_first_byte((unsigned char)str->m_data[e])) {
        e = size;
    }
    return lean_mk_string_from_bytes_unchecked(str->m_data + b, e - b);
}

/* ===========================================================================
   Arrays
   ===========================================================================
   `Array α` is a heap-allocated growable buffer of `lean_object *` slots.
   Mutating operations follow Lean's standard copy-on-write discipline:
   modify in place only when the array is exclusive, otherwise copy first.
*/

static lean_array_object *lean_freestanding_alloc_array(size_t size, size_t capacity) {
    lean_array_object *o = (lean_array_object *)lean_alloc_object(sizeof(lean_array_object) + sizeof(void *) * capacity);
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
    size_t cap = 0;
    if (lean_freestanding_is_scalar(capacity_box)) {
        cap = lean_unbox(capacity_box);
    }
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

void *lean_array_get_panic(void *def_val) {
    return lean_panic_fn(def_val, lean_mk_ascii_string_unchecked("Error: index out of bounds"));
}

void *lean_array_set_panic(void *a, void *v) {
    lean_dec(v);
    return lean_panic_fn(a, lean_mk_ascii_string_unchecked("Error: index out of bounds"));
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
    if (src->m_capacity > (LEAN_FREESTANDING_HEAP_BYTES / sizeof(void *))) {
        lean_freestanding_panic("bad_array_cap", src->m_capacity,
            LEAN_FREESTANDING_RETURN_ADDRESS(0));
    }
    size_t new_cap = src->m_capacity;
    if (expand) new_cap = (new_cap + 1) * 2;
    if (new_cap < src->m_size) new_cap = src->m_size;
    lean_array_object *dst = lean_freestanding_alloc_array(src->m_size, new_cap);
    if (lean_is_exclusive(a)) {
        for (size_t i = 0; i < src->m_size; ++i) dst->m_data[i] = src->m_data[i];
        lean_del_object(a);
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

void *lean_array_mk(void *xs) {
    size_t n = 0;
    for (void *it = xs; !lean_freestanding_is_scalar(it); ) {
        lean_object *o = (lean_object *)it;
        if (o->m_tag == 0) break;
        n++;
        it = ((lean_ctor_object *)o)->m_objs[1];
    }
    lean_array_object *dst = lean_freestanding_alloc_array(n, n);
    size_t i = 0;
    for (void *it = xs; i < n; ) {
        lean_ctor_object *cell = (lean_ctor_object *)it;
        lean_object *elem = cell->m_objs[0];
        lean_inc(elem);
        dst->m_data[i++] = elem;
        it = cell->m_objs[1];
    }
    return dst;
}

void *lean_array_to_list(void *a) {
    lean_array_object *arr = (lean_array_object *)a;
    void *r = lean_box(0);
    for (size_t i = arr->m_size; i > 0; --i) {
        lean_object *elem = arr->m_data[i - 1];
        lean_inc(elem);
        void *cell = lean_alloc_ctor(1, 2, 0);
        lean_ctor_set(cell, 0, elem);
        lean_ctor_set(cell, 1, r);
        r = cell;
    }
    lean_dec(a);
    return r;
}

void *lean_array_push(void *a, void *v) {
    if (a == 0 || lean_freestanding_is_scalar(a) ||
        ((lean_object *)a)->m_tag != LEAN_TAG_ARRAY) {
        uintptr_t tag = 0;
        if (a != 0 && !lean_freestanding_is_scalar(a)) {
            tag = ((lean_object *)a)->m_tag;
        }
        lean_freestanding_panic("bad_array_push_obj", (uint64_t)(uintptr_t)a,
            (uint64_t)tag);
    }
    lean_array_object *src = (lean_array_object *)a;
    if (src->m_capacity > (LEAN_FREESTANDING_HEAP_BYTES / sizeof(void *))) {
        lean_freestanding_panic("bad_array_push", src->m_capacity,
            LEAN_FREESTANDING_RETURN_ADDRESS(0));
    }
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
    if (((lean_object *)r)->m_tag != LEAN_TAG_ARRAY) {
        lean_freestanding_panic("bad_array_push_ret", (uint64_t)(uintptr_t)r,
            (uint64_t)((lean_object *)r)->m_tag);
    }
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
    lean_sarray_object *o = (lean_sarray_object *)lean_alloc_object(sizeof(lean_sarray_object) + elem_size * capacity);
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
        lean_del_object(a);
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

uint8_t lean_sarray_eq_cold(void *a1, void *a2) {
    lean_sarray_object *x = (lean_sarray_object *)a1;
    lean_sarray_object *y = (lean_sarray_object *)a2;
    unsigned elem_size = lean_freestanding_sarray_elem_size(a1);
    size_t byte_size = elem_size * x->m_size;
    for (size_t i = 0; i < byte_size; ++i) {
        if (x->m_data[i] != y->m_data[i]) return 0;
    }
    return 1;
}

uint8_t lean_sarray_dec_eq(void *a1, void *a2) {
    if (a1 == a2) return 1;
    lean_sarray_object *x = (lean_sarray_object *)a1;
    lean_sarray_object *y = (lean_sarray_object *)a2;
    unsigned elem_size = lean_freestanding_sarray_elem_size(a1);
    if (elem_size != lean_freestanding_sarray_elem_size(a2)) return 0;
    if (x->m_size != y->m_size) return 0;
    return lean_sarray_eq_cold(a1, a2);
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
   Lean's host runtime keeps `Nat`/`Int` values as either tagged-scalar small
   values or heap-allocated GMP integers. Freestanding does not ship GMP. This
   runtime implements the scalar path plus a deliberately small fake-MPZ subset
   for the stdlib's 64-bit boundary constants; arithmetic outside that bounded
   subset still panics at the point full GMP semantics would be required. */

void *lean_unsigned_to_nat(uint32_t n) {
    if ((uint64_t)n > LEAN_FREESTANDING_MAX_SMALL_NAT) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (unsigned_to_nat exceeds small-Nat cap)");
    }
    return lean_box((size_t)n);
}

void *lean_uint64_to_nat(uint64_t n) {
    return lean_freestanding_nat_from_u64(n);
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
    return lean_freestanding_nat_from_u64((uint64_t)n);
}

uint64_t lean_uint64_of_nat(void *n) {
    return lean_freestanding_nat_mod64(n, "lean-freestanding: UInt64 conversion requires Nat");
}

uint32_t lean_uint32_of_nat(void *n) {
    return (uint32_t)lean_uint64_of_nat(n);
}

uint16_t lean_uint16_of_nat(void *n) {
    return (uint16_t)lean_uint64_of_nat(n);
}

uint8_t lean_uint8_of_nat(void *n) {
    return (uint8_t)lean_uint64_of_nat(n);
}

size_t lean_usize_of_nat(void *n) {
    uint64_t v = lean_freestanding_nat_to_u64(n, "lean-freestanding: Nat overflow (usize_of_nat requires GMP-sized Nat)");
    if (v > (uint64_t)SIZE_MAX) lean_freestanding_nat_panic("lean-freestanding: Nat overflow (usize_of_nat)");
    return (size_t)v;
}

uint8_t lean_uint8_of_big_nat(void *a) {
    return (uint8_t)lean_freestanding_nat_mod64(a, "lean-freestanding: UInt8 conversion requires Nat");
}

uint16_t lean_uint16_of_big_nat(void *a) {
    return (uint16_t)lean_freestanding_nat_mod64(a, "lean-freestanding: UInt16 conversion requires Nat");
}

uint32_t lean_uint32_of_big_nat(void *a) {
    return (uint32_t)lean_freestanding_nat_mod64(a, "lean-freestanding: UInt32 conversion requires Nat");
}

uint64_t lean_uint64_of_big_nat(void *a) {
    return lean_freestanding_nat_mod64(a, "lean-freestanding: UInt64 conversion requires Nat");
}

size_t lean_usize_of_big_nat(void *a) {
    return (size_t)lean_freestanding_nat_to_u64(a, "lean-freestanding: USize conversion requires target-sized Nat");
}

void *lean_nat_add(void *a, void *b) {
    uint64_t av = lean_freestanding_nat_to_u64(a, "lean-freestanding: Nat.add requires GMP-sized Nat");
    uint64_t bv = lean_freestanding_nat_to_u64(b, "lean-freestanding: Nat.add requires GMP-sized Nat");
    if (av > UINT64_MAX - bv) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (add result requires GMP-sized Nat)");
    }
    return lean_freestanding_nat_from_u64(av + bv);
}

void *lean_nat_sub(void *a, void *b) {
    uint64_t av = lean_freestanding_nat_to_u64(a, "lean-freestanding: Nat.sub requires GMP-sized Nat");
    uint64_t bv = lean_freestanding_nat_to_u64(b, "lean-freestanding: Nat.sub requires GMP-sized Nat");
    /* Lean's `Nat` saturates: m - n with m < n yields 0. */
    return lean_freestanding_nat_from_u64(av < bv ? 0 : av - bv);
}

void *lean_nat_mul(void *a, void *b) {
    uint64_t av = lean_freestanding_nat_to_u64(a, "lean-freestanding: Nat.mul requires GMP-sized Nat");
    uint64_t bv = lean_freestanding_nat_to_u64(b, "lean-freestanding: Nat.mul requires GMP-sized Nat");
    if (av != 0 && bv > UINT64_MAX / av) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (mul result requires GMP-sized Nat)");
    }
    return lean_freestanding_nat_from_u64(av * bv);
}

void *lean_nat_div(void *a, void *b) {
    uint64_t av = lean_freestanding_nat_to_u64(a, "lean-freestanding: Nat.div requires GMP-sized Nat");
    uint64_t bv = lean_freestanding_nat_to_u64(b, "lean-freestanding: Nat.div requires GMP-sized Nat");
    /* Lean's `Nat` defines `n / 0 = 0`. */
    return lean_freestanding_nat_from_u64(bv == 0 ? 0 : av / bv);
}

void *lean_nat_mod(void *a, void *b) {
    uint64_t av = lean_freestanding_nat_to_u64(a, "lean-freestanding: Nat.mod requires GMP-sized Nat");
    uint64_t bv = lean_freestanding_nat_to_u64(b, "lean-freestanding: Nat.mod requires GMP-sized Nat");
    return lean_freestanding_nat_from_u64(bv == 0 ? av : av % bv);
}

void *lean_nat_shiftr(void *a, void *b) {
    uint64_t ah, al;
    lean_freestanding_nat_parts(a, &ah, &al, "lean-freestanding: Nat.shiftRight requires GMP-sized Nat");
    uint64_t bv = lean_freestanding_nat_to_u64(b, "lean-freestanding: Nat.shiftRight requires GMP-sized Nat");
    if (bv >= 128) return lean_box(0);
    if (bv >= 64) return lean_freestanding_nat_from_u64(ah >> (bv - 64));
    if (bv == 0) return lean_freestanding_nat_from_u128_parts(ah, al);
    uint64_t hi = ah >> bv;
    uint64_t lo = (al >> bv) | (ah << (64 - bv));
    return lean_freestanding_nat_from_u128_parts(hi, lo);
}

uint8_t lean_nat_dec_lt(void *a, void *b) {
    return lean_freestanding_nat_cmp(a, b, "lean-freestanding: Nat.lt requires GMP-sized Nat") < 0;
}

uint8_t lean_nat_dec_le(void *a, void *b) {
    return lean_freestanding_nat_cmp(a, b, "lean-freestanding: Nat.le requires GMP-sized Nat") <= 0;
}

uint8_t lean_nat_dec_eq(void *a, void *b) {
    return lean_freestanding_nat_cmp(a, b, "lean-freestanding: Nat.eq requires GMP-sized Nat") == 0;
}

void *lean_nat_shiftl(void *a, void *b) {
    uint64_t ah, al;
    lean_freestanding_nat_parts(a, &ah, &al, "lean-freestanding: Nat.shiftLeft requires GMP-sized Nat");
    uint64_t bv = lean_freestanding_nat_to_u64(b, "lean-freestanding: Nat.shiftLeft requires GMP-sized Nat");
    if (ah == 0 && al == 0) return lean_box(0);
    if (bv >= 128) {
        lean_freestanding_nat_panic("lean-freestanding: Nat overflow (shiftl result requires GMP-sized Nat)");
    }
    if (bv == 0) return lean_freestanding_nat_from_u128_parts(ah, al);
    uint64_t hi, lo;
    if (bv >= 64) {
        if (ah != 0) lean_freestanding_nat_panic("lean-freestanding: Nat overflow (shiftl result requires GMP-sized Nat)");
        hi = al << (bv - 64);
        lo = 0;
    } else {
        hi = (ah << bv) | (al >> (64 - bv));
        lo = al << bv;
    }
    return lean_freestanding_nat_from_u128_parts(hi, lo);
}

void *lean_nat_pow(void *a, void *b) {
    uint64_t base = lean_freestanding_nat_to_u64(a, "lean-freestanding: Nat.pow requires GMP-sized Nat");
    uint64_t exp = lean_freestanding_nat_to_u64(b, "lean-freestanding: Nat.pow requires GMP-sized Nat");
    uint64_t hi = 0;
    uint64_t lo = 1;
    for (uint64_t i = 0; i < exp; ++i) {
        if (hi != 0) {
            if (base == 0) {
                hi = 0;
                lo = 0;
                continue;
            }
            if (base == 1) continue;
            lean_freestanding_nat_panic("lean-freestanding: Nat.pow requires GMP-sized Nat");
        }
        lean_freestanding_mul_u64_to_u128_limited(lo, base, &hi, &lo);
    }
    return lean_freestanding_nat_from_u128_parts(hi, lo);
}

void *lean_nat_gcd(void *a, void *b) {
    uint64_t x = lean_freestanding_nat_to_u64(a, "lean-freestanding: Nat.gcd requires GMP-sized Nat");
    uint64_t y = lean_freestanding_nat_to_u64(b, "lean-freestanding: Nat.gcd requires GMP-sized Nat");
    while (y != 0) {
        uint64_t r = x % y;
        x = y;
        y = r;
    }
    return lean_freestanding_nat_from_u64(x);
}

void *lean_big_usize_to_nat(size_t n) {
    return lean_freestanding_nat_from_u64((uint64_t)n);
}

void *lean_big_uint64_to_nat(uint64_t n) {
    return lean_freestanding_nat_from_u64(n);
}

void *lean_big_int_to_nat(void *a) {
    if (lean_freestanding_is_scalar(a)) return a;
    if (lean_freestanding_is_big_nat64(a) || lean_freestanding_is_big_nat128(a)) return a;
    if (lean_freestanding_is_fake_mpz64(a) && !lean_freestanding_fake_mpz64_is_negative(a)) return a;
    lean_freestanding_nat_panic("lean-freestanding: Nat conversion on negative or unsupported big-Int");
}

void *lean_nat_overflow_mul(size_t a, size_t b) {
    if (a != 0 && b > SIZE_MAX / a) {
        lean_freestanding_nat_panic("lean-freestanding: Nat multiplication requires GMP-sized Nat");
    }
    return lean_freestanding_nat_from_u64((uint64_t)(a * b));
}

void *lean_nat_big_succ(void *a) {
    uint64_t av = lean_freestanding_nat_to_u64(a, "lean-freestanding: Nat.succ requires GMP-sized Nat");
    if (av == UINT64_MAX) lean_freestanding_nat_panic("lean-freestanding: Nat.succ requires GMP-sized Nat");
    return lean_freestanding_nat_from_u64(av + 1);
}

void *lean_nat_big_add(void *a, void *b) {
    return lean_nat_add(a, b);
}

void *lean_nat_big_sub(void *a, void *b) {
    return lean_nat_sub(a, b);
}

void *lean_nat_big_mul(void *a, void *b) {
    return lean_nat_mul(a, b);
}

void *lean_nat_big_div(void *a, void *b) {
    return lean_nat_div(a, b);
}

void *lean_nat_big_div_exact(void *a, void *b) {
    return lean_nat_div(a, b);
}

void *lean_nat_big_mod(void *a, void *b) {
    return lean_nat_mod(a, b);
}

uint8_t lean_nat_big_eq(void *a, void *b) {
    return lean_nat_dec_eq(a, b);
}

uint8_t lean_nat_big_le(void *a, void *b) {
    return lean_nat_dec_le(a, b);
}

uint8_t lean_nat_big_lt(void *a, void *b) {
    return lean_nat_dec_lt(a, b);
}

void *lean_nat_big_land(void *a, void *b) {
    uint64_t av = lean_freestanding_nat_to_u64(a, "lean-freestanding: Nat.land requires GMP-sized Nat");
    uint64_t bv = lean_freestanding_nat_to_u64(b, "lean-freestanding: Nat.land requires GMP-sized Nat");
    return lean_freestanding_nat_from_u64(av & bv);
}

void *lean_nat_big_lor(void *a, void *b) {
    uint64_t av = lean_freestanding_nat_to_u64(a, "lean-freestanding: Nat.lor requires GMP-sized Nat");
    uint64_t bv = lean_freestanding_nat_to_u64(b, "lean-freestanding: Nat.lor requires GMP-sized Nat");
    return lean_freestanding_nat_from_u64(av | bv);
}

void *lean_nat_big_xor(void *a, void *b) {
    uint64_t av = lean_freestanding_nat_to_u64(a, "lean-freestanding: Nat.xor requires GMP-sized Nat");
    uint64_t bv = lean_freestanding_nat_to_u64(b, "lean-freestanding: Nat.xor requires GMP-sized Nat");
    return lean_freestanding_nat_from_u64(av ^ bv);
}

void *lean_nat_big_shiftr(void *a, void *b) {
    return lean_nat_shiftr(a, b);
}

void *lean_nat_log2(void *a) {
    uint64_t hi, lo;
    lean_freestanding_nat_parts(a, &hi, &lo, "lean-freestanding: Nat.log2 requires GMP-sized Nat");
    uint64_t v = hi != 0 ? hi : lo;
    if (v == 0) return lean_box(0);
    uint64_t r = 0;
    while (v >>= 1) ++r;
    if (hi != 0) r += 64;
    return lean_box((size_t)r);
}

/* Bounded `Int` support. Host Lean uses scalar encodings for small signed
   integers and GMP-backed MPZ objects for larger values. Freestanding keeps
   the scalar encoding and traps at the exact point an operation would need
   MPZ. */

#define LEAN_FREESTANDING_MAX_SMALL_INT \
    ((int64_t)(sizeof(void *) == 8 ? INT32_MAX : (INT32_MAX >> 1)))
#define LEAN_FREESTANDING_MIN_SMALL_INT \
    ((int64_t)(sizeof(void *) == 8 ? INT32_MIN : (-1073741824)))

static void lean_freestanding_int_panic(const char *what) {
    lean_freestanding_log(what, lean_strlen(what));
    lean_freestanding_panic("lean_int", 0, 0);
    __builtin_unreachable();
}

static int64_t lean_freestanding_scalar_to_int64(void *a) {
    if (sizeof(void *) == 8) {
        return (int64_t)(int32_t)(uint32_t)lean_unbox(a);
    } else {
        return (int64_t)(((int)(size_t)a) >> 1);
    }
}

static uint64_t lean_freestanding_i64_abs_u64(int64_t v) {
    if (v >= 0) return (uint64_t)v;
    return (uint64_t)(-(v + 1)) + 1;
}

static void lean_freestanding_int_parts(void *a, int *sign, uint64_t *hi, uint64_t *lo, const char *what) {
    if (lean_freestanding_is_scalar(a)) {
        int64_t v = lean_freestanding_scalar_to_int64(a);
        if (v == 0) {
            *sign = 0;
            *hi = 0;
            *lo = 0;
        } else if (v < 0) {
            *sign = -1;
            *hi = 0;
            *lo = lean_freestanding_i64_abs_u64(v);
        } else {
            *sign = 1;
            *hi = 0;
            *lo = (uint64_t)v;
        }
    } else if (lean_freestanding_is_fake_mpz64(a)) {
        uint64_t bits = lean_freestanding_big_nat64_value(a);
        if (lean_freestanding_fake_mpz64_is_negative(a)) {
            int64_t v = (int64_t)bits;
            if (v >= 0) lean_freestanding_int_panic(what);
            *sign = -1;
            *hi = 0;
            *lo = lean_freestanding_i64_abs_u64(v);
        } else {
            *sign = bits == 0 ? 0 : 1;
            *hi = 0;
            *lo = bits;
        }
    } else if (lean_freestanding_is_big_nat128(a)) {
        uint64_t *p = (uint64_t *)((char *)a + sizeof(lean_object));
        *sign = (p[0] == 0 && p[1] == 0) ? 0 : 1;
        *lo = p[0];
        *hi = p[1];
    } else {
        lean_freestanding_int_panic(what);
    }
}

static int lean_freestanding_int_cmp(void *a, void *b, const char *what) {
    int as, bs;
    uint64_t ah, al, bh, bl;
    lean_freestanding_int_parts(a, &as, &ah, &al, what);
    lean_freestanding_int_parts(b, &bs, &bh, &bl, what);
    if (as != bs) return as < bs ? -1 : 1;
    if (as == 0) return 0;
    int mag_cmp = 0;
    if (ah != bh) mag_cmp = ah < bh ? -1 : 1;
    else if (al != bl) mag_cmp = al < bl ? -1 : 1;
    return as > 0 ? mag_cmp : -mag_cmp;
}

static int lean_freestanding_int_mag_cmp(uint64_t ah, uint64_t al, uint64_t bh, uint64_t bl) {
    if (ah != bh) return ah < bh ? -1 : 1;
    if (al != bl) return al < bl ? -1 : 1;
    return 0;
}

static void lean_freestanding_int_mag_add(uint64_t ah, uint64_t al, uint64_t bh, uint64_t bl,
        uint64_t *rh, uint64_t *rl) {
    uint64_t lo = al + bl;
    uint64_t carry = lo < al ? 1u : 0u;
    uint64_t hi0 = ah + bh;
    if (hi0 < ah) {
        lean_freestanding_int_panic("lean-freestanding: Int.add result requires GMP-sized Int");
    }
    uint64_t hi = hi0 + carry;
    if (hi < hi0) {
        lean_freestanding_int_panic("lean-freestanding: Int.add result requires GMP-sized Int");
    }
    *rh = hi;
    *rl = lo;
}

static void lean_freestanding_int_mag_sub(uint64_t ah, uint64_t al, uint64_t bh, uint64_t bl,
        uint64_t *rh, uint64_t *rl) {
    uint64_t borrow = al < bl ? 1u : 0u;
    *rl = al - bl;
    *rh = ah - bh - borrow;
}

static void *lean_freestanding_int_from_parts(int sign, uint64_t hi, uint64_t lo, const char *what) {
    if (sign == 0 || (hi == 0 && lo == 0)) return lean_box(0);
    if (sign > 0) {
        if (hi == 0) return lean_freestanding_uint64_to_nonnegative_int(lo);
        if (hi == 1 && lo == 0) return lean_freestanding_big_nat128(hi, lo);
        lean_freestanding_int_panic(what);
    } else {
        uint64_t min_mag = (uint64_t)INT64_MAX + 1u;
        if (hi != 0 || lo > min_mag) lean_freestanding_int_panic(what);
        if (lo == min_mag) return lean_freestanding_int64_to_int(INT64_MIN);
        return lean_freestanding_int64_to_int(-(int64_t)lo);
    }
}

static void *lean_freestanding_int_addsub(void *a, void *b, int subtract, const char *what) {
    int as, bs;
    uint64_t ah, al, bh, bl, rh, rl;
    lean_freestanding_int_parts(a, &as, &ah, &al, what);
    lean_freestanding_int_parts(b, &bs, &bh, &bl, what);
    if (subtract) bs = -bs;
    if (as == 0) return lean_freestanding_int_from_parts(bs, bh, bl, what);
    if (bs == 0) return lean_freestanding_int_from_parts(as, ah, al, what);
    if (as == bs) {
        lean_freestanding_int_mag_add(ah, al, bh, bl, &rh, &rl);
        return lean_freestanding_int_from_parts(as, rh, rl, what);
    }
    int cmp = lean_freestanding_int_mag_cmp(ah, al, bh, bl);
    if (cmp == 0) return lean_box(0);
    if (cmp > 0) {
        lean_freestanding_int_mag_sub(ah, al, bh, bl, &rh, &rl);
        return lean_freestanding_int_from_parts(as, rh, rl, what);
    } else {
        lean_freestanding_int_mag_sub(bh, bl, ah, al, &rh, &rl);
        return lean_freestanding_int_from_parts(bs, rh, rl, what);
    }
}

static int64_t lean_freestanding_int_to_int64(void *a, const char *what) {
    int sign;
    uint64_t hi, lo;
    lean_freestanding_int_parts(a, &sign, &hi, &lo, what);
    if (sign == 0) return 0;
    if (hi != 0) lean_freestanding_int_panic(what);
    if (sign > 0) {
        if (lo > (uint64_t)INT64_MAX) lean_freestanding_int_panic(what);
        return (int64_t)lo;
    } else {
        uint64_t min_mag = (uint64_t)INT64_MAX + 1u;
        if (lo > min_mag) lean_freestanding_int_panic(what);
        if (lo == min_mag) return INT64_MIN;
        return -(int64_t)lo;
    }
}

static uint64_t lean_freestanding_int_mod64(void *a, const char *what) {
    int sign;
    uint64_t hi, lo;
    lean_freestanding_int_parts(a, &sign, &hi, &lo, what);
    (void)hi;
    if (sign < 0) return (uint64_t)(0 - lo);
    return lo;
}

static void *lean_freestanding_int64_to_int(int64_t n) {
    if (n < LEAN_FREESTANDING_MIN_SMALL_INT || n > LEAN_FREESTANDING_MAX_SMALL_INT) {
        return lean_freestanding_big_int64(n);
    }
    return lean_box((size_t)(uint32_t)(int32_t)n);
}

static void *lean_freestanding_uint64_to_nonnegative_int(uint64_t n) {
    if (n <= (uint64_t)INT64_MAX) return lean_freestanding_int64_to_int((int64_t)n);
    return lean_freestanding_big_nat64(n);
}

int8_t lean_int8_of_big_int(void *a) {
    return (int8_t)lean_freestanding_int_mod64(a, "lean-freestanding: Int8 conversion requires supported big-Int");
}

int16_t lean_int16_of_big_int(void *a) {
    return (int16_t)lean_freestanding_int_mod64(a, "lean-freestanding: Int16 conversion requires supported big-Int");
}

int32_t lean_int32_of_big_int(void *a) {
    return (int32_t)lean_freestanding_int_mod64(a, "lean-freestanding: Int32 conversion requires supported big-Int");
}

int64_t lean_int64_of_big_int(void *a) {
    return (int64_t)lean_freestanding_int_mod64(a, "lean-freestanding: Int64 conversion requires supported big-Int");
}

ptrdiff_t lean_isize_of_big_int(void *a) {
    uint64_t r = lean_freestanding_int_mod64(a, "lean-freestanding: ISize conversion requires supported big-Int");
    return sizeof(ptrdiff_t) == 8 ? (ptrdiff_t)(int64_t)r : (ptrdiff_t)(int32_t)r;
}

void *lean_cstr_to_int(const char *s) {
    uint8_t neg = 0;
    if (*s == '-') {
        neg = 1;
        ++s;
    }
    if (*s == '\0') {
        lean_freestanding_int_panic("lean-freestanding: cstr_to_int: empty literal");
    }
    uint64_t limit = neg ? ((uint64_t)INT64_MAX + 1u) : UINT64_MAX;
    uint64_t n = 0;
    while (*s) {
        char c = *s++;
        if (c < '0' || c > '9') {
            lean_freestanding_int_panic("lean-freestanding: cstr_to_int: non-digit");
        }
        uint64_t d = (uint64_t)(c - '0');
        if (n > (limit - d) / 10) {
            lean_freestanding_int_panic("lean-freestanding: cstr_to_int: requires GMP-sized Int");
        }
        n = n * 10 + d;
    }
    if (neg) {
        if (n == (uint64_t)INT64_MAX + 1u) return lean_freestanding_int64_to_int(INT64_MIN);
        return lean_freestanding_int64_to_int(-(int64_t)n);
    }
    return lean_freestanding_uint64_to_nonnegative_int(n);
}

void *lean_big_int_to_int(int n) {
    return lean_freestanding_int64_to_int((int64_t)n);
}

void *lean_big_size_t_to_int(size_t n) {
    return lean_freestanding_uint64_to_nonnegative_int((uint64_t)n);
}

void *lean_big_int64_to_int(int64_t n) {
    return lean_freestanding_int64_to_int(n);
}

void *lean_nat_to_int(void *a) {
    if (lean_freestanding_is_scalar(a)) {
        uint64_t n = lean_unbox(a);
        return lean_freestanding_uint64_to_nonnegative_int(n);
    }
    if (lean_freestanding_is_big_nat64(a) || lean_freestanding_is_big_nat128(a)) return a;
    lean_freestanding_int_panic("lean-freestanding: Nat to Int requires nonnegative Nat");
}

void *lean_int_neg_succ_of_nat(void *a) {
    uint64_t n = lean_freestanding_nat_to_u64(a, "lean-freestanding: Int.negSucc requires GMP-sized Nat");
    if (n >= (uint64_t)INT64_MAX + 1u) {
        lean_freestanding_int_panic("lean-freestanding: Int.negSucc requires GMP-sized Int");
    }
    if (n == (uint64_t)INT64_MAX) return lean_freestanding_int64_to_int(INT64_MIN);
    return lean_freestanding_int64_to_int(-((int64_t)n + 1));
}

void *lean_int_neg(void *a) {
    int sign;
    uint64_t hi, lo;
    lean_freestanding_int_parts(a, &sign, &hi, &lo, "lean-freestanding: Int.neg requires GMP-sized Int");
    return lean_freestanding_int_from_parts(-sign, hi, lo, "lean-freestanding: Int.neg result requires GMP-sized Int");
}

void *lean_int_add(void *a, void *b) {
    return lean_freestanding_int_addsub(a, b, 0, "lean-freestanding: Int.add requires GMP-sized Int");
}

void *lean_int_sub(void *a, void *b) {
    return lean_freestanding_int_addsub(a, b, 1, "lean-freestanding: Int.sub requires GMP-sized Int");
}

void *lean_int_mul(void *a, void *b) {
    int64_t av = lean_freestanding_int_to_int64(a, "lean-freestanding: Int.mul requires GMP-sized Int");
    int64_t bv = lean_freestanding_int_to_int64(b, "lean-freestanding: Int.mul requires GMP-sized Int");
    int64_t r;
    if (__builtin_mul_overflow(av, bv, &r)) {
        lean_freestanding_int_panic("lean-freestanding: Int.mul result requires GMP-sized Int");
    }
    return lean_freestanding_int64_to_int(r);
}

void *lean_int_div(void *a, void *b) {
    int64_t av = lean_freestanding_int_to_int64(a, "lean-freestanding: Int.div requires GMP-sized Int");
    int64_t bv = lean_freestanding_int_to_int64(b, "lean-freestanding: Int.div requires GMP-sized Int");
    if (av == INT64_MIN && bv == -1) return lean_freestanding_big_nat64((uint64_t)INT64_MAX + 1u);
    return bv == 0 ? lean_box(0) : lean_freestanding_int64_to_int(av / bv);
}

void *lean_int_div_exact(void *a, void *b) {
    return lean_int_div(a, b);
}

void *lean_int_mod(void *a, void *b) {
    int64_t av = lean_freestanding_int_to_int64(a, "lean-freestanding: Int.mod requires GMP-sized Int");
    int64_t bv = lean_freestanding_int_to_int64(b, "lean-freestanding: Int.mod requires GMP-sized Int");
    if (av == INT64_MIN && bv == -1) return lean_box(0);
    return bv == 0 ? a : lean_freestanding_int64_to_int(av % bv);
}

void *lean_int_ediv(void *a, void *b) {
    int64_t n = lean_freestanding_int_to_int64(a, "lean-freestanding: Int.ediv requires GMP-sized Int");
    int64_t d = lean_freestanding_int_to_int64(b, "lean-freestanding: Int.ediv requires GMP-sized Int");
    if (d == 0) return lean_box(0);
    if (n == INT64_MIN && d == -1) return lean_freestanding_big_nat64((uint64_t)INT64_MAX + 1u);
    int64_t q = n / d;
    int64_t r = n % d;
    if (r < 0) q = d > 0 ? q - 1 : q + 1;
    return lean_freestanding_int64_to_int(q);
}

void *lean_int_emod(void *a, void *b) {
    int64_t n = lean_freestanding_int_to_int64(a, "lean-freestanding: Int.emod requires GMP-sized Int");
    int64_t d = lean_freestanding_int_to_int64(b, "lean-freestanding: Int.emod requires GMP-sized Int");
    if (d == 0) return a;
    if (n == INT64_MIN && d == -1) return lean_box(0);
    int64_t r = n % d;
    if (r < 0) r = d > 0 ? r + d : r - d;
    return lean_freestanding_int64_to_int(r);
}

uint8_t lean_int_dec_eq(void *a, void *b) {
    return lean_freestanding_int_cmp(a, b, "lean-freestanding: Int.eq requires supported Int") == 0;
}

uint8_t lean_int_dec_nonneg(void *a) {
    int sign;
    uint64_t hi, lo;
    lean_freestanding_int_parts(a, &sign, &hi, &lo, "lean-freestanding: Int.nonneg requires supported Int");
    (void)hi;
    (void)lo;
    return sign >= 0;
}

uint8_t lean_int_dec_le(void *a, void *b) {
    return lean_freestanding_int_cmp(a, b, "lean-freestanding: Int.le requires supported Int") <= 0;
}

uint8_t lean_int_dec_lt(void *a, void *b) {
    return lean_freestanding_int_cmp(a, b, "lean-freestanding: Int.lt requires supported Int") < 0;
}

void *lean_nat_abs(void *a) {
    int sign;
    uint64_t hi, lo;
    lean_freestanding_int_parts(a, &sign, &hi, &lo, "lean-freestanding: Int.natAbs requires supported Int");
    if (hi != 0) return lean_freestanding_big_nat128(hi, lo);
    return lean_uint64_to_nat(lo);
}

void *lean_int_big_neg(void *a) { return lean_int_neg(a); }
void *lean_int_big_add(void *a, void *b) { return lean_int_add(a, b); }
void *lean_int_big_sub(void *a, void *b) { return lean_int_sub(a, b); }
void *lean_int_big_mul(void *a, void *b) { return lean_int_mul(a, b); }
void *lean_int_big_div(void *a, void *b) { return lean_int_div(a, b); }
void *lean_int_big_div_exact(void *a, void *b) { return lean_int_div(a, b); }
void *lean_int_big_mod(void *a, void *b) { return lean_int_mod(a, b); }
void *lean_int_big_ediv(void *a, void *b) { return lean_int_ediv(a, b); }
void *lean_int_big_emod(void *a, void *b) { return lean_int_emod(a, b); }
uint8_t lean_int_big_eq(void *a, void *b) { return lean_int_dec_eq(a, b); }
uint8_t lean_int_big_le(void *a, void *b) { return lean_int_dec_le(a, b); }
uint8_t lean_int_big_lt(void *a, void *b) { return lean_int_dec_lt(a, b); }
uint8_t lean_int_big_nonneg(void *a) { return lean_int_dec_nonneg(a); }

uint8_t lean_float_isnan(double a) { return a != a; }
uint8_t lean_float32_isnan(float a) { return a != a; }

static unsigned lean_freestanding_clz64(uint64_t x) {
    unsigned n = 0;
    while ((x & (1ULL << 63)) == 0) {
        ++n;
        x <<= 1;
    }
    return n;
}

double __floatundidf(uint64_t x) {
    union { uint64_t u; double d; } r;
    if (x == 0) {
        r.u = 0;
        return r.d;
    }
    unsigned e = 63 - lean_freestanding_clz64(x);
    uint64_t sig;
    if (e <= 52) {
        sig = x << (52 - e);
    } else {
        unsigned shift = e - 52;
        uint64_t extra = x & ((1ULL << shift) - 1);
        sig = x >> shift;
        uint64_t half = 1ULL << (shift - 1);
        if (extra > half || (extra == half && (sig & 1) != 0)) ++sig;
        if (sig == (1ULL << 53)) {
            ++e;
            sig >>= 1;
        }
    }
    r.u = ((uint64_t)(e + 1023) << 52) | (sig & ((1ULL << 52) - 1));
    return r.d;
}

float __floatundisf(uint64_t x) {
    union { uint32_t u; float f; } r;
    if (x == 0) {
        r.u = 0;
        return r.f;
    }
    unsigned e = 63 - lean_freestanding_clz64(x);
    uint64_t sig;
    if (e <= 23) {
        sig = x << (23 - e);
    } else {
        unsigned shift = e - 23;
        uint64_t extra = x & ((1ULL << shift) - 1);
        sig = x >> shift;
        uint64_t half = 1ULL << (shift - 1);
        if (extra > half || (extra == half && (sig & 1) != 0)) ++sig;
        if (sig == (1ULL << 24)) {
            ++e;
            sig >>= 1;
        }
    }
    r.u = ((uint32_t)(e + 127) << 23) | ((uint32_t)sig & ((1u << 23) - 1));
    return r.f;
}

uint8_t lean_system_platform_windows(void *unit) {
    (void)unit;
    return 0;
}

uint8_t lean_system_platform_osx(void *unit) {
    (void)unit;
    return 0;
}

uint8_t lean_system_platform_emscripten(void *unit) {
    (void)unit;
    return 0;
}

void *lean_system_platform_nbits(void *unit) {
    (void)unit;
    return lean_box(64);
}

void *lean_system_platform_target(void *unit) {
    (void)unit;
    return lean_mk_ascii_string_unchecked("");
}

void *lean_get_githash(void *unit) {
    (void)unit;
    return lean_mk_ascii_string_unchecked("");
}

uint8_t lean_internal_has_llvm_backend(void *unit) {
    (void)unit;
#ifdef LEAN_LLVM
    return 1;
#else
    return 0;
#endif
}

uint8_t lean_is_reserved_name(void *env, void *name) {
    (void)env; (void)name;
    return 0;
}

/* ===========================================================================
   Kernel object helpers used by generated Lean kernel code
   =========================================================================== */

static unsigned lean_freestanding_ctor_num_objs(void *o) {
    return ((lean_object *)o)->m_other;
}

uint64_t lean_expr_data(void *expr) {
    return lean_ctor_get_uint64(expr, lean_freestanding_ctor_num_objs(expr) * sizeof(void *));
}

static uint32_t lean_freestanding_expr_bvar_range_from_data(uint64_t data) {
    return (uint32_t)(data >> 44);
}

static uint32_t lean_freestanding_expr_bvar_range(void *e) {
    return lean_freestanding_expr_bvar_range_from_data(lean_expr_data(e));
}

__attribute__((weak)) uint64_t lean_expr_hash(void *e) {
    return (uint32_t)lean_expr_data(e);
}

__attribute__((weak)) uint8_t lean_expr_has_fvar(void *e) {
    return (uint8_t)((lean_expr_data(e) >> 40) & 1u);
}

__attribute__((weak)) uint8_t lean_expr_has_expr_mvar(void *e) {
    return (uint8_t)((lean_expr_data(e) >> 41) & 1u);
}

__attribute__((weak)) uint8_t lean_expr_has_level_mvar(void *e) {
    return (uint8_t)((lean_expr_data(e) >> 42) & 1u);
}

__attribute__((weak)) uint8_t lean_expr_has_level_param(void *e) {
    return (uint8_t)((lean_expr_data(e) >> 43) & 1u);
}

__attribute__((weak)) unsigned lean_expr_loose_bvar_range(void *e) {
    return lean_freestanding_expr_bvar_range(e);
}

uint64_t lean_level_mk_data(uint64_t h, void *depth, uint8_t hasMVar, uint8_t hasParam) {
    if (!lean_freestanding_is_scalar(depth)) {
        lean_freestanding_panic("universe level depth is too big", 0, 0);
        __builtin_unreachable();
    }
    size_t d = lean_unbox(depth);
    if (d > 16777215) {
        lean_freestanding_panic("universe level depth is too big", d, 0);
        __builtin_unreachable();
    }
    uint32_t h1 = (uint32_t)h;
    return ((uint64_t)h1) |
           (((uint64_t)hasMVar) << 32) |
           (((uint64_t)hasParam) << 33) |
           (((uint64_t)d) << 40);
}

uint64_t lean_expr_mk_data(uint64_t hash, void *bvarRange, uint32_t approxDepth,
                           uint8_t hasFVar, uint8_t hasExprMVar,
                           uint8_t hasLevelMVar, uint8_t hasLevelParam) {
    if (approxDepth > 255) approxDepth = 255;
    if (!lean_freestanding_is_scalar(bvarRange)) {
        lean_freestanding_panic("too many bound variables", 0, 0);
        __builtin_unreachable();
    }
    size_t range = lean_unbox(bvarRange);
    if (range > 1048575) {
        lean_freestanding_panic("too many bound variables", range, 0);
        __builtin_unreachable();
    }
    uint32_t h = (uint32_t)hash;
    return ((uint64_t)h) |
           (((uint64_t)approxDepth) << 32) |
           (((uint64_t)hasFVar) << 40) |
           (((uint64_t)hasExprMVar) << 41) |
           (((uint64_t)hasLevelMVar) << 42) |
           (((uint64_t)hasLevelParam) << 43) |
           (((uint64_t)range) << 44);
}

uint64_t lean_expr_mk_app_data(uint64_t fData, uint64_t aData) {
    uint32_t fd = (uint32_t)((fData >> 32) & 255u);
    uint32_t ad = (uint32_t)((aData >> 32) & 255u);
    uint32_t depth = (fd > ad ? fd : ad) + 1;
    if (depth > 255) depth = 255;
    uint32_t fr = lean_freestanding_expr_bvar_range_from_data(fData);
    uint32_t ar = lean_freestanding_expr_bvar_range_from_data(aData);
    uint32_t range = fr > ar ? fr : ar;
    uint32_t h = (uint32_t)lean_uint64_mix_hash(fData, aData);
    return ((fData | aData) & (((uint64_t)15) << 40)) |
           ((uint64_t)h) |
           (((uint64_t)depth) << 32) |
           (((uint64_t)range) << 44);
}

uint8_t lean_name_eq(void *n1, void *n2) {
    if (n1 == n2) return 1;
    if (lean_freestanding_is_scalar(n1) || lean_freestanding_is_scalar(n2)) return 0;
    for (;;) {
        if (((lean_object *)n1)->m_tag != ((lean_object *)n2)->m_tag) return 0;
        lean_ctor_object *a = (lean_ctor_object *)n1;
        lean_ctor_object *b = (lean_ctor_object *)n2;
        if (((lean_object *)n1)->m_tag == 1) {
            if (!lean_string_dec_eq(a->m_objs[1], b->m_objs[1])) return 0;
        } else {
            if (!lean_nat_dec_eq(a->m_objs[1], b->m_objs[1])) return 0;
        }
        n1 = a->m_objs[0];
        n2 = b->m_objs[0];
        if (n1 == n2) return 1;
        if (lean_freestanding_is_scalar(n1) || lean_freestanding_is_scalar(n2)) return 0;
    }
}

uint8_t lean_level_eq(void *l1, void *l2) {
    if (l1 == l2) return 1;
    if (lean_freestanding_is_scalar(l1) || lean_freestanding_is_scalar(l2)) return 0;
    lean_object *o1 = (lean_object *)l1;
    lean_object *o2 = (lean_object *)l2;
    if (o1->m_tag != o2->m_tag) return 0;
    lean_ctor_object *c1 = (lean_ctor_object *)l1;
    lean_ctor_object *c2 = (lean_ctor_object *)l2;
    switch (o1->m_tag) {
    case 1:
        return lean_level_eq(c1->m_objs[0], c2->m_objs[0]);
    case 2: case 3:
        return lean_level_eq(c1->m_objs[0], c2->m_objs[0]) &&
               lean_level_eq(c1->m_objs[1], c2->m_objs[1]);
    case 4: case 5:
        return lean_name_eq(c1->m_objs[0], c2->m_objs[0]);
    default:
        return 0;
    }
}

uint8_t lean_level_eqv(void *l1, void *l2) {
    return lean_level_eq(l1, l2);
}

extern void *lean_expr_mk_bvar(void *idx);
extern void *lean_expr_mk_fvar(void *fvarId);
extern void *lean_expr_mk_mvar(void *mvarId);
extern void *lean_expr_mk_sort(void *u);
extern void *lean_expr_mk_const(void *c, void *lvls);
extern void *lean_expr_mk_app(void *f, void *a);
extern void *lean_expr_mk_lambda(void *n, void *d, void *b, uint8_t bi);
extern void *lean_expr_mk_forall(void *n, void *d, void *b, uint8_t bi);
extern void *lean_expr_mk_let(void *n, void *t, void *v, void *b, uint8_t nondep);
extern void *lean_expr_mk_lit(void *l);
extern void *lean_expr_mk_mdata(void *m, void *e);
extern void *lean_expr_mk_proj(void *structName, void *idx, void *structExpr);

static void *lean_freestanding_expr_field(void *e, unsigned i) {
    return ((lean_ctor_object *)e)->m_objs[i];
}

static void *lean_freestanding_expr_field_inc(void *e, unsigned i) {
    void *r = lean_freestanding_expr_field(e, i);
    lean_inc(r);
    return r;
}

static uint8_t lean_freestanding_expr_uint8(void *e, unsigned offset) {
    return lean_ctor_get_uint8(e, lean_freestanding_ctor_num_objs(e) * sizeof(void *) + offset);
}

static uint8_t lean_freestanding_expr_has_loose_bvar_at(void *e, size_t i, size_t offset) {
    size_t n_i = i + offset;
    if (n_i < i || n_i >= lean_freestanding_expr_bvar_range(e)) return 0;
    unsigned tag = ((lean_object *)e)->m_tag;
    switch (tag) {
    case 0:
        return lean_freestanding_is_scalar(lean_freestanding_expr_field(e, 0)) &&
               lean_unbox(lean_freestanding_expr_field(e, 0)) == n_i;
    case 5:
        return lean_freestanding_expr_has_loose_bvar_at(lean_freestanding_expr_field(e, 0), i, offset) ||
               lean_freestanding_expr_has_loose_bvar_at(lean_freestanding_expr_field(e, 1), i, offset);
    case 6: case 7:
        return lean_freestanding_expr_has_loose_bvar_at(lean_freestanding_expr_field(e, 1), i, offset) ||
               lean_freestanding_expr_has_loose_bvar_at(lean_freestanding_expr_field(e, 2), i, offset + 1);
    case 8:
        return lean_freestanding_expr_has_loose_bvar_at(lean_freestanding_expr_field(e, 1), i, offset) ||
               lean_freestanding_expr_has_loose_bvar_at(lean_freestanding_expr_field(e, 2), i, offset) ||
               lean_freestanding_expr_has_loose_bvar_at(lean_freestanding_expr_field(e, 3), i, offset + 1);
    case 10:
        return lean_freestanding_expr_has_loose_bvar_at(lean_freestanding_expr_field(e, 1), i, offset);
    case 11:
        return lean_freestanding_expr_has_loose_bvar_at(lean_freestanding_expr_field(e, 2), i, offset);
    default:
        return 0;
    }
}

uint8_t lean_expr_has_loose_bvar(void *e, void *i) {
    if (!lean_freestanding_is_scalar(i)) return 0;
    return lean_freestanding_expr_has_loose_bvar_at(e, lean_unbox(i), 0);
}

static void *lean_freestanding_expr_lift_at(void *e, size_t s, size_t d, size_t offset);
static void *lean_freestanding_expr_lower_at(void *e, size_t s, size_t d, size_t offset);
static void *lean_freestanding_expr_instantiate1_at(void *e, void *subst, size_t offset);
static void *lean_freestanding_expr_instantiate_at(void *e, size_t n, lean_object **subst, uint8_t rev, size_t offset);
static void *lean_freestanding_expr_abstract_at(void *e, size_t n, void *subst, size_t offset);
static void *lean_freestanding_replace_expr_at(void *f, void *e);

static void *lean_freestanding_rebuild_same_shape(void *e,
                                                  void *a0, void *a1, void *a2, void *a3) {
    switch (((lean_object *)e)->m_tag) {
    case 0: return lean_expr_mk_bvar(a0);
    case 1: return lean_expr_mk_fvar(a0);
    case 2: return lean_expr_mk_mvar(a0);
    case 3: return lean_expr_mk_sort(a0);
    case 4: return lean_expr_mk_const(a0, a1);
    case 5: return lean_expr_mk_app(a0, a1);
    case 6: return lean_expr_mk_lambda(a0, a1, a2, lean_freestanding_expr_uint8(e, 0));
    case 7: return lean_expr_mk_forall(a0, a1, a2, lean_freestanding_expr_uint8(e, 0));
    case 8: return lean_expr_mk_let(a0, a1, a2, a3, lean_freestanding_expr_uint8(e, 0));
    case 9: return lean_expr_mk_lit(a0);
    case 10: return lean_expr_mk_mdata(a0, a1);
    case 11: return lean_expr_mk_proj(a0, a1, a2);
    default:
        lean_freestanding_panic("unknown Expr tag", ((lean_object *)e)->m_tag, 0);
        __builtin_unreachable();
    }
}

static void *lean_freestanding_expr_lift_at(void *e, size_t s, size_t d, size_t offset) {
    if (d == 0) {
        lean_inc(e);
        return e;
    }
    size_t s1 = s + offset;
    if (s1 < s || s1 >= lean_freestanding_expr_bvar_range(e)) {
        lean_inc(e);
        return e;
    }
    unsigned tag = ((lean_object *)e)->m_tag;
    if (tag == 0) {
        void *idx_obj = lean_freestanding_expr_field(e, 0);
        if (lean_freestanding_is_scalar(idx_obj)) {
            size_t idx = lean_unbox(idx_obj);
            if (idx >= s1) return lean_expr_mk_bvar(lean_uint64_to_nat(idx + d));
        }
        lean_inc(e);
        return e;
    }
    switch (tag) {
    case 5: {
        void *f = lean_freestanding_expr_lift_at(lean_freestanding_expr_field(e, 0), s, d, offset);
        void *a = lean_freestanding_expr_lift_at(lean_freestanding_expr_field(e, 1), s, d, offset);
        return lean_expr_mk_app(f, a);
    }
    case 6: case 7: {
        void *n = lean_freestanding_expr_field_inc(e, 0);
        void *t = lean_freestanding_expr_lift_at(lean_freestanding_expr_field(e, 1), s, d, offset);
        void *b = lean_freestanding_expr_lift_at(lean_freestanding_expr_field(e, 2), s, d, offset + 1);
        return tag == 6 ? lean_expr_mk_lambda(n, t, b, lean_freestanding_expr_uint8(e, 0))
                        : lean_expr_mk_forall(n, t, b, lean_freestanding_expr_uint8(e, 0));
    }
    case 8: {
        void *n = lean_freestanding_expr_field_inc(e, 0);
        void *t = lean_freestanding_expr_lift_at(lean_freestanding_expr_field(e, 1), s, d, offset);
        void *v = lean_freestanding_expr_lift_at(lean_freestanding_expr_field(e, 2), s, d, offset);
        void *b = lean_freestanding_expr_lift_at(lean_freestanding_expr_field(e, 3), s, d, offset + 1);
        return lean_expr_mk_let(n, t, v, b, lean_freestanding_expr_uint8(e, 0));
    }
    case 10: {
        void *m = lean_freestanding_expr_field_inc(e, 0);
        void *x = lean_freestanding_expr_lift_at(lean_freestanding_expr_field(e, 1), s, d, offset);
        return lean_expr_mk_mdata(m, x);
    }
    case 11: {
        void *n = lean_freestanding_expr_field_inc(e, 0);
        void *idx = lean_freestanding_expr_field_inc(e, 1);
        void *x = lean_freestanding_expr_lift_at(lean_freestanding_expr_field(e, 2), s, d, offset);
        return lean_expr_mk_proj(n, idx, x);
    }
    default:
        lean_inc(e);
        return e;
    }
}

static void *lean_freestanding_expr_instantiate1_at(void *e, void *subst, size_t offset) {
    if (offset >= lean_freestanding_expr_bvar_range(e)) {
        lean_inc(e);
        return e;
    }
    unsigned tag = ((lean_object *)e)->m_tag;
    if (tag == 0) {
        void *idx_obj = lean_freestanding_expr_field(e, 0);
        if (lean_freestanding_is_scalar(idx_obj)) {
            size_t idx = lean_unbox(idx_obj);
            if (idx >= offset) {
                if (idx == offset) return lean_freestanding_expr_lift_at(subst, 0, offset, 0);
                return lean_expr_mk_bvar(lean_uint64_to_nat(idx - 1));
            }
        }
        lean_inc(e);
        return e;
    }
    switch (tag) {
    case 5: {
        void *f = lean_freestanding_expr_instantiate1_at(lean_freestanding_expr_field(e, 0), subst, offset);
        void *a = lean_freestanding_expr_instantiate1_at(lean_freestanding_expr_field(e, 1), subst, offset);
        return lean_expr_mk_app(f, a);
    }
    case 6: case 7: {
        void *n = lean_freestanding_expr_field_inc(e, 0);
        void *t = lean_freestanding_expr_instantiate1_at(lean_freestanding_expr_field(e, 1), subst, offset);
        void *b = lean_freestanding_expr_instantiate1_at(lean_freestanding_expr_field(e, 2), subst, offset + 1);
        return tag == 6 ? lean_expr_mk_lambda(n, t, b, lean_freestanding_expr_uint8(e, 0))
                        : lean_expr_mk_forall(n, t, b, lean_freestanding_expr_uint8(e, 0));
    }
    case 8: {
        void *n = lean_freestanding_expr_field_inc(e, 0);
        void *t = lean_freestanding_expr_instantiate1_at(lean_freestanding_expr_field(e, 1), subst, offset);
        void *v = lean_freestanding_expr_instantiate1_at(lean_freestanding_expr_field(e, 2), subst, offset);
        void *b = lean_freestanding_expr_instantiate1_at(lean_freestanding_expr_field(e, 3), subst, offset + 1);
        return lean_expr_mk_let(n, t, v, b, lean_freestanding_expr_uint8(e, 0));
    }
    case 10: {
        void *m = lean_freestanding_expr_field_inc(e, 0);
        void *x = lean_freestanding_expr_instantiate1_at(lean_freestanding_expr_field(e, 1), subst, offset);
        return lean_expr_mk_mdata(m, x);
    }
    case 11: {
        void *n = lean_freestanding_expr_field_inc(e, 0);
        void *idx = lean_freestanding_expr_field_inc(e, 1);
        void *x = lean_freestanding_expr_instantiate1_at(lean_freestanding_expr_field(e, 2), subst, offset);
        return lean_expr_mk_proj(n, idx, x);
    }
    default:
        lean_inc(e);
        return e;
    }
}

void *lean_expr_instantiate1(void *a, void *e) {
    if (lean_freestanding_expr_bvar_range(a) == 0) {
        lean_inc(a);
        return a;
    }
    return lean_freestanding_expr_instantiate1_at(a, e, 0);
}

static void *lean_freestanding_expr_lower_at(void *e, size_t s, size_t d, size_t offset) {
    if (d == 0) {
        lean_inc(e);
        return e;
    }
    size_t s1 = s + offset;
    if (s1 < s || s1 >= lean_freestanding_expr_bvar_range(e)) {
        lean_inc(e);
        return e;
    }
    unsigned tag = ((lean_object *)e)->m_tag;
    if (tag == 0) {
        void *idx_obj = lean_freestanding_expr_field(e, 0);
        if (lean_freestanding_is_scalar(idx_obj)) {
            size_t idx = lean_unbox(idx_obj);
            if (idx >= s1) return lean_expr_mk_bvar(lean_uint64_to_nat(idx - d));
        }
        lean_inc(e);
        return e;
    }
    switch (tag) {
    case 5: {
        void *f = lean_freestanding_expr_lower_at(lean_freestanding_expr_field(e, 0), s, d, offset);
        void *a = lean_freestanding_expr_lower_at(lean_freestanding_expr_field(e, 1), s, d, offset);
        return lean_expr_mk_app(f, a);
    }
    case 6: case 7: {
        void *n = lean_freestanding_expr_field_inc(e, 0);
        void *t = lean_freestanding_expr_lower_at(lean_freestanding_expr_field(e, 1), s, d, offset);
        void *b = lean_freestanding_expr_lower_at(lean_freestanding_expr_field(e, 2), s, d, offset + 1);
        return tag == 6 ? lean_expr_mk_lambda(n, t, b, lean_freestanding_expr_uint8(e, 0))
                        : lean_expr_mk_forall(n, t, b, lean_freestanding_expr_uint8(e, 0));
    }
    case 8: {
        void *n = lean_freestanding_expr_field_inc(e, 0);
        void *t = lean_freestanding_expr_lower_at(lean_freestanding_expr_field(e, 1), s, d, offset);
        void *v = lean_freestanding_expr_lower_at(lean_freestanding_expr_field(e, 2), s, d, offset);
        void *b = lean_freestanding_expr_lower_at(lean_freestanding_expr_field(e, 3), s, d, offset + 1);
        return lean_expr_mk_let(n, t, v, b, lean_freestanding_expr_uint8(e, 0));
    }
    case 10: {
        void *m = lean_freestanding_expr_field_inc(e, 0);
        void *x = lean_freestanding_expr_lower_at(lean_freestanding_expr_field(e, 1), s, d, offset);
        return lean_expr_mk_mdata(m, x);
    }
    case 11: {
        void *n = lean_freestanding_expr_field_inc(e, 0);
        void *idx = lean_freestanding_expr_field_inc(e, 1);
        void *x = lean_freestanding_expr_lower_at(lean_freestanding_expr_field(e, 2), s, d, offset);
        return lean_expr_mk_proj(n, idx, x);
    }
    default:
        lean_inc(e);
        return e;
    }
}

void *lean_expr_lower_loose_bvars(void *e, void *s, void *d) {
    if (!lean_freestanding_is_scalar(s) || !lean_freestanding_is_scalar(d) ||
        lean_unbox(s) < lean_unbox(d)) {
        lean_inc(e);
        return e;
    }
    return lean_freestanding_expr_lower_at(e, lean_unbox(s), lean_unbox(d), 0);
}

void *lean_expr_lift_loose_bvars(void *e, void *s, void *d) {
    if (!lean_freestanding_is_scalar(s) || !lean_freestanding_is_scalar(d)) {
        lean_inc(e);
        return e;
    }
    return lean_freestanding_expr_lift_at(e, lean_unbox(s), lean_unbox(d), 0);
}

static void *lean_freestanding_expr_instantiate_at(void *e, size_t n, lean_object **subst, uint8_t rev, size_t offset) {
    if (n == 0 || offset >= lean_freestanding_expr_bvar_range(e)) {
        lean_inc(e);
        return e;
    }
    unsigned tag = ((lean_object *)e)->m_tag;
    if (tag == 0) {
        void *idx_obj = lean_freestanding_expr_field(e, 0);
        if (lean_freestanding_is_scalar(idx_obj)) {
            size_t idx = lean_unbox(idx_obj);
            if (idx >= offset) {
                size_t j = idx - offset;
                if (j < n) {
                    void *v = rev ? subst[n - j - 1] : subst[j];
                    return lean_freestanding_expr_lift_at(v, 0, offset, 0);
                }
                return lean_expr_mk_bvar(lean_uint64_to_nat(idx - n));
            }
        }
        lean_inc(e);
        return e;
    }
    switch (tag) {
    case 5: {
        void *f = lean_freestanding_expr_instantiate_at(lean_freestanding_expr_field(e, 0), n, subst, rev, offset);
        void *a = lean_freestanding_expr_instantiate_at(lean_freestanding_expr_field(e, 1), n, subst, rev, offset);
        return lean_expr_mk_app(f, a);
    }
    case 6: case 7: {
        void *bn = lean_freestanding_expr_field_inc(e, 0);
        void *t = lean_freestanding_expr_instantiate_at(lean_freestanding_expr_field(e, 1), n, subst, rev, offset);
        void *b = lean_freestanding_expr_instantiate_at(lean_freestanding_expr_field(e, 2), n, subst, rev, offset + 1);
        return tag == 6 ? lean_expr_mk_lambda(bn, t, b, lean_freestanding_expr_uint8(e, 0))
                        : lean_expr_mk_forall(bn, t, b, lean_freestanding_expr_uint8(e, 0));
    }
    case 8: {
        void *dn = lean_freestanding_expr_field_inc(e, 0);
        void *t = lean_freestanding_expr_instantiate_at(lean_freestanding_expr_field(e, 1), n, subst, rev, offset);
        void *v = lean_freestanding_expr_instantiate_at(lean_freestanding_expr_field(e, 2), n, subst, rev, offset);
        void *b = lean_freestanding_expr_instantiate_at(lean_freestanding_expr_field(e, 3), n, subst, rev, offset + 1);
        return lean_expr_mk_let(dn, t, v, b, lean_freestanding_expr_uint8(e, 0));
    }
    case 10: {
        void *m = lean_freestanding_expr_field_inc(e, 0);
        void *x = lean_freestanding_expr_instantiate_at(lean_freestanding_expr_field(e, 1), n, subst, rev, offset);
        return lean_expr_mk_mdata(m, x);
    }
    case 11: {
        void *sn = lean_freestanding_expr_field_inc(e, 0);
        void *idx = lean_freestanding_expr_field_inc(e, 1);
        void *x = lean_freestanding_expr_instantiate_at(lean_freestanding_expr_field(e, 2), n, subst, rev, offset);
        return lean_expr_mk_proj(sn, idx, x);
    }
    default:
        lean_inc(e);
        return e;
    }
}

void *lean_expr_instantiate(void *a, void *subst) {
    lean_array_object *arr = (lean_array_object *)subst;
    return lean_freestanding_expr_instantiate_at(a, arr->m_size, arr->m_data, 0, 0);
}

void *lean_expr_instantiate_rev(void *a, void *subst) {
    lean_array_object *arr = (lean_array_object *)subst;
    void *r = lean_freestanding_expr_instantiate_at(a, arr->m_size, arr->m_data, 1, 0);
    if (!lean_freestanding_is_scalar(a) && ((lean_object *)a)->m_tag == 0 && arr->m_size > 0 &&
        !lean_freestanding_is_scalar(r) && ((lean_object *)r)->m_tag == 0) {
        uint64_t idx = 0;
        void *idx_obj = lean_freestanding_expr_field(a, 0);
        if (lean_freestanding_is_scalar(idx_obj)) idx = lean_unbox(idx_obj);
        uint64_t sub_tag = lean_freestanding_is_scalar(arr->m_data[arr->m_size - 1])
            ? 0xffffffffffffffffULL
            : ((lean_object *)arr->m_data[arr->m_size - 1])->m_tag;
        lean_freestanding_panic("instantiate_rev_bvar_result", idx, sub_tag);
        __builtin_unreachable();
    }
    return r;
}

void *lean_expr_instantiate_range(void *a, void *begin, void *end, void *subst) {
    lean_array_object *arr = (lean_array_object *)subst;
    if (!lean_freestanding_is_scalar(begin) || !lean_freestanding_is_scalar(end)) {
        lean_freestanding_panic("invalid Expr.instantiateRange", 0, 0);
        __builtin_unreachable();
    }
    size_t b = lean_unbox(begin);
    size_t e = lean_unbox(end);
    if (b > e || e > arr->m_size) {
        lean_freestanding_panic("invalid Expr.instantiateRange", b, e);
        __builtin_unreachable();
    }
    return lean_freestanding_expr_instantiate_at(a, e - b, arr->m_data + b, 0, 0);
}

void *lean_expr_instantiate_rev_range(void *a, void *begin, void *end, void *subst) {
    lean_array_object *arr = (lean_array_object *)subst;
    if (!lean_freestanding_is_scalar(begin) || !lean_freestanding_is_scalar(end)) {
        lean_freestanding_panic("invalid Expr.instantiateRevRange", 0, 0);
        __builtin_unreachable();
    }
    size_t b = lean_unbox(begin);
    size_t e = lean_unbox(end);
    if (b > e || e > arr->m_size) {
        lean_freestanding_panic("invalid Expr.instantiateRevRange", b, e);
        __builtin_unreachable();
    }
    return lean_freestanding_expr_instantiate_at(a, e - b, arr->m_data + b, 1, 0);
}

static void *lean_freestanding_expr_some(void *e) {
    void *r = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(r, 0, e);
    return r;
}

static uint8_t lean_freestanding_find_expr_at(void *p, void *e, void **found) {
    lean_inc(p);
    lean_inc(e);
    void *r = lean_apply_1(p, e);
    if (lean_freestanding_is_scalar(r) && lean_unbox(r) != 0) {
        lean_inc(e);
        *found = e;
        return 1;
    }
    if (!lean_freestanding_is_scalar(r)) lean_dec(r);
    switch (((lean_object *)e)->m_tag) {
    case 5:
        if (lean_freestanding_find_expr_at(p, lean_freestanding_expr_field(e, 0), found)) return 1;
        return lean_freestanding_find_expr_at(p, lean_freestanding_expr_field(e, 1), found);
    case 6: case 7:
        if (lean_freestanding_find_expr_at(p, lean_freestanding_expr_field(e, 1), found)) return 1;
        return lean_freestanding_find_expr_at(p, lean_freestanding_expr_field(e, 2), found);
    case 8:
        if (lean_freestanding_find_expr_at(p, lean_freestanding_expr_field(e, 1), found)) return 1;
        if (lean_freestanding_find_expr_at(p, lean_freestanding_expr_field(e, 2), found)) return 1;
        return lean_freestanding_find_expr_at(p, lean_freestanding_expr_field(e, 3), found);
    case 10:
        return lean_freestanding_find_expr_at(p, lean_freestanding_expr_field(e, 1), found);
    case 11:
        return lean_freestanding_find_expr_at(p, lean_freestanding_expr_field(e, 2), found);
    default:
        return 0;
    }
}

void *lean_find_expr(void *p, void *e) {
    void *found = 0;
    if (lean_freestanding_find_expr_at(p, e, &found)) return lean_freestanding_expr_some(found);
    return lean_box(0);
}

static void *lean_freestanding_replace_expr_at(void *f, void *e) {
    lean_inc(f);
    lean_inc(e);
    void *r = lean_apply_1(f, e);
    if (!lean_freestanding_is_scalar(r)) {
        void *new_e = lean_ctor_get(r, 0);
        lean_inc(new_e);
        lean_dec(r);
        return new_e;
    }
    switch (((lean_object *)e)->m_tag) {
    case 5: {
        void *nf = lean_freestanding_replace_expr_at(f, lean_freestanding_expr_field(e, 0));
        void *na = lean_freestanding_replace_expr_at(f, lean_freestanding_expr_field(e, 1));
        return lean_expr_mk_app(nf, na);
    }
    case 6: case 7: {
        void *n = lean_freestanding_expr_field_inc(e, 0);
        void *t = lean_freestanding_replace_expr_at(f, lean_freestanding_expr_field(e, 1));
        void *b = lean_freestanding_replace_expr_at(f, lean_freestanding_expr_field(e, 2));
        return ((lean_object *)e)->m_tag == 6
            ? lean_expr_mk_lambda(n, t, b, lean_freestanding_expr_uint8(e, 0))
            : lean_expr_mk_forall(n, t, b, lean_freestanding_expr_uint8(e, 0));
    }
    case 8: {
        void *n = lean_freestanding_expr_field_inc(e, 0);
        void *t = lean_freestanding_replace_expr_at(f, lean_freestanding_expr_field(e, 1));
        void *v = lean_freestanding_replace_expr_at(f, lean_freestanding_expr_field(e, 2));
        void *b = lean_freestanding_replace_expr_at(f, lean_freestanding_expr_field(e, 3));
        return lean_expr_mk_let(n, t, v, b, lean_freestanding_expr_uint8(e, 0));
    }
    case 10: {
        void *m = lean_freestanding_expr_field_inc(e, 0);
        void *x = lean_freestanding_replace_expr_at(f, lean_freestanding_expr_field(e, 1));
        return lean_expr_mk_mdata(m, x);
    }
    case 11: {
        void *n = lean_freestanding_expr_field_inc(e, 0);
        void *idx = lean_freestanding_expr_field_inc(e, 1);
        void *x = lean_freestanding_replace_expr_at(f, lean_freestanding_expr_field(e, 2));
        return lean_expr_mk_proj(n, idx, x);
    }
    default:
        lean_inc(e);
        return e;
    }
}

void *lean_replace_expr(void *f, void *e) {
    return lean_freestanding_replace_expr_at(f, e);
}

static uint8_t lean_freestanding_expr_same_fvar_or_mvar(void *candidate, unsigned tag, void *name) {
    if (lean_freestanding_is_scalar(candidate) || ((lean_object *)candidate)->m_tag != tag) return 0;
    return lean_name_eq(lean_freestanding_expr_field(candidate, 0), name);
}

static void *lean_freestanding_expr_abstract_at(void *e, size_t n, void *subst, size_t offset) {
    unsigned tag = ((lean_object *)e)->m_tag;
    if (tag == 1 || tag == 2) {
        void *name = lean_freestanding_expr_field(e, 0);
        lean_array_object *arr = (lean_array_object *)subst;
        for (size_t i = n; i > 0; --i) {
            void *v = arr->m_data[i - 1];
            if (lean_freestanding_expr_same_fvar_or_mvar(v, tag, name)) {
                return lean_expr_mk_bvar(lean_uint64_to_nat(offset + n - i));
            }
        }
        lean_inc(e);
        return e;
    }
    switch (tag) {
    case 5: {
        void *f = lean_freestanding_expr_abstract_at(lean_freestanding_expr_field(e, 0), n, subst, offset);
        void *a = lean_freestanding_expr_abstract_at(lean_freestanding_expr_field(e, 1), n, subst, offset);
        return lean_expr_mk_app(f, a);
    }
    case 6: case 7: {
        void *bn = lean_freestanding_expr_field_inc(e, 0);
        void *t = lean_freestanding_expr_abstract_at(lean_freestanding_expr_field(e, 1), n, subst, offset);
        void *b = lean_freestanding_expr_abstract_at(lean_freestanding_expr_field(e, 2), n, subst, offset + 1);
        return tag == 6 ? lean_expr_mk_lambda(bn, t, b, lean_freestanding_expr_uint8(e, 0))
                        : lean_expr_mk_forall(bn, t, b, lean_freestanding_expr_uint8(e, 0));
    }
    case 8: {
        void *dn = lean_freestanding_expr_field_inc(e, 0);
        void *t = lean_freestanding_expr_abstract_at(lean_freestanding_expr_field(e, 1), n, subst, offset);
        void *v = lean_freestanding_expr_abstract_at(lean_freestanding_expr_field(e, 2), n, subst, offset);
        void *b = lean_freestanding_expr_abstract_at(lean_freestanding_expr_field(e, 3), n, subst, offset + 1);
        return lean_expr_mk_let(dn, t, v, b, lean_freestanding_expr_uint8(e, 0));
    }
    case 10: {
        void *m = lean_freestanding_expr_field_inc(e, 0);
        void *x = lean_freestanding_expr_abstract_at(lean_freestanding_expr_field(e, 1), n, subst, offset);
        return lean_expr_mk_mdata(m, x);
    }
    case 11: {
        void *sn = lean_freestanding_expr_field_inc(e, 0);
        void *idx = lean_freestanding_expr_field_inc(e, 1);
        void *x = lean_freestanding_expr_abstract_at(lean_freestanding_expr_field(e, 2), n, subst, offset);
        return lean_expr_mk_proj(sn, idx, x);
    }
    default:
        lean_inc(e);
        return e;
    }
}

void *lean_expr_abstract_range(void *e, void *n, void *subst) {
    size_t sz = ((lean_array_object *)subst)->m_size;
    size_t count = sz;
    if (lean_freestanding_is_scalar(n) && lean_unbox(n) < count) count = lean_unbox(n);
    return lean_freestanding_expr_abstract_at(e, count, subst, 0);
}

void *lean_expr_abstract(void *e, void *subst) {
    return lean_freestanding_expr_abstract_at(e, ((lean_array_object *)subst)->m_size, subst, 0);
}

static uint8_t lean_freestanding_level_list_eq(void *as, void *bs) {
    while (!lean_freestanding_is_scalar(as) && !lean_freestanding_is_scalar(bs)) {
        lean_ctor_object *a = (lean_ctor_object *)as;
        lean_ctor_object *b = (lean_ctor_object *)bs;
        if (!lean_level_eq(a->m_objs[0], b->m_objs[0])) return 0;
        as = a->m_objs[1];
        bs = b->m_objs[1];
    }
    return as == bs;
}

static uint8_t lean_freestanding_literal_eq(void *a, void *b) {
    if (a == b) return 1;
    if (((lean_object *)a)->m_tag != ((lean_object *)b)->m_tag) return 0;
    void *av = lean_freestanding_expr_field(a, 0);
    void *bv = lean_freestanding_expr_field(b, 0);
    return ((lean_object *)a)->m_tag == 0 ? lean_nat_dec_eq(av, bv) : lean_string_dec_eq(av, bv);
}

static uint8_t lean_freestanding_expr_eq(void *a, void *b, uint8_t compare_binder_info) {
    if (a == b) return 1;
    unsigned atag = ((lean_object *)a)->m_tag;
    unsigned btag = ((lean_object *)b)->m_tag;
    if (atag != btag) return 0;
    if ((uint32_t)lean_expr_data(a) != (uint32_t)lean_expr_data(b)) return 0;
    switch (atag) {
    case 0:
        return lean_nat_dec_eq(lean_freestanding_expr_field(a, 0), lean_freestanding_expr_field(b, 0));
    case 1: case 2:
        return lean_name_eq(lean_freestanding_expr_field(a, 0), lean_freestanding_expr_field(b, 0));
    case 3:
        return lean_level_eq(lean_freestanding_expr_field(a, 0), lean_freestanding_expr_field(b, 0));
    case 4:
        return lean_name_eq(lean_freestanding_expr_field(a, 0), lean_freestanding_expr_field(b, 0)) &&
               lean_freestanding_level_list_eq(lean_freestanding_expr_field(a, 1), lean_freestanding_expr_field(b, 1));
    case 5:
        return lean_freestanding_expr_eq(lean_freestanding_expr_field(a, 0), lean_freestanding_expr_field(b, 0), compare_binder_info) &&
               lean_freestanding_expr_eq(lean_freestanding_expr_field(a, 1), lean_freestanding_expr_field(b, 1), compare_binder_info);
    case 6: case 7:
        if (!lean_freestanding_expr_eq(lean_freestanding_expr_field(a, 1), lean_freestanding_expr_field(b, 1), compare_binder_info)) return 0;
        if (!lean_freestanding_expr_eq(lean_freestanding_expr_field(a, 2), lean_freestanding_expr_field(b, 2), compare_binder_info)) return 0;
        if (!compare_binder_info) return 1;
        return lean_name_eq(lean_freestanding_expr_field(a, 0), lean_freestanding_expr_field(b, 0)) &&
               lean_freestanding_expr_uint8(a, 0) == lean_freestanding_expr_uint8(b, 0);
    case 8:
        if (!lean_freestanding_expr_eq(lean_freestanding_expr_field(a, 1), lean_freestanding_expr_field(b, 1), compare_binder_info)) return 0;
        if (!lean_freestanding_expr_eq(lean_freestanding_expr_field(a, 2), lean_freestanding_expr_field(b, 2), compare_binder_info)) return 0;
        if (!lean_freestanding_expr_eq(lean_freestanding_expr_field(a, 3), lean_freestanding_expr_field(b, 3), compare_binder_info)) return 0;
        if (lean_freestanding_expr_uint8(a, 0) != lean_freestanding_expr_uint8(b, 0)) return 0;
        return !compare_binder_info || lean_name_eq(lean_freestanding_expr_field(a, 0), lean_freestanding_expr_field(b, 0));
    case 9:
        return lean_freestanding_literal_eq(lean_freestanding_expr_field(a, 0), lean_freestanding_expr_field(b, 0));
    case 10:
        return lean_freestanding_expr_field(a, 0) == lean_freestanding_expr_field(b, 0) &&
               lean_freestanding_expr_eq(lean_freestanding_expr_field(a, 1), lean_freestanding_expr_field(b, 1), compare_binder_info);
    case 11:
        return lean_name_eq(lean_freestanding_expr_field(a, 0), lean_freestanding_expr_field(b, 0)) &&
               lean_nat_dec_eq(lean_freestanding_expr_field(a, 1), lean_freestanding_expr_field(b, 1)) &&
               lean_freestanding_expr_eq(lean_freestanding_expr_field(a, 2), lean_freestanding_expr_field(b, 2), compare_binder_info);
    default:
        return 0;
    }
}

uint8_t lean_expr_eqv(void *a, void *b) {
    return lean_freestanding_expr_eq(a, b, 0);
}

uint8_t lean_expr_equal(void *a, void *b) {
    return lean_freestanding_expr_eq(a, b, 1);
}

uint8_t lean_expr_quick_lt(void *a, void *b) {
    if (a == b || lean_expr_equal(a, b)) return 0;
    uint32_t ah = (uint32_t)lean_expr_data(a);
    uint32_t bh = (uint32_t)lean_expr_data(b);
    if (ah != bh) return ah < bh;
    unsigned atag = ((lean_object *)a)->m_tag;
    unsigned btag = ((lean_object *)b)->m_tag;
    if (atag != btag) return atag < btag;
    return (uintptr_t)a < (uintptr_t)b;
}

uint8_t lean_expr_lt(void *a, void *b) {
    return lean_expr_quick_lt(a, b);
}

void *lean_expr_dbg_to_string(void *e) {
    (void)e;
    return lean_mk_ascii_string_unchecked("<expr>");
}

/* ===========================================================================
   Lean-generated kernel specialization shims
   ===========================================================================
   Some imported Lean modules expose generated specialization symbols whose
   bodies are pure data-structure code. Pulling their defining modules into a
   freestanding kernel image drags in large elaborator/pretty-printer closures,
   so the restricted runtime provides the small pure fragments needed by
   lean4lean's kernel-facing path.
*/

uint8_t l_Bool_toLBool(uint8_t b) {
    return b ? 1 : 0;
}

uint8_t l_Lean_instBEqLBool_beq(uint8_t a, uint8_t b) {
    return a == b;
}

void *l_panic___at___00Lean_SubExpr_Pos_head_spec__0(void *default_val) {
    return lean_panic_fn(default_val, lean_mk_ascii_string_unchecked("Lean.SubExpr.Pos.head: empty position"));
}

void *l_panic___at___00__private_Lean_PrettyPrinter_Delaborator_Builtins_0__Lean_PrettyPrinter_Delaborator_delabAppImplicitCore_mkArg_spec__0(void *default_val) {
    return lean_panic_fn(default_val, lean_mk_ascii_string_unchecked("delabAppImplicitCore.mkArg"));
}

uint8_t l_List_elem___at___00Lean_Elab_expandDeclId_spec__0(void *a, void *xs) {
    while (!lean_freestanding_is_scalar(xs)) {
        lean_ctor_object *cell = (lean_ctor_object *)xs;
        if (lean_name_eq(a, cell->m_objs[0])) return 1;
        xs = cell->m_objs[1];
    }
    return 0;
}

uint8_t l_List_beq___at___00Lean_Compiler_LCNF_instBEqLetValue_beq_spec__1(void *xs, void *ys) {
    while (!lean_freestanding_is_scalar(xs) && !lean_freestanding_is_scalar(ys)) {
        lean_ctor_object *xcell = (lean_ctor_object *)xs;
        lean_ctor_object *ycell = (lean_ctor_object *)ys;
        if (!lean_level_eq(xcell->m_objs[0], ycell->m_objs[0])) return 0;
        xs = xcell->m_objs[1];
        ys = ycell->m_objs[1];
    }
    return xs == ys;
}

uint8_t l_Array_contains___at___00__private_Lean_Elab_Term_TermElabM_0__Lean_Elab_Term_collectUnassignedMVars_go_spec__0(void *arr_obj, void *needle) {
    lean_array_object *arr = (lean_array_object *)arr_obj;
    for (size_t i = 0; i < arr->m_size; ++i) {
        if (lean_expr_eqv(needle, arr->m_data[i])) return 1;
    }
    return 0;
}

static void *lean_freestanding_option_some(void *value) {
    void *r = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(r, 0, value);
    return r;
}

static size_t lean_freestanding_hash_index(uint64_t hash, size_t bucket_count) {
    hash ^= hash >> 32;
    hash ^= hash >> 16;
    return (size_t)hash & (bucket_count - 1);
}

static size_t lean_freestanding_expr_hash_index(void *key, void *buckets_obj) {
    size_t bucket_count = ((lean_array_object *)buckets_obj)->m_size;
    return lean_freestanding_hash_index(lean_expr_hash(key), bucket_count);
}

static size_t lean_freestanding_ptr_hash_index(void *key, void *buckets_obj) {
    uint64_t hash = lean_uint64_mix_hash((uint64_t)(uintptr_t)key, 11);
    size_t bucket_count = ((lean_array_object *)buckets_obj)->m_size;
    return lean_freestanding_hash_index(hash, bucket_count);
}

static void *lean_freestanding_assoc_get_expr(void *key, void *xs) {
    while (!lean_freestanding_is_scalar(xs)) {
        lean_ctor_object *cell = (lean_ctor_object *)xs;
        if (lean_expr_eqv(key, cell->m_objs[0])) {
            lean_inc(cell->m_objs[1]);
            return lean_freestanding_option_some(cell->m_objs[1]);
        }
        xs = cell->m_objs[2];
    }
    return lean_box(0);
}

static uint8_t lean_freestanding_assoc_contains_expr(void *key, void *xs) {
    while (!lean_freestanding_is_scalar(xs)) {
        lean_ctor_object *cell = (lean_ctor_object *)xs;
        if (lean_expr_eqv(key, cell->m_objs[0])) return 1;
        xs = cell->m_objs[2];
    }
    return 0;
}

static void *lean_freestanding_assoc_replace_expr(void *key, void *value, void *xs) {
    if (lean_freestanding_is_scalar(xs)) {
        lean_dec(key);
        lean_dec(value);
        return xs;
    }

    lean_ctor_object *cell = (lean_ctor_object *)xs;
    if (lean_expr_eqv(key, cell->m_objs[0])) {
        lean_inc(cell->m_objs[2]);
        void *r = lean_alloc_ctor(1, 3, 0);
        lean_ctor_set(r, 0, key);
        lean_ctor_set(r, 1, value);
        lean_ctor_set(r, 2, cell->m_objs[2]);
        return r;
    }

    lean_inc(cell->m_objs[0]);
    lean_inc(cell->m_objs[1]);
    void *tail = lean_freestanding_assoc_replace_expr(key, value, cell->m_objs[2]);
    void *r = lean_alloc_ctor(1, 3, 0);
    lean_ctor_set(r, 0, cell->m_objs[0]);
    lean_ctor_set(r, 1, cell->m_objs[1]);
    lean_ctor_set(r, 2, tail);
    return r;
}

static void *lean_freestanding_dhashmap_expand(void *buckets_obj, uint8_t key_is_ptr) {
    lean_array_object *old_buckets = (lean_array_object *)buckets_obj;
    size_t old_size = old_buckets->m_size;
    void *new_buckets = lean_mk_array(lean_usize_to_nat(old_size == 0 ? 8 : old_size * 2), lean_box(0));
    for (size_t i = 0; i < old_size; ++i) {
        void *xs = old_buckets->m_data[i];
        while (!lean_freestanding_is_scalar(xs)) {
            lean_ctor_object *cell = (lean_ctor_object *)xs;
            size_t j = key_is_ptr
                ? lean_freestanding_ptr_hash_index(cell->m_objs[0], new_buckets)
                : lean_freestanding_expr_hash_index(cell->m_objs[0], new_buckets);
            void *bucket = lean_array_uget_borrowed(new_buckets, j);
            lean_inc(bucket);
            lean_inc(cell->m_objs[0]);
            lean_inc(cell->m_objs[1]);
            void *new_cell = lean_alloc_ctor(1, 3, 0);
            lean_ctor_set(new_cell, 0, cell->m_objs[0]);
            lean_ctor_set(new_cell, 1, cell->m_objs[1]);
            lean_ctor_set(new_cell, 2, bucket);
            new_buckets = lean_array_uset(new_buckets, j, new_cell);
            xs = cell->m_objs[2];
        }
    }
    lean_dec(buckets_obj);
    return new_buckets;
}

void *l_Std_DHashMap_Internal_Raw_u2080_Const_get_x3f___at___00Lean_Elab_Term_ContainsPendingMVar_visit_spec__1___redArg(void *map, void *key) {
    void *buckets = lean_ctor_get(map, 1);
    if (((lean_array_object *)buckets)->m_size == 0) return lean_box(0);
    size_t i = lean_freestanding_expr_hash_index(key, buckets);
    return lean_freestanding_assoc_get_expr(key, lean_array_uget_borrowed(buckets, i));
}

void *l_Std_DHashMap_Internal_Raw_u2080_insert___at___00Lean_Elab_Term_ContainsPendingMVar_visit_spec__0___redArg(void *map, void *key, void *value) {
    void *size_obj = lean_ctor_get(map, 0);
    void *buckets = lean_ctor_get(map, 1);
    lean_inc(size_obj);
    lean_inc(buckets);
    lean_dec(map);

    if (((lean_array_object *)buckets)->m_size == 0) {
        lean_dec(buckets);
        buckets = lean_mk_array(lean_box(8), lean_box(0));
    }

    size_t i = lean_freestanding_expr_hash_index(key, buckets);
    void *bucket = lean_array_uget_borrowed(buckets, i);
    void *new_size = size_obj;
    void *new_bucket;
    if (lean_freestanding_assoc_contains_expr(key, bucket)) {
        new_bucket = lean_freestanding_assoc_replace_expr(key, value, bucket);
    } else {
        new_size = lean_nat_add(size_obj, lean_box(1));
        lean_dec(size_obj);
        lean_inc(bucket);
        new_bucket = lean_alloc_ctor(1, 3, 0);
        lean_ctor_set(new_bucket, 0, key);
        lean_ctor_set(new_bucket, 1, value);
        lean_ctor_set(new_bucket, 2, bucket);
    }

    buckets = lean_array_uset(buckets, i, new_bucket);
    size_t count = lean_freestanding_is_scalar(new_size) ? lean_unbox(new_size) : 0;
    size_t capacity = ((lean_array_object *)buckets)->m_size;
    if (capacity != 0 && count * 4 > capacity * 3) {
        buckets = lean_freestanding_dhashmap_expand(buckets, 0);
    }

    void *r = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(r, 0, new_size);
    lean_ctor_set(r, 1, buckets);
    return r;
}

uint8_t l_Std_DHashMap_Internal_AssocList_contains___at___00Std_DHashMap_Internal_Raw_u2080_contains___at___00Lean_Expr_NumObjs_visit_spec__0_spec__0___redArg(void *key, void *xs) {
    while (!lean_freestanding_is_scalar(xs)) {
        lean_ctor_object *cell = (lean_ctor_object *)xs;
        if (cell->m_objs[0] == key) return 1;
        xs = cell->m_objs[2];
    }
    return 0;
}

void *l_Std_DHashMap_Internal_Raw_u2080_expand___at___00Std_DHashMap_Internal_Raw_u2080_insertIfNew___at___00Lean_Expr_NumObjs_visit_spec__1_spec__2___redArg(void *buckets) {
    return lean_freestanding_dhashmap_expand(buckets, 1);
}

extern uint8_t l___private_Lean_Data_Name_0__Lean_Name_quickCmpImpl(void *a, void *b);

void *l_Std_DTreeMap_Internal_Impl_Const_getD___at___00__private_Lean_Parser_Term_Doc_0__Lean_Parser_Term_Doc_initFn_00___x40_Lean_Parser_Term_Doc_383197578____hygCtx___hyg_2__spec__2___redArg(void *tree, void *key, void *fallback) {
    while (!lean_freestanding_is_scalar(tree) && ((lean_object *)tree)->m_tag == 0) {
        lean_ctor_object *node = (lean_ctor_object *)tree;
        switch (l___private_Lean_Data_Name_0__Lean_Name_quickCmpImpl(key, node->m_objs[1])) {
        case 0:
            tree = node->m_objs[3];
            break;
        case 1:
            lean_inc(node->m_objs[2]);
            return node->m_objs[2];
        default:
            tree = node->m_objs[4];
            break;
        }
    }
    lean_inc(fallback);
    return fallback;
}
