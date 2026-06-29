/- DiagKey: typed entrypoint returns (accounts[0].key[0] << 8) | key[1].

   Regression test for the unboxed-`Pubkey` representation bug: `Pubkey` is a
   trivial structure, so the compiler represents it as its bare `ByteArray` and
   `a.key.toBytes` is the identity. The SBF runtime used to store `key`/`owner`
   as an explicit `Pubkey` ctor, so reading `a.key.toBytes[i]` returned the ctor
   header instead of the address byte (a constant, independent of the account).
   Returning two distinct key bytes pins the fix: both must equal the account's
   real address bytes. -/
import Std.Solana
open Std.Solana

namespace DiagKey

@[export lean_sol_entry_typed]
def entry (ctx : ProgramContext) : UInt64 :=
  match ctx.accounts[0]? with
  | none => 0xFF00
  | some a =>
    let k0 : UInt64 := (a.key.toBytes[0]?.getD 0).toUInt64
    let k1 : UInt64 := (a.key.toBytes[1]?.getD 0).toUInt64
    (k0 * 256) + k1

end DiagKey
