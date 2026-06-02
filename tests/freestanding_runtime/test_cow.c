/*
 * Host-side differential harness for the freestanding runtime's
 * copy-on-write invariants. Companion TU runtime_host.c compiles
 * runtime.c with a static heap; this file links against the public
 * symbols and drives them through the scenarios from bug.txt §432-480
 * plus exclusivity-contract checks.
 *
 * Failure here => the RC + COW contract is broken; downstream Lean
 * programs targeting this runtime will silently miscompute when arrays
 * are used non-linearly.
 */

#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

/* --- Freestanding runtime public API surface we exercise. ---------- */

extern void *lean_box(size_t n);
extern uint64_t lean_unbox(void *o);

extern void  lean_inc_ref(void *o);
extern void  lean_dec_ref(void *o);
extern void  lean_dec(void *o);
extern uint8_t lean_is_exclusive(void *o);
extern void  lean_mark_persistent(void *o);
extern size_t lean_freestanding_heap_used_bytes(void);
extern size_t lean_freestanding_heap_live_bytes(void);

extern void *lean_alloc_array(size_t size, size_t capacity);
extern void *lean_alloc_ctor(unsigned tag, unsigned num_objs, unsigned scalar_sz);
extern void *lean_ctor_get(void *o, unsigned i);
extern void  lean_ctor_set(void *o, unsigned i, void *v);
extern void  lean_ctor_release(void *o, unsigned i);
extern void *lean_mk_array(void *n, void *v);
extern size_t lean_array_size(void *a);
extern void *lean_array_uget_borrowed(void *a, size_t i);
extern void *lean_array_uset(void *a, size_t i, void *v);
extern void *lean_array_push(void *a, void *v);

extern void *lean_mk_empty_byte_array(void *capacity_box);
extern size_t lean_sarray_size(void *a);
extern uint8_t lean_byte_array_uget(void *a, size_t i);
extern void *lean_byte_array_uset(void *a, size_t i, uint8_t v);
extern void *lean_byte_array_push(void *a, uint8_t v);
extern void *lean_mk_empty_float_array(void *capacity_box);
extern void *lean_float_array_push(void *a, double v);
extern void *lean_float_array_uset(void *a, size_t i, double v);
extern void *lean_float_array_size(void *a);
extern double lean_float_array_uget(void *a, size_t i);
extern void *lean_mk_string(const char *s);
extern void *lean_string_push(void *s, uint32_t c);
extern void *lean_string_append(void *s1, void *s2);
extern void *lean_string_data(void *s);
extern void *lean_string_from_utf8_unchecked(void *bytes);
extern void *lean_alloc_closure(void *fun, unsigned arity, unsigned num_fixed);
extern void  lean_closure_set(void *c, unsigned i, void *v);
extern void *lean_apply_1(void *c, void *a1);
extern void *lean_apply_n(void *c, unsigned n, void **args);
extern void *lean_apply_m(void *c, unsigned n, void **args);
extern size_t lean_ptr_addr(void *o);
extern uint64_t lean_uint64_mix_hash(uint64_t h, uint64_t k);
extern void *lean_st_mk_ref(void *value);
extern void *lean_st_ref_get(void *ref);
extern void *lean_st_ref_set(void *ref, void *value);
extern void *lean_st_ref_take(void *ref);
extern void *lean_st_ref_swap(void *ref, void *value);
extern uint8_t lean_st_ref_ptr_eq(void *ref1, void *ref2);
extern void *lean_cstr_to_int(const char *s);
extern void *lean_nat_to_int(void *a);
extern void *lean_int_neg_succ_of_nat(void *a);
extern void *lean_int_neg(void *a);
extern void *lean_int_add(void *a, void *b);
extern void *lean_int_sub(void *a, void *b);
extern void *lean_int_mul(void *a, void *b);
extern void *lean_int_div(void *a, void *b);
extern void *lean_int_mod(void *a, void *b);
extern void *lean_int_ediv(void *a, void *b);
extern void *lean_int_emod(void *a, void *b);
extern uint8_t lean_int_dec_eq(void *a, void *b);
extern uint8_t lean_int_dec_nonneg(void *a);
extern uint8_t lean_int_dec_le(void *a, void *b);
extern uint8_t lean_int_dec_lt(void *a, void *b);
extern void *lean_nat_abs(void *a);

/* ---------------------------------------------------------------- */

static int g_failed = 0;

#define CHECK(cond, fmt, ...) do {                                      \
    if (!(cond)) {                                                      \
        fprintf(stderr, "FAIL %s: " fmt "\n", __func__, ##__VA_ARGS__); \
        g_failed = 1;                                                   \
        return;                                                         \
    }                                                                   \
} while (0)

static int64_t scalar_int_value(void *i) {
    return (int64_t)(int32_t)(uint32_t)lean_unbox(i);
}

/* Probe 1 (bug.txt §438): Array.push on an aliased array must not
   mutate the original. Reproduces:
       let a : Array UInt64 := Array.emptyWithCapacity 4
       let b := a.push 7
       assert a.size == 0 && b.size == 1 && b[0]! == 7
*/
static void test_array_push_aliasing(void) {
    void *a = lean_alloc_array(0, 4);   /* RC=1, size 0, cap 4 */
    lean_inc_ref(a);                    /* RC=2 -- simulate non-linear use */
    void *b = lean_array_push(a, lean_box(7));

    CHECK(b != a, "push returned the same pointer for an aliased array");
    CHECK(lean_array_size(a) == 0, "aliased original size=%zu, expected 0",
          lean_array_size(a));
    CHECK(lean_array_size(b) == 1, "pushed array size=%zu, expected 1",
          lean_array_size(b));
    CHECK(lean_unbox(lean_array_uget_borrowed(b, 0)) == 7,
          "pushed value=%" PRIu64 ", expected 7",
          lean_unbox(lean_array_uget_borrowed(b, 0)));
}

/* Probe 2 (bug.txt §446): Array.set! on an aliased array must not
   mutate the original. */
static void test_array_set_aliasing(void) {
    void *a = lean_mk_array(lean_box(3), lean_box(0));
    a = lean_array_uset(a, 0, lean_box(10));
    a = lean_array_uset(a, 1, lean_box(20));
    a = lean_array_uset(a, 2, lean_box(30));
    lean_inc_ref(a);                    /* RC=2 -- alias */
    void *b = lean_array_uset(a, 0, lean_box(99));

    CHECK(b != a, "uset returned the same pointer for an aliased array");
    CHECK(lean_unbox(lean_array_uget_borrowed(a, 0)) == 10,
          "aliased a[0]=%" PRIu64 ", expected 10",
          lean_unbox(lean_array_uget_borrowed(a, 0)));
    CHECK(lean_unbox(lean_array_uget_borrowed(b, 0)) == 99,
          "b[0]=%" PRIu64 ", expected 99",
          lean_unbox(lean_array_uget_borrowed(b, 0)));
    CHECK(lean_unbox(lean_array_uget_borrowed(a, 1)) == 20, "a[1] mismatch");
    CHECK(lean_unbox(lean_array_uget_borrowed(b, 1)) == 20, "b[1] mismatch");
    CHECK(lean_unbox(lean_array_uget_borrowed(a, 2)) == 30, "a[2] mismatch");
    CHECK(lean_unbox(lean_array_uget_borrowed(b, 2)) == 30, "b[2] mismatch");
}

/* Probe 3 (bug.txt §455): ByteArray.push on an aliased array must not
   mutate the original. */
static void test_byte_array_push_aliasing(void) {
    void *a = lean_mk_empty_byte_array(lean_box(4));  /* size 0, cap 4 */
    lean_inc_ref(a);                                  /* alias */
    void *b = lean_byte_array_push(a, 7);

    CHECK(b != a, "byte_array_push returned the same pointer for an aliased array");
    CHECK(lean_sarray_size(a) == 0, "aliased a.size=%zu, expected 0",
          lean_sarray_size(a));
    CHECK(lean_sarray_size(b) == 1, "b.size=%zu, expected 1",
          lean_sarray_size(b));
    CHECK(lean_byte_array_uget(b, 0) == 7, "b[0]=%u, expected 7",
          (unsigned)lean_byte_array_uget(b, 0));
}

/* Probe 4 (bug.txt §463): ByteArray.set! on an aliased array must not
   mutate the original. */
static void test_byte_array_set_aliasing(void) {
    void *a = lean_mk_empty_byte_array(lean_box(8));
    a = lean_byte_array_push(a, 10);
    a = lean_byte_array_push(a, 20);
    a = lean_byte_array_push(a, 30);
    lean_inc_ref(a);                                  /* alias */
    void *b = lean_byte_array_uset(a, 0, 99);

    CHECK(b != a, "byte_array_uset returned the same pointer for an aliased array");
    CHECK(lean_byte_array_uget(a, 0) == 10, "aliased a[0]=%u, expected 10",
          (unsigned)lean_byte_array_uget(a, 0));
    CHECK(lean_byte_array_uget(b, 0) == 99, "b[0]=%u, expected 99",
          (unsigned)lean_byte_array_uget(b, 0));
    CHECK(lean_byte_array_uget(a, 1) == 20, "a[1] mismatch");
    CHECK(lean_byte_array_uget(b, 1) == 20, "b[1] mismatch");
    CHECK(lean_byte_array_uget(a, 2) == 30, "a[2] mismatch");
    CHECK(lean_byte_array_uget(b, 2) == 30, "b[2] mismatch");
}

/* Probe 5: FloatArray.push on an aliased array must not mutate the original. */
static void test_float_array_push_aliasing(void) {
    void *a = lean_mk_empty_float_array(lean_box(4));  /* size 0, cap 4 */
    lean_inc_ref(a);                                   /* alias */
    void *b = lean_float_array_push(a, 1.5);

    CHECK(b != a, "float_array_push returned the same pointer for an aliased array");
    CHECK(lean_sarray_size(a) == 0, "aliased a.size=%zu, expected 0",
          lean_sarray_size(a));
    CHECK(lean_sarray_size(b) == 1, "b.size=%zu, expected 1",
          lean_sarray_size(b));
    CHECK(lean_unbox(lean_float_array_size(b)) == 1,
          "boxed FloatArray.size=%" PRIu64 ", expected 1",
          lean_unbox(lean_float_array_size(b)));
    CHECK(lean_float_array_uget(b, 0) == 1.5, "b[0]=%f, expected 1.5",
          lean_float_array_uget(b, 0));
}

/* Probe 6: FloatArray.set! on an aliased array must not mutate the original. */
static void test_float_array_set_aliasing(void) {
    void *a = lean_mk_empty_float_array(lean_box(8));
    a = lean_float_array_push(a, 1.5);
    a = lean_float_array_push(a, 2.5);
    a = lean_float_array_push(a, 3.5);
    lean_inc_ref(a);                                   /* alias */
    void *b = lean_float_array_uset(a, 1, 9.5);

    CHECK(b != a, "float_array_uset returned the same pointer for an aliased array");
    CHECK(lean_float_array_uget(a, 0) == 1.5, "a[0] mismatch");
    CHECK(lean_float_array_uget(b, 0) == 1.5, "b[0] mismatch");
    CHECK(lean_float_array_uget(a, 1) == 2.5, "aliased a[1]=%f, expected 2.5",
          lean_float_array_uget(a, 1));
    CHECK(lean_float_array_uget(b, 1) == 9.5, "b[1]=%f, expected 9.5",
          lean_float_array_uget(b, 1));
    CHECK(lean_float_array_uget(a, 2) == 3.5, "a[2] mismatch");
    CHECK(lean_float_array_uget(b, 2) == 3.5, "b[2] mismatch");
}

/* Probe 7: FloatArray size APIs must agree with scalar-array raw size and
   the boxed Lean-level size result. */
static void test_float_array_size_abi(void) {
    void *a = lean_mk_empty_float_array(lean_box(2));
    CHECK(lean_sarray_size(a) == 0, "fresh raw size=%zu, expected 0",
          lean_sarray_size(a));
    CHECK(lean_unbox(lean_float_array_size(a)) == 0,
          "fresh boxed size=%" PRIu64 ", expected 0",
          lean_unbox(lean_float_array_size(a)));

    a = lean_float_array_push(a, 4.5);
    a = lean_float_array_push(a, 5.5);
    CHECK(lean_sarray_size(a) == 2, "raw size=%zu, expected 2",
          lean_sarray_size(a));
    CHECK(lean_unbox(lean_float_array_size(a)) == 2,
          "boxed size=%" PRIu64 ", expected 2",
          lean_unbox(lean_float_array_size(a)));
}

/* Probe 8: exclusivity invariant -- `lean_is_exclusive` must be true
   exactly when the object's RC is 1, and false on persistent/scalar
   values. Without this, all of the COW above degenerates. */
static void test_exclusivity_contract(void) {
    void *a = lean_alloc_array(0, 4);
    CHECK(lean_is_exclusive(a), "fresh array should be exclusive (RC=1)");

    lean_inc_ref(a);                  /* RC=2 */
    CHECK(!lean_is_exclusive(a), "RC=2 array reported as exclusive");

    lean_dec_ref(a);                  /* RC=1 */
    CHECK(lean_is_exclusive(a), "RC restored to 1 but not reported exclusive");

    lean_mark_persistent(a);          /* RC=0 (persistent) */
    CHECK(!lean_is_exclusive(a), "persistent array reported as exclusive");

    CHECK(!lean_is_exclusive(lean_box(42)),
          "boxed scalar reported as exclusive");
    CHECK(!lean_is_exclusive(lean_box(0)),
          "boxed zero reported as exclusive");
}

/* Probe 9: an in-place push on an exclusive array MUST mutate in place
   -- otherwise we've regressed to O(n^2) and lost the COW performance
   win that justifies tracking RC at all. */
static void test_exclusive_push_in_place(void) {
    void *a = lean_alloc_array(0, 4);   /* exclusive, spare capacity */
    void *b = lean_array_push(a, lean_box(7));
    CHECK(b == a, "exclusive push with spare capacity should mutate in place "
                  "(got fresh pointer; would be quadratic)");
    CHECK(lean_array_size(a) == 1, "in-place push didn't bump size");
    CHECK(lean_unbox(lean_array_uget_borrowed(a, 0)) == 7,
          "in-place push wrong value");
}

static void dummy_closure_target(void) {}

static void *identity1(void *x) {
    return x;
}

static void *drop2(void *x, void *y) {
    lean_dec(x);
    lean_dec(y);
    return lean_box(0);
}

static void *drop9(void *a1, void *a2, void *a3, void *a4, void *a5,
                   void *a6, void *a7, void *a8, void *a9) {
    lean_dec(a1); lean_dec(a2); lean_dec(a3);
    lean_dec(a4); lean_dec(a5); lean_dec(a6);
    lean_dec(a7); lean_dec(a8); lean_dec(a9);
    return lean_box(0);
}

static void *drop17(void **args) {
    for (unsigned i = 0; i < 17; ++i) lean_dec(args[i]);
    return lean_box(0);
}

static void test_reclaim_array_blocks(void) {
    size_t baseline = lean_freestanding_heap_used_bytes();
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *a = lean_mk_array(lean_box(16), lean_box(i & 0xFF));
        lean_dec(a);
        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "array allocate/drop grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
    CHECK(lean_freestanding_heap_used_bytes() <= warm,
          "array reclamation failed to stabilize heap (baseline=%zu warm=%zu now=%zu)",
          baseline, warm, lean_freestanding_heap_used_bytes());
}

static void test_reclaim_nested_ctor_blocks(void) {
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *child = lean_mk_array(lean_box(8), lean_box(i & 0xFF));
        void *root = lean_alloc_ctor(7, 1, 16);
        lean_ctor_set(root, 0, child);
        lean_dec(root);
        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "nested ctor allocate/drop grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
}

static void test_ctor_release_clears_released_field(void) {
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *child = lean_mk_array(lean_box(8), lean_box(i & 0xFF));
        void *root = lean_alloc_ctor(7, 1, 0);
        lean_ctor_set(root, 0, child);
        lean_ctor_release(root, 0);

        CHECK(lean_ctor_get(root, 0) == lean_box(0),
              "ctor_release left stale field instead of box(0)");

        lean_dec(root);
        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "ctor_release/reset fallback grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
}

static void test_reclaim_string_blocks(void) {
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *s = lean_mk_string("freestanding allocator reuse");
        lean_dec(s);
        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "string allocate/drop grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
}

static void test_reclaim_string_consuming_ops(void) {
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *s = lean_mk_string("abc");
        s = lean_string_push(s, '!');

        void *suffix = lean_mk_string("xyz");
        s = lean_string_append(s, suffix);
        lean_dec(suffix);

        void *chars = lean_string_data(s);
        lean_dec(chars);

        void *bytes = lean_mk_empty_byte_array(lean_box(8));
        bytes = lean_byte_array_push(bytes, 'o');
        bytes = lean_byte_array_push(bytes, 'k');
        void *from_bytes = lean_string_from_utf8_unchecked(bytes);
        lean_dec(from_bytes);

        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "string consuming ops grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
}

static void test_reclaim_closure_blocks(void) {
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *payload = lean_mk_array(lean_box(4), lean_box(i & 0xFF));
        void *closure = lean_alloc_closure((void *)&dummy_closure_target, 1, 1);
        lean_closure_set(closure, 0, payload);
        lean_dec(closure);
        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "closure allocate/drop grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
}

static void test_reclaim_closure_apply_exact(void) {
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *payload = lean_mk_array(lean_box(4), lean_box(i & 0xFF));
        void *closure = lean_alloc_closure((void *)&identity1, 1, 0);
        void *result = lean_apply_1(closure, payload);
        lean_dec(result);

        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "exact closure apply grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
}

static void test_reclaim_closure_apply_partial(void) {
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *x = lean_mk_array(lean_box(4), lean_box(i & 0xFF));
        void *y = lean_mk_string("closure apply payload");
        void *closure = lean_alloc_closure((void *)&drop2, 2, 0);
        void *partial = lean_apply_1(closure, x);
        void *result = lean_apply_1(partial, y);
        CHECK(result == lean_box(0), "partial closure apply returned non-scalar result");

        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "partial closure apply grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
}

static void test_reclaim_closure_apply_shared_fixed(void) {
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *fixed = lean_mk_array(lean_box(4), lean_box(i & 0xFF));
        void *arg = lean_mk_string("shared closure arg");
        void *closure = lean_alloc_closure((void *)&drop2, 2, 1);
        lean_closure_set(closure, 0, fixed);
        lean_inc_ref(closure);

        void *result = lean_apply_1(closure, arg);
        CHECK(result == lean_box(0), "shared fixed closure apply returned non-scalar result");
        lean_dec(closure);

        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "shared fixed closure apply grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
}

static void test_reclaim_scalar_erased_apply_n(void) {
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *args[9];
        for (unsigned j = 0; j < 9; ++j) {
            args[j] = lean_mk_array(lean_box(2), lean_box((i + j) & 0xFF));
        }
        void *result = lean_apply_n(lean_box(0), 9, args);
        CHECK(result == lean_box(0), "scalar erased apply_n returned unexpected result");

        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "scalar erased apply_n grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
}

static void test_reclaim_closure_apply_nine(void) {
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *args[9];
        for (unsigned j = 0; j < 9; ++j) {
            args[j] = lean_mk_array(lean_box(2), lean_box((i + j) & 0xFF));
        }
        void *closure = lean_alloc_closure((void *)&drop9, 9, 0);
        void *result = lean_apply_n(closure, 9, args);
        CHECK(result == lean_box(0), "arity-9 apply_n returned unexpected result");

        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "arity-9 apply_n grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
}

static void test_reclaim_closure_apply_many(void) {
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *args[17];
        for (unsigned j = 0; j < 17; ++j) {
            args[j] = lean_mk_array(lean_box(2), lean_box((i + j) & 0xFF));
        }
        void *closure = lean_alloc_closure((void *)&drop17, 17, 0);
        void *result = lean_apply_m(closure, 17, args);
        CHECK(result == lean_box(0), "arity-17 apply_m returned unexpected result");

        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "arity-17 apply_m grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
}

static void test_live_bytes_return_to_prior_level(void) {
    size_t before = lean_freestanding_heap_live_bytes();
    void *a = lean_mk_array(lean_box(32), lean_box(1));
    void *b = lean_mk_string("temporary live object");
    lean_dec(a);
    lean_dec(b);
    CHECK(lean_freestanding_heap_live_bytes() == before,
          "live bytes after dec=%zu, expected prior level %zu",
          lean_freestanding_heap_live_bytes(), before);
}

static void test_pointer_address_and_mix_hash(void) {
    void *a = lean_mk_array(lean_box(2), lean_box(11));
    CHECK(lean_ptr_addr(a) == (size_t)a,
          "lean_ptr_addr(heap)=%zu, expected %zu", lean_ptr_addr(a), (size_t)a);
    CHECK(lean_ptr_addr(lean_box(42)) == (size_t)lean_box(42),
          "lean_ptr_addr(scalar)=%zu, expected %zu",
          lean_ptr_addr(lean_box(42)), (size_t)lean_box(42));
    lean_dec(a);

    CHECK(lean_uint64_mix_hash(0, 0) == UINT64_C(0x35a98f4d286a90b9),
          "mixHash(0,0)=0x%016" PRIx64,
          lean_uint64_mix_hash(0, 0));
    CHECK(lean_uint64_mix_hash(7, 11) == UINT64_C(0xc5121aeed2cb5fcf),
          "mixHash(7,11)=0x%016" PRIx64,
          lean_uint64_mix_hash(7, 11));
    CHECK(lean_uint64_mix_hash(UINT64_C(0x123456789abcdef0),
                               UINT64_C(0xfedcba9876543210)) ==
          UINT64_C(0x90e3d58779296ab7),
          "mixHash(large)=0x%016" PRIx64,
          lean_uint64_mix_hash(UINT64_C(0x123456789abcdef0),
                               UINT64_C(0xfedcba9876543210)));
}

static void test_st_ref_basic_and_reclaim(void) {
    size_t warm = 0;
    for (unsigned i = 0; i < 128; ++i) {
        void *initial = lean_mk_array(lean_box(2), lean_box(i & 0xFF));
        void *ref = lean_st_mk_ref(initial);

        void *same = lean_st_ref_get(ref);
        CHECK(same == initial, "Ref.get returned a different object");
        lean_dec(same);

        void *replacement = lean_mk_string("ref replacement");
        void *old = lean_st_ref_swap(ref, replacement);
        CHECK(old == initial, "Ref.swap did not return the old value");
        lean_dec(old);

        void *again = lean_st_ref_get(ref);
        CHECK(again == replacement, "Ref.get did not see swapped value");
        lean_dec(again);

        void *taken = lean_st_ref_take(ref);
        CHECK(taken == replacement, "Ref.take did not return current value");
        lean_dec(taken);

        CHECK(lean_st_ref_set(ref, lean_box(0)) == lean_box(0),
              "Ref.set did not return Unit");

        void *other = lean_st_mk_ref(lean_box(0));
        CHECK(lean_st_ref_ptr_eq(ref, ref), "Ref.ptrEq false for same ref");
        CHECK(!lean_st_ref_ptr_eq(ref, other), "Ref.ptrEq true for distinct refs");
        lean_dec(other);
        lean_dec(ref);

        size_t used = lean_freestanding_heap_used_bytes();
        if (i == 0) warm = used;
        CHECK(used == warm, "ST.Ref cycle grew heap from %zu to %zu at iteration %u",
              warm, used, i);
    }
}

static void test_bounded_int_arithmetic(void) {
    void *i5 = lean_nat_to_int(lean_box(5));
    void *neg3 = lean_int_neg_succ_of_nat(lean_box(2));
    CHECK(scalar_int_value(i5) == 5, "Nat.toInt(5) mismatch");
    CHECK(scalar_int_value(neg3) == -3, "Int.negSucc 2 mismatch");

    CHECK(scalar_int_value(lean_int_neg(i5)) == -5, "Int.neg mismatch");
    CHECK(scalar_int_value(lean_int_add(i5, neg3)) == 2, "Int.add mismatch");
    CHECK(scalar_int_value(lean_int_sub(neg3, i5)) == -8, "Int.sub mismatch");
    CHECK(scalar_int_value(lean_int_mul(i5, neg3)) == -15, "Int.mul mismatch");

    void *neg7 = lean_cstr_to_int("-7");
    void *i3 = lean_cstr_to_int("3");
    CHECK(scalar_int_value(neg7) == -7, "cstr_to_int(-7) mismatch");
    CHECK(scalar_int_value(lean_int_div(neg7, i3)) == -2, "Int.tdiv mismatch");
    CHECK(scalar_int_value(lean_int_mod(neg7, i3)) == -1, "Int.tmod mismatch");
    CHECK(scalar_int_value(lean_int_ediv(neg7, i3)) == -3, "Int.ediv mismatch");
    CHECK(scalar_int_value(lean_int_emod(neg7, i3)) == 2, "Int.emod mismatch");

    CHECK(lean_int_dec_eq(i5, lean_cstr_to_int("5")), "Int.decEq false for equal values");
    CHECK(!lean_int_dec_eq(i5, neg3), "Int.decEq true for distinct values");
    CHECK(lean_int_dec_nonneg(i5), "Int.decNonneg false for positive value");
    CHECK(!lean_int_dec_nonneg(neg3), "Int.decNonneg true for negative value");
    CHECK(lean_int_dec_le(neg3, i5), "Int.decLe false for -3 <= 5");
    CHECK(lean_int_dec_lt(neg3, i5), "Int.decLt false for -3 < 5");
    CHECK(scalar_int_value(lean_nat_abs(neg3)) == 3, "Int.natAbs mismatch");
}

int main(void) {
    test_array_push_aliasing();
    test_array_set_aliasing();
    test_byte_array_push_aliasing();
    test_byte_array_set_aliasing();
    test_float_array_push_aliasing();
    test_float_array_set_aliasing();
    test_float_array_size_abi();
    test_exclusivity_contract();
    test_exclusive_push_in_place();
    test_reclaim_array_blocks();
    test_reclaim_nested_ctor_blocks();
    test_ctor_release_clears_released_field();
    test_reclaim_string_blocks();
    test_reclaim_string_consuming_ops();
    test_reclaim_closure_blocks();
    test_reclaim_closure_apply_exact();
    test_reclaim_closure_apply_partial();
    test_reclaim_closure_apply_shared_fixed();
    test_reclaim_scalar_erased_apply_n();
    test_reclaim_closure_apply_nine();
    test_reclaim_closure_apply_many();
    test_live_bytes_return_to_prior_level();
    test_pointer_address_and_mix_hash();
    test_st_ref_basic_and_reclaim();
    test_bounded_int_arithmetic();

    if (g_failed) {
        fprintf(stderr, "FAIL: freestanding runtime COW harness\n");
        return 1;
    }
    printf("PASS: freestanding runtime COW + reclamation harness (25 probes)\n");
    return 0;
}
