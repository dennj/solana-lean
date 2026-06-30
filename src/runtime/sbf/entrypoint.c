/*
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Solana SBF program entrypoint: ABI adapter from the loader-facing
`entrypoint(const uint8_t *) -> uint64_t` to the leanc-generated
`lean_sbf_module_init` and `lean_sbf_invoke_entry` wrappers.
*/

#include <stdint.h>
#include <stddef.h>

extern void *lean_sbf_module_init(uint8_t builtin);
extern uint64_t lean_sbf_invoke_entry(const uint8_t *input);
extern uint8_t lean_sbf_entry_returns_status(void);

extern void sol_log_64_(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);

/* See solana SBF SDK (sdk/sbf/c/inc/sol/deserialize.h). */
#define MAX_PERMITTED_DATA_INCREASE (1024 * 10)

static const uint8_t *skip_account(const uint8_t *p) {
    uint8_t dup_info = *p++;
    if (dup_info != 0xFFu) {
        /* Duplicate marker: 7 bytes padding follow. */
        return p + 7;
    }
    /* Full account record: is_signer/is_writable/executable/padding/pubkey/
       owner/lamports/data_len/data/realloc-pad/8-align/rent_epoch. */
    p += 1 + 1 + 1 + 4 + 32 + 32 + 8;
    uint64_t data_len = *(const uint64_t *)p;
    p += 8 + data_len + MAX_PERMITTED_DATA_INCREASE;
    p = (const uint8_t *)(((uintptr_t)p + 7u) & ~(uintptr_t)7u);
    p += 8; /* rent_epoch */
    return p;
}

uint64_t entrypoint(const uint8_t *input) {
#ifdef LEAN_SBF_ENTRYPOINT_TRACE
    sol_log_64_(0x1EA0u, 0, 0, 0, 0);
#endif
    lean_sbf_module_init(/* builtin = */ 1);
#ifdef LEAN_SBF_ENTRYPOINT_TRACE
    sol_log_64_(0x1EA1u, 0, 0, 0, 0);
#endif
    uint64_t result = lean_sbf_invoke_entry(input);
#ifdef LEAN_SBF_ENTRYPOINT_TRACE
    sol_log_64_(0x1EA2u, 0, 0, 0, result);
#endif

    /* Extract data_len so the validator log line is interpretable. */
    const uint8_t *p = input;
    uint64_t ka_num = *(const uint64_t *)p; p += 8;
    for (uint64_t i = 0; i < ka_num; ++i) p = skip_account(p);
    uint64_t data_len = *(const uint64_t *)p;
    /* 0x1EAA marker = "Lean answer" in validator log. */
    sol_log_64_(0x1EAAu, 0, 0, data_len, result);
    return lean_sbf_entry_returns_status() ? result : 0;
}
