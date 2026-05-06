/- Derive an address-book PDA from instruction-data name and program ID. -/
import Std.Solana

open Std.Solana

namespace AddressBook

/-- Canonical seed prefix that identifies this program's registry. -/
def seedPrefix : ByteArray := "addressbook".toUTF8

/-- Reject names larger than 32 bytes — keeps the seed list within the
    Solana SDK's 16-segment / 32-byte-per-segment cap. -/
def maxNameBytes : Nat := 32

@[export lean_sol_entry_typed]
def entry (ctx : ProgramContext) : UInt64 :=
  let _ := msg! "addressbook: derive PDA"
  let name := ctx.data
  if name.size > maxNameBytes then
    let _ := msg! "addressbook: name too long"
    0xE1
  else
    match findProgramAddressImpl #[seedPrefix, name] ctx.programId with
    | some (_pk, bump) =>
      let _ := msg! "addressbook: PDA derived"
      bump.toUInt64
    | none =>
      let _ := msg! "addressbook: no valid PDA"
      0xE0

end AddressBook
