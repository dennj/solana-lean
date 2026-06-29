/*
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Solana-specific Lean runtime additions for the SBF cross-compile target:
the typed entrypoint deserialiser, the `Std.Solana.msg` log forwarder,
cross-program invocation marshaling, PDA derivation, and mutable
account-state mutators.

The freestanding subset (object layout, bump allocator, refcount no-ops,
boxing, ctors, IO results, strings, arrays, byte arrays, bounded `Nat`)
lives in `src/runtime/freestanding/runtime.c`. This file imports it via
extern declarations and provides the embedder hooks the freestanding
runtime expects (`lean_freestanding_panic`, `lean_freestanding_log`)
by forwarding to the Solana `sol_panic_` / `sol_log_` syscalls.
*/

#include <stdint.h>
#include <stddef.h>

extern void sol_log_(const char *, uint64_t);
extern void sol_panic_(const char *, uint64_t, uint64_t, uint64_t);

/* ===========================================================================
   Embedder hooks for the freestanding runtime
   =========================================================================*/

extern uint64_t lean_strlen(const char *s);

void lean_freestanding_log(const char *msg, uint64_t len) {
    sol_log_(msg, len);
}

void lean_freestanding_panic(const char *what, uint64_t a, uint64_t b) {
    sol_panic_(what, lean_strlen(what), a, b);
    __builtin_unreachable();
}

/* ===========================================================================
   Compiler-rt helpers required by Solana LLVM
   =========================================================================*/

typedef unsigned __int128 lean_sbf_du_int;
typedef __int128 lean_sbf_ti_int;

static uint64_t lean_sbf_mul64_high(uint64_t a, uint64_t b) {
    uint64_t a0 = (uint32_t)a;
    uint64_t a1 = a >> 32;
    uint64_t b0 = (uint32_t)b;
    uint64_t b1 = b >> 32;
    uint64_t p0 = a0 * b0;
    uint64_t p1 = a0 * b1;
    uint64_t p2 = a1 * b0;
    uint64_t p3 = a1 * b1;
    uint64_t mid = (p0 >> 32) + (uint32_t)p1 + (uint32_t)p2;
    return p3 + (p1 >> 32) + (p2 >> 32) + (mid >> 32);
}

lean_sbf_ti_int __multi3(lean_sbf_ti_int aa, lean_sbf_ti_int bb) {
    lean_sbf_du_int a = (lean_sbf_du_int)aa;
    lean_sbf_du_int b = (lean_sbf_du_int)bb;
    uint64_t al = (uint64_t)a;
    uint64_t ah = (uint64_t)(a >> 64);
    uint64_t bl = (uint64_t)b;
    uint64_t bh = (uint64_t)(b >> 64);
    uint64_t lo = al * bl;
    uint64_t hi = lean_sbf_mul64_high(al, bl) + al * bh + ah * bl;
    return (lean_sbf_ti_int)(((lean_sbf_du_int)hi << 64) | lo);
}

/* ===========================================================================
   Lean object layout (mirrors the freestanding runtime's typedefs)
   =========================================================================*/

typedef struct {
    int      m_rc;
    unsigned m_cs_sz:16;
    unsigned m_other:8;
    unsigned m_tag:8;
} lean_object;

typedef struct {
    lean_object   m_header;
    lean_object * m_objs[];
} lean_ctor_object;

typedef struct {
    lean_object m_header;
    size_t      m_size;
    size_t      m_capacity;
    size_t      m_length;
    char        m_data[];
} lean_string_object;

typedef struct {
    lean_object   m_header;
    size_t        m_size;
    size_t        m_capacity;
    lean_object * m_data[];
} lean_array_object;

typedef struct {
    lean_object m_header;
    size_t      m_size;
    size_t      m_capacity;
    uint8_t     m_data[];
} lean_sarray_object;

/* ===========================================================================
   Freestanding runtime exports we reuse
   =========================================================================*/

extern void *bump_alloc(size_t size);
extern void *lean_box(size_t n);
extern uint64_t lean_unbox(void *o);
extern void *lean_alloc_ctor(unsigned tag, unsigned num_objs, unsigned scalar_sz);
extern void *lean_ctor_get(void *o, unsigned i);
extern void  lean_ctor_set(void *o, unsigned i, void *v);
extern void *lean_array_push(void *a, void *v);
extern void *lean_mk_empty_array_with_capacity(void *capacity_box);
extern void *lean_freestanding_make_byte_array(const uint8_t *data, size_t len);

/* ===========================================================================
   Heap-prefix metadata: SBF-specific slots
   ===========================================================================
   The freestanding bump allocator reserves the first `LEAN_FREESTANDING_HEAP_PREFIX`
   bytes of the heap; bytes [0..8) hold the bump cursor. The SBF embedder
   reserves an additional 16 bytes (PREFIX = 24) for two pointers used by
   the typed-entrypoint deserialiser and the CPI / mutator runtime:

     [8..16)  raw_input_ptr     (set by make_program_context, read by invoke
                                 and by the account-mutator helpers)
     [16..24) account_table_ptr (set by make_program_context, read by mutators)

   Solana zero-initialises the heap on every program invocation, so any
   "not yet populated" state is observable as zero.
*/

#define LEAN_SBF_HEAP_START 0x300000000UL

static uintptr_t *raw_input_storage(void) {
    return (uintptr_t *)(LEAN_SBF_HEAP_START + sizeof(uintptr_t));
}

static uintptr_t *account_table_storage(void) {
    return (uintptr_t *)(LEAN_SBF_HEAP_START + 2 * sizeof(uintptr_t));
}

/*
 * One entry per account, populated by make_program_context. Pointers
 * reference back into the loader buffer (stable for the program's
 * lifetime). The packed `data_len_and_writable` field stores
 * `(is_writable << 56) | data_len`; data_len is bounded by Solana's
 * MAX_PERMITTED_DATA_LEN (10 MB) so 56 bits is comfortably enough.
 */
typedef struct {
    uint64_t *lamports_ptr;
    uint8_t  *data_ptr;
    uint64_t  data_len_and_writable;
} LeanSbfAccountSlot;

#define LEAN_SBF_SLOT_DATA_LEN(s) ((s)->data_len_and_writable & 0x00FFFFFFFFFFFFFFULL)
#define LEAN_SBF_SLOT_WRITABLE(s) (((s)->data_len_and_writable >> 56) & 1u)
#define LEAN_SBF_SLOT_PACK(len, writable) (((uint64_t)((writable) ? 1 : 0) << 56) | ((len) & 0x00FFFFFFFFFFFFFFULL))

/* ===========================================================================
   Module initialiser: Std.Solana
   ===========================================================================
   `Std.Solana` exists as a stdlib module on the host but its body is
   either pure Lean (inlined into user code via `@[inline, expose]`) or
   `@[extern]` opaques (provided by this runtime). The module init has
   no host-side state that is meaningful on SBF, so we ship it as a
   no-op success — same shape as `initialize_Init` in the freestanding
   runtime.
*/

extern void *lean_io_result_mk_ok(void *value);

void *initialize_Std_Solana(uint8_t builtin, void *world) {
    (void)builtin; (void)world;
    return lean_io_result_mk_ok(lean_box(0));
}

/* ===========================================================================
   Typed entrypoint deserialiser
   ===========================================================================
   Parses the Solana loader's input buffer into a `Std.Solana.ProgramContext`
   value (a Lean ctor with three fields: accounts, data, programId).

   Buffer layout (mirrors SBF deserialize.h):
     u64 ka_num
     repeat ka_num:
       u8  dup_info
       if dup_info != 0xFF: 7 bytes padding (this is a duplicate ref)
       else: full account record:
         u8 is_signer, u8 is_writable, u8 executable, 4 bytes pad,
         32 bytes pubkey, 32 bytes owner, 8 bytes lamports,
         8 bytes data_len, data_len bytes data,
         MAX_PERMITTED_DATA_INCREASE (10240) bytes realloc-pad,
         padding to 8-align, 8 bytes rent_epoch
     u64 instruction_data_len
     instruction_data_len bytes instruction_data
     32 bytes program_id
*/

#define LEAN_SBF_MAX_PERMITTED_DATA_INCREASE (1024 * 10)

/* Build a Lean `Std.Solana.Pubkey` from 32 raw bytes.

   `Pubkey` is a single-field structure (`bytes : ByteArray` plus the erased
   `size_eq` proof), so the compiler treats it as a *trivial structure* and
   unboxes it: a `Pubkey` value has the same runtime representation as its
   `ByteArray` field, and `Pubkey.bytes`/`toBytes` compile to the identity.
   The runtime must therefore store a `Pubkey` as the bare 32-byte ByteArray —
   NOT wrapped in an explicit ctor. Wrapping makes `a.key.toBytes[i]` read the
   ctor header as if it were ByteArray payload and return garbage. */
static void *lean_sbf_make_pubkey_bytes(const uint8_t *bytes) {
    return lean_freestanding_make_byte_array(bytes, 32);
}

/* Build a Lean `Std.Solana.AccountInfo` ctor from a parsed account record.
   The structure has 8 fields: key, owner, lamports, data, rentEpoch,
   isSigner, isWritable, executable. We pack the layout to match Lean's
   default ordering for `structure AccountInfo where ...` (alphabetical
   for explicit ctor or source order; Lean uses source order). */
static void *lean_sbf_make_account_info(
    const uint8_t *key,
    const uint8_t *owner,
    uint64_t lamports,
    const uint8_t *data, uint64_t data_len,
    uint64_t rent_epoch,
    uint8_t is_signer,
    uint8_t is_writable,
    uint8_t executable
) {
    /* `structure AccountInfo where key owner lamports data rentEpoch
       isSigner isWritable executable`. Bool fields each occupy a UInt8
       in the runtime; per Lean's emit convention they sit in the
       scalar tail of the ctor. obj-fields = key, owner, data; scalar
       area = lamports (8), rentEpoch (8), isSigner (1), isWritable (1),
       executable (1) = 19 bytes. `key`/`owner` are unboxed Pubkeys, i.e.
       the bare 32-byte ByteArray (see `lean_sbf_make_pubkey_bytes`). */
    void *acc = lean_alloc_ctor(0, /* num_objs = */ 3, /* scalar_sz = */ 8 + 8 + 1 + 1 + 1);
    lean_ctor_set(acc, 0, lean_sbf_make_pubkey_bytes(key));
    lean_ctor_set(acc, 1, lean_sbf_make_pubkey_bytes(owner));
    lean_ctor_set(acc, 2, lean_freestanding_make_byte_array(data, data_len));
    /* Scalar tail: write lamports, rentEpoch, then the three bools. */
    char *scalar_tail = (char *)acc + sizeof(lean_ctor_object) + 3 * sizeof(void *);
    *(uint64_t *)(scalar_tail + 0)  = lamports;
    *(uint64_t *)(scalar_tail + 8)  = rent_epoch;
    *(uint8_t  *)(scalar_tail + 16) = is_signer;
    *(uint8_t  *)(scalar_tail + 17) = is_writable;
    *(uint8_t  *)(scalar_tail + 18) = executable;
    return acc;
}

/*
Parse the loader's input buffer into a `Std.Solana.ProgramContext` ctor.
Layout: 3 obj fields (accounts, data, programId), 0 scalar bytes.

Side effects:
 - Stashes the raw input pointer in the heap prefix so the CPI
   runtime (`lean_sbf_invoke_signed`) can find it later.
 - Allocates and populates the account-pointer table in the heap
   prefix so the account-data mutators can locate each account's
   loader-buffer position in O(1).
*/
void *lean_sbf_make_program_context(const uint8_t *input) {
    *raw_input_storage() = (uintptr_t)input;
    uint64_t ka_num = *(const uint64_t *)input;
    input += 8;
    /* Allocate the account-pointer table in the bump heap. */
    LeanSbfAccountSlot *acct_table = (LeanSbfAccountSlot *)bump_alloc(
        sizeof(LeanSbfAccountSlot) * (ka_num == 0 ? 1 : ka_num));
    *account_table_storage() = (uintptr_t)acct_table;

    /* First pass: build the AccountInfo[] array with the exact final
       capacity. Duplicate accounts (dup_info != 0xFF) reuse a previously-
       built AccountInfo. The `prev` lookup table sits on the bump heap
       (sized to `ka_num`) rather than the stack so it doesn't compete
       with the SBF 4 KB stack budget. */
    void *accounts_array = lean_mk_empty_array_with_capacity(lean_box(ka_num));
    void **prev = (void **)bump_alloc(sizeof(void *) * (ka_num == 0 ? 1 : ka_num));
    uint64_t built = 0;
    for (uint64_t i = 0; i < ka_num; ++i) {
        uint8_t dup_info = *input++;
        if (dup_info != 0xFFu) {
            input += 7;
            void *dup = (dup_info < built) ? prev[dup_info] : prev[0];
            accounts_array = lean_array_push(accounts_array, dup);
            if (dup_info < i) acct_table[i] = acct_table[dup_info];
            prev[built++] = dup;
            continue;
        }
        uint8_t is_signer   = *input++;
        uint8_t is_writable = *input++;
        uint8_t executable  = *input++;
        input += 4; /* padding */
        const uint8_t *key = input;   input += 32;
        const uint8_t *owner = input; input += 32;
        uint64_t *lamports_ptr = (uint64_t *)input;
        uint64_t lamports = *lamports_ptr; input += 8;
        uint64_t data_len = *(const uint64_t *)input; input += 8;
        const uint8_t *data = input;  input += data_len;
        input += LEAN_SBF_MAX_PERMITTED_DATA_INCREASE;
        input = (const uint8_t *)(((uintptr_t)input + 7u) & ~(uintptr_t)7u);
        uint64_t rent_epoch = *(const uint64_t *)input; input += 8;

        acct_table[i].lamports_ptr = lamports_ptr;
        acct_table[i].data_ptr     = (uint8_t *)data;
        acct_table[i].data_len_and_writable = LEAN_SBF_SLOT_PACK(data_len, is_writable);

        void *acc = lean_sbf_make_account_info(
            key, owner, lamports, data, data_len, rent_epoch,
            is_signer, is_writable, executable);
        accounts_array = lean_array_push(accounts_array, acc);
        prev[built++] = acc;
    }

    uint64_t inst_len = *(const uint64_t *)input;
    input += 8;
    void *inst_data = lean_freestanding_make_byte_array(input, inst_len);
    input += inst_len;

    /* program_id: 32 bytes at the end. Stored as an unboxed Pubkey. */
    void *prog_pubkey = lean_sbf_make_pubkey_bytes(input);

    /* Build ProgramContext = ctor with 3 obj fields. */
    void *ctx = lean_alloc_ctor(0, 3, 0);
    lean_ctor_set(ctx, 0, accounts_array);
    lean_ctor_set(ctx, 1, inst_data);
    lean_ctor_set(ctx, 2, prog_pubkey);
    return ctx;
}

/* ===========================================================================
   Std.Solana.msg
   ===========================================================================
   Forward a Lean `String` to the Solana `sol_log_` syscall. The string's
   payload bytes are passed directly; `m_size - 1` strips the trailing
   `'\0'` that Lean keeps inside the buffer for C-string compatibility.
*/

void *lean_sol_log(void *s) {
    lean_string_object *str = (lean_string_object *)s;
    /* Lean keeps strings NUL-terminated; m_size includes the terminator. */
    uint64_t bytes = str->m_size > 0 ? str->m_size - 1 : 0;
    sol_log_(str->m_data, bytes);
    return lean_box(0); /* Unit */
}

/* ===========================================================================
   Cross-program invocation
   ===========================================================================
   `Std.Solana.invokeSignedImpl` forwards to the SBF `sol_invoke_signed_c`
   syscall. The runtime here marshals the Lean structures
   (`Std.Solana.Instruction`, `Array AccountMeta`, `ByteArray` payload,
   PDA signer seeds) into the C structs the syscall expects, then
   reconstructs the `SolAccountInfo[]` array from the loader's input
   buffer (whose pointer was stashed by `lean_sbf_make_program_context`).
*/

#define LEAN_SBF_PUBKEY_BYTES 32

typedef struct {
    uint8_t *pubkey;       /* 32 bytes */
    uint8_t  is_signer;
    uint8_t  is_writable;
} SolAccountMeta;

typedef struct {
    uint8_t  *program_id;
    SolAccountMeta *accounts;
    uint64_t  account_len;
    uint8_t  *data;
    uint64_t  data_len;
} SolInstruction;

typedef struct {
    uint8_t  *key;        /* 32 bytes */
    uint64_t *lamports;
    uint64_t  data_len;
    uint8_t  *data;
    uint8_t  *owner;      /* 32 bytes */
    uint64_t  rent_epoch;
    uint8_t   is_signer;
    uint8_t   is_writable;
    uint8_t   executable;
} SolAccountInfo;

typedef struct {
    const uint8_t *addr;
    uint64_t       len;
} SolSignerSeed;

typedef struct {
    const SolSignerSeed *addr;
    uint64_t             len;
} SolSignerSeeds;

extern uint64_t sol_invoke_signed_c(
    const SolInstruction *instruction,
    const SolAccountInfo *account_infos,
    uint64_t              account_infos_len,
    const SolSignerSeeds *signers_seeds,
    uint64_t              signers_seeds_len);

/* Reconstruct a `SolAccountInfo` array from the original loader input.
   Pointers in the resulting structs reference back into the loader
   buffer, so they remain valid for the program's lifetime — exactly
   what the CPI syscall expects. */
static uint64_t lean_sbf_build_account_infos(
    const uint8_t *input, SolAccountInfo *out, uint64_t out_cap)
{
    uint64_t ka_num = *(const uint64_t *)input;
    input += 8;
    if (ka_num > out_cap) ka_num = out_cap;
    for (uint64_t i = 0; i < ka_num; ++i) {
        uint8_t dup_info = *input++;
        if (dup_info != 0xFFu) {
            input += 7;
            if (dup_info < i) out[i] = out[dup_info];
            continue;
        }
        out[i].is_signer   = *input++;
        out[i].is_writable = *input++;
        out[i].executable  = *input++;
        input += 4;
        out[i].key   = (uint8_t *)input; input += 32;
        out[i].owner = (uint8_t *)input; input += 32;
        out[i].lamports = (uint64_t *)input; input += 8;
        out[i].data_len = *(const uint64_t *)input; input += 8;
        out[i].data = (uint8_t *)input;
        input += out[i].data_len + LEAN_SBF_MAX_PERMITTED_DATA_INCREASE;
        input = (const uint8_t *)(((uintptr_t)input + 7u) & ~(uintptr_t)7u);
        out[i].rent_epoch = *(const uint64_t *)input;
        input += 8;
    }
    return ka_num;
}

/* Marshal a Lean `Std.Solana.Instruction` (3 obj fields: programId,
   accounts, data) into a heap-allocated `SolInstruction` plus an array
   of `SolAccountMeta`. `Pubkey` is an unboxed trivial structure, so a
   `Pubkey`-typed field IS the 32-byte ByteArray directly — no inner
   ctor projection (see `lean_sbf_make_pubkey_bytes`). */
static SolInstruction *lean_sbf_marshal_instruction(void *inst_obj,
                                                    SolAccountMeta **out_metas)
{
    void *prog_pubkey  = lean_ctor_get(inst_obj, 0);
    void *accounts_arr = lean_ctor_get(inst_obj, 1);
    void *data_bytes   = lean_ctor_get(inst_obj, 2);

    /* programId is the unboxed Pubkey, i.e. the 32-byte ByteArray itself. */
    lean_sarray_object *prog_sa = (lean_sarray_object *)prog_pubkey;

    /* accounts is an `Array AccountMeta`; AccountMeta = { pubkey,
       isWritable, isSigner } — Pubkey field then a 2-byte scalar
       tail (two Bool / UInt8). */
    lean_array_object *acc_arr = (lean_array_object *)accounts_arr;
    uint64_t n_accounts = acc_arr->m_size;
    SolAccountMeta *metas = (SolAccountMeta *)bump_alloc(sizeof(SolAccountMeta) * n_accounts);
    for (uint64_t i = 0; i < n_accounts; ++i) {
        void *meta = acc_arr->m_data[i];
        lean_sarray_object *pk_sa = (lean_sarray_object *)lean_ctor_get(meta, 0);
        char *scalar_tail = (char *)meta + sizeof(lean_ctor_object) + 1 * sizeof(void *);
        metas[i].pubkey      = pk_sa->m_data;
        metas[i].is_writable = *(uint8_t *)(scalar_tail + 0);
        metas[i].is_signer   = *(uint8_t *)(scalar_tail + 1);
    }
    *out_metas = metas;

    lean_sarray_object *data_sa = (lean_sarray_object *)data_bytes;

    SolInstruction *si = (SolInstruction *)bump_alloc(sizeof(SolInstruction));
    si->program_id  = prog_sa->m_data;
    si->accounts    = metas;
    si->account_len = n_accounts;
    si->data        = data_sa->m_data;
    si->data_len    = data_sa->m_size;
    return si;
}

/* Marshal a Lean `Array (Array ByteArray)` into a heap-allocated
   `SolSignerSeeds` array. */
static SolSignerSeeds *lean_sbf_marshal_signers(void *signers_arr_obj,
                                                uint64_t *out_count)
{
    lean_array_object *outer = (lean_array_object *)signers_arr_obj;
    *out_count = outer->m_size;
    if (outer->m_size == 0) return NULL;
    SolSignerSeeds *seeds = (SolSignerSeeds *)bump_alloc(sizeof(SolSignerSeeds) * outer->m_size);
    for (uint64_t i = 0; i < outer->m_size; ++i) {
        lean_array_object *inner = (lean_array_object *)outer->m_data[i];
        SolSignerSeed *parts = (SolSignerSeed *)bump_alloc(sizeof(SolSignerSeed) * inner->m_size);
        for (uint64_t j = 0; j < inner->m_size; ++j) {
            lean_sarray_object *seg = (lean_sarray_object *)inner->m_data[j];
            parts[j].addr = seg->m_data;
            parts[j].len  = seg->m_size;
        }
        seeds[i].addr = parts;
        seeds[i].len  = inner->m_size;
    }
    return seeds;
}

void *lean_sbf_invoke_signed(void *instruction, void *signers) {
    /* Read the loader's raw input pointer stashed by
       `lean_sbf_make_program_context`. If the program never built a
       `ProgramContext` we have no account_infos to forward — surface
       that as a clean panic rather than a CPI with empty accounts. */
    uintptr_t raw = *raw_input_storage();
    if (raw == 0) {
        const char *m = "lean-sbf: invoke called before ProgramContext was built";
        sol_log_(m, lean_strlen(m));
        sol_panic_("invoke_no_ctx", 13, 0, 0);
        __builtin_unreachable();
    }

    /* Build the loader's account_infos array on the bump heap, not the
       stack: SBF gives functions a 4 KB stack budget, and `SolAccountInfo`
       at ~64 B/entry × 256 entries would overflow it (~16 KB) and cause
       undefined behaviour at runtime even though the .so still links. We
       size the buffer dynamically off the loader's `ka_num` so small
       programs don't pay for the worst case. */
    uint64_t ka_num_hint = *(const uint64_t *)raw;
    if (ka_num_hint == 0) ka_num_hint = 1;
    SolAccountInfo *infos = (SolAccountInfo *)bump_alloc(
        sizeof(SolAccountInfo) * ka_num_hint);
    uint64_t infos_len = lean_sbf_build_account_infos(
        (const uint8_t *)raw, infos, ka_num_hint);

    /* Marshal Instruction + signers. */
    SolAccountMeta *metas = NULL;
    SolInstruction *inst = lean_sbf_marshal_instruction(instruction, &metas);
    uint64_t signers_len = 0;
    SolSignerSeeds *seeds = lean_sbf_marshal_signers(signers, &signers_len);

    uint64_t status = sol_invoke_signed_c(inst, infos, infos_len, seeds, signers_len);
    if (status != 0) {
        const char *m = "lean-sbf: CPI returned non-zero status";
        sol_log_(m, lean_strlen(m));
        sol_panic_("cpi_failed", 10, status, 0);
        __builtin_unreachable();
    }
    return lean_box(0);
}

/* ===========================================================================
   PDA derivation
   =========================================================================*/

extern uint64_t sol_try_find_program_address(
    const SolSignerSeed *seeds,
    int                  seeds_len,
    const uint8_t       *program_id,
    uint8_t             *program_address,
    uint8_t             *bump_seed);

extern uint64_t sol_create_program_address(
    const SolSignerSeed *seeds,
    int                  seeds_len,
    const uint8_t       *program_id,
    uint8_t             *program_address);

/* Marshal `Array ByteArray` (the seeds list) into a heap-allocated
   `SolSignerSeed[]`. Each element references the underlying ByteArray's
   m_data — the seeds array must outlive the syscall, which is fine since
   the caller holds a Lean reference. */
static SolSignerSeed *lean_sbf_marshal_seeds(void *seeds_obj, uint64_t *out_count) {
    lean_array_object *arr = (lean_array_object *)seeds_obj;
    *out_count = arr->m_size;
    if (arr->m_size == 0) return NULL;
    SolSignerSeed *out = (SolSignerSeed *)bump_alloc(sizeof(SolSignerSeed) * arr->m_size);
    for (uint64_t i = 0; i < arr->m_size; ++i) {
        lean_sarray_object *seg = (lean_sarray_object *)arr->m_data[i];
        out[i].addr = seg->m_data;
        out[i].len  = seg->m_size;
    }
    return out;
}

/* Build an `Option (Pubkey × UInt8)`. Pubkey × UInt8 = ctor tag=0,
   num_objs=1 (Pubkey), scalar_sz=1 (UInt8). The Pubkey field is the
   unboxed 32-byte ByteArray. */
static void *lean_sbf_some_pubkey_bump(void *pk, uint8_t bump) {
    void *pair = lean_alloc_ctor(0, 1, 1);
    lean_ctor_set(pair, 0, pk);
    char *scalar_tail = (char *)pair + sizeof(lean_ctor_object) + sizeof(void *);
    *(uint8_t *)scalar_tail = bump;
    void *some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, pair);
    return some;
}

static void *lean_sbf_some_pubkey(void *pk) {
    void *some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, pk);
    return some;
}

void *lean_sbf_find_program_address(void *seeds_obj, void *program_id_obj) {
    uint64_t seeds_len = 0;
    SolSignerSeed *seeds = lean_sbf_marshal_seeds(seeds_obj, &seeds_len);
    /* program_id_obj is the unboxed Pubkey, i.e. the 32-byte ByteArray. */
    lean_sarray_object *pid_sa = (lean_sarray_object *)program_id_obj;
    uint8_t out_addr[32];
    uint8_t bump = 0;
    uint64_t rc = sol_try_find_program_address(
        seeds, (int)seeds_len, pid_sa->m_data, out_addr, &bump);
    if (rc != 0) return lean_box(0); /* Option.none */
    return lean_sbf_some_pubkey_bump(lean_sbf_make_pubkey_bytes(out_addr), bump);
}

void *lean_sbf_create_program_address(void *seeds_obj, void *program_id_obj) {
    uint64_t seeds_len = 0;
    SolSignerSeed *seeds = lean_sbf_marshal_seeds(seeds_obj, &seeds_len);
    /* program_id_obj is the unboxed Pubkey, i.e. the 32-byte ByteArray. */
    lean_sarray_object *pid_sa = (lean_sarray_object *)program_id_obj;
    uint8_t out_addr[32];
    uint64_t rc = sol_create_program_address(
        seeds, (int)seeds_len, pid_sa->m_data, out_addr);
    if (rc != 0) return lean_box(0); /* Option.none — on-curve */
    return lean_sbf_some_pubkey(lean_sbf_make_pubkey_bytes(out_addr));
}

/* ===========================================================================
   Sysvars
   =========================================================================*/

extern uint64_t sol_get_clock_sysvar(uint8_t *clock_addr);

static void *lean_sbf_some_bytearray(void *bytes) {
    void *some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, bytes);
    return some;
}

void *lean_sbf_get_clock_sysvar(uint64_t nonce) {
    (void)nonce;
    uint8_t clock[40];
    uint64_t rc = sol_get_clock_sysvar(clock);
    if (rc != 0) return lean_box(0); /* Option.none */
    return lean_sbf_some_bytearray(lean_freestanding_make_byte_array(clock, sizeof(clock)));
}

/* ===========================================================================
   Mutable account state
   ===========================================================================
   Writes targeting account[i].data and account[i].lamports propagate back
   into the loader buffer (whose pointers we cached during
   make_program_context). The Solana validator reads the buffer at
   program exit and persists the changes to the chain.

   All mutators perform bounds checks plus an `is_writable` check
   (the loader rejects writes to non-writable accounts; we fail-fast
   with a Lean-shaped panic for a clearer error).
*/

static LeanSbfAccountSlot *lean_sbf_resolve_slot(uint64_t idx, const char *what) {
    uintptr_t table = *account_table_storage();
    if (table == 0) {
        const char *m = "lean-sbf: account mutator called before ProgramContext was built";
        sol_log_(m, lean_strlen(m));
        sol_panic_(what, lean_strlen(what), 0, 0);
        __builtin_unreachable();
    }
    /* The table sits at the front of the bump heap; the loader's
       ka_num bound (re-read from the raw input) is our authoritative
       length. We read it lazily here so we don't need to cache it. */
    uintptr_t raw = *raw_input_storage();
    uint64_t ka_num = *(const uint64_t *)raw;
    if (idx >= ka_num) {
        const char *m = "lean-sbf: account index out of range";
        sol_log_(m, lean_strlen(m));
        sol_panic_(what, lean_strlen(what), idx, ka_num);
        __builtin_unreachable();
    }
    return ((LeanSbfAccountSlot *)table) + idx;
}

uint64_t lean_sbf_get_lamports(uint64_t idx) {
    LeanSbfAccountSlot *slot = lean_sbf_resolve_slot(idx, "get_lamports");
    return *slot->lamports_ptr;
}

void *lean_sbf_set_lamports(uint64_t idx, uint64_t value) {
    LeanSbfAccountSlot *slot = lean_sbf_resolve_slot(idx, "set_lamports");
    if (!LEAN_SBF_SLOT_WRITABLE(slot)) {
        const char *m = "lean-sbf: set_lamports on non-writable account";
        sol_log_(m, lean_strlen(m));
        sol_panic_("set_lamports", 12, idx, 0);
        __builtin_unreachable();
    }
    *slot->lamports_ptr = value;
    return lean_box(0); /* Unit */
}

uint8_t lean_sbf_get_data_byte(uint64_t idx, uint64_t offset) {
    LeanSbfAccountSlot *slot = lean_sbf_resolve_slot(idx, "get_data_byte");
    uint64_t len = LEAN_SBF_SLOT_DATA_LEN(slot);
    if (offset >= len) {
        const char *m = "lean-sbf: get_data_byte offset out of range";
        sol_log_(m, lean_strlen(m));
        sol_panic_("get_data_byte", 13, offset, len);
        __builtin_unreachable();
    }
    return slot->data_ptr[offset];
}

void *lean_sbf_set_data_byte(uint64_t idx, uint64_t offset, uint8_t value) {
    LeanSbfAccountSlot *slot = lean_sbf_resolve_slot(idx, "set_data_byte");
    if (!LEAN_SBF_SLOT_WRITABLE(slot)) {
        const char *m = "lean-sbf: set_data_byte on non-writable account";
        sol_log_(m, lean_strlen(m));
        sol_panic_("set_data_byte", 13, idx, 0);
        __builtin_unreachable();
    }
    uint64_t len = LEAN_SBF_SLOT_DATA_LEN(slot);
    if (offset >= len) {
        const char *m = "lean-sbf: set_data_byte offset out of range";
        sol_log_(m, lean_strlen(m));
        sol_panic_("set_data_byte", 13, offset, len);
        __builtin_unreachable();
    }
    slot->data_ptr[offset] = value;
    return lean_box(0);
}

void *lean_sbf_write_data(uint64_t idx, uint64_t offset, void *src_bytearray) {
    LeanSbfAccountSlot *slot = lean_sbf_resolve_slot(idx, "write_data");
    if (!LEAN_SBF_SLOT_WRITABLE(slot)) {
        const char *m = "lean-sbf: write_data on non-writable account";
        sol_log_(m, lean_strlen(m));
        sol_panic_("write_data", 10, idx, 0);
        __builtin_unreachable();
    }
    lean_sarray_object *src = (lean_sarray_object *)src_bytearray;
    uint64_t len = LEAN_SBF_SLOT_DATA_LEN(slot);
    if (offset > len || src->m_size > len - offset) {
        const char *m = "lean-sbf: write_data extends past account data_len";
        sol_log_(m, lean_strlen(m));
        sol_panic_("write_data", 10, offset + src->m_size, len);
        __builtin_unreachable();
    }
    for (size_t i = 0; i < src->m_size; ++i) {
        slot->data_ptr[offset + i] = src->m_data[i];
    }
    return lean_box(0);
}

void *lean_sbf_read_data(uint64_t idx, uint64_t offset, uint64_t len) {
    LeanSbfAccountSlot *slot = lean_sbf_resolve_slot(idx, "read_data");
    uint64_t total = LEAN_SBF_SLOT_DATA_LEN(slot);
    if (offset > total || len > total - offset) {
        const char *m = "lean-sbf: read_data extends past account data_len";
        sol_log_(m, lean_strlen(m));
        sol_panic_("read_data", 9, offset + len, total);
        __builtin_unreachable();
    }
    return lean_freestanding_make_byte_array(slot->data_ptr + offset, len);
}
