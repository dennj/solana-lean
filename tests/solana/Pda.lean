/- Linked .so retains lean_sbf_find_program_address / sol_try_find_program_address. -/
import Std.Solana

open Std.Solana

@[export lean_sol_entry_typed]
def entry (ctx : ProgramContext) : UInt64 :=
  let _ := msg! "pda demo"
  let seed := ByteArray.mk #[0x6c, 0x65, 0x61, 0x6e]  -- "lean"
  match findProgramAddressImpl #[seed] ctx.programId with
  | some (_pk, bump) => 0xB0 ||| bump.toUInt64
  | none             => 0xE0
