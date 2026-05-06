/*
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
*/

#include <cstdio>
#include <cstdint>
#include <lean/lean.h>

namespace lean {
extern "C" {

LEAN_EXPORT lean_object * lean_sol_log(b_lean_obj_arg s) {
    size_t sz = lean_string_size(s);
    if (sz > 0) {
        std::fwrite(lean_string_cstr(s), 1, sz - 1, stderr);
        std::fputc('\n', stderr);
    }
    return lean_box(0);
}

LEAN_EXPORT lean_object * lean_sbf_invoke_signed(b_lean_obj_arg instruction, b_lean_obj_arg signers) {
    (void)instruction; (void)signers;
    std::fputs("lean-host: Std.Solana.invokeSigned called (no-op on host)\n", stderr);
    return lean_box(0);
}

LEAN_EXPORT lean_object * lean_sbf_find_program_address(b_lean_obj_arg seeds, b_lean_obj_arg program_id) {
    (void)seeds; (void)program_id;
    std::fputs("lean-host: Std.Solana.findProgramAddress called (no-op on host)\n", stderr);
    return lean_box(0);
}

LEAN_EXPORT lean_object * lean_sbf_create_program_address(b_lean_obj_arg seeds, b_lean_obj_arg program_id) {
    (void)seeds; (void)program_id;
    std::fputs("lean-host: Std.Solana.createProgramAddress called (no-op on host)\n", stderr);
    return lean_box(0);
}

LEAN_EXPORT lean_object * lean_sbf_get_clock_sysvar(uint64_t nonce) {
    (void)nonce;
    std::fputs("lean-host: Std.Solana.Sysvar.Clock.get? called (no-op on host)\n", stderr);
    return lean_box(0);
}

LEAN_EXPORT uint64_t lean_sbf_get_lamports(uint64_t idx) {
    (void)idx;
    std::fputs("lean-host: Std.Solana.getLamports called (no-op on host)\n", stderr);
    return 0;
}

LEAN_EXPORT lean_object * lean_sbf_set_lamports(uint64_t idx, uint64_t value) {
    (void)idx; (void)value;
    std::fputs("lean-host: Std.Solana.setLamports called (no-op on host)\n", stderr);
    return lean_box(0);
}

LEAN_EXPORT uint8_t lean_sbf_get_data_byte(uint64_t idx, uint64_t offset) {
    (void)idx; (void)offset;
    std::fputs("lean-host: Std.Solana.getDataByte called (no-op on host)\n", stderr);
    return 0;
}

LEAN_EXPORT lean_object * lean_sbf_set_data_byte(uint64_t idx, uint64_t offset, uint8_t value) {
    (void)idx; (void)offset; (void)value;
    std::fputs("lean-host: Std.Solana.setDataByte called (no-op on host)\n", stderr);
    return lean_box(0);
}

LEAN_EXPORT lean_object * lean_sbf_write_data(uint64_t idx, uint64_t offset, b_lean_obj_arg src) {
    (void)idx; (void)offset; (void)src;
    std::fputs("lean-host: Std.Solana.writeData called (no-op on host)\n", stderr);
    return lean_box(0);
}

LEAN_EXPORT lean_object * lean_sbf_read_data(uint64_t idx, uint64_t offset, uint64_t len) {
    (void)idx; (void)offset;
    std::fputs("lean-host: Std.Solana.readData called (no-op on host)\n", stderr);
    return lean_alloc_sarray(1, 0, len);
}

} // extern "C"
} // namespace lean
