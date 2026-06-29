/- DiagKey: typed entrypoint validates accounts[0].key and .owner.

   Regression test for the unboxed-`Pubkey` representation bug: `Pubkey` is a
   trivial structure, so the compiler represents it as its bare `ByteArray` and
   `a.key.toBytes` is the identity. The SBF runtime used to store `key`/`owner`
   as an explicit `Pubkey` ctor, so reading `a.key.toBytes[i]` returned the ctor
   header instead of the address byte (a constant, independent of the account).
   The return value packs two projected bytes from both `key` and `owner`, plus
   equality flags for `a.key == expectedKey` and `a.owner == expectedOwner`.
   Instruction data is `expectedKey || expectedOwner`. -/
import Std.Solana
open Std.Solana

namespace DiagKey

private def bit (b : Bool) : UInt64 :=
  if b then 1 else 0

private def firstMismatch (a b : ByteArray) : UInt64 × UInt64 × UInt64 := Id.run do
  for i in [0:32] do
    let x := (a[i]?.getD 0).toUInt64
    let y := (b[i]?.getD 0).toUInt64
    if x != y then
      return (i.toUInt64, x, y)
  return (0xFF, 0, 0)

@[export lean_sol_entry_typed]
def entry (ctx : ProgramContext) : UInt64 :=
  match ctx.accounts[0]? with
  | none => 0xFF00
  | some a =>
    match Bytes.readPubkeyAt? ctx.data 0, Bytes.readPubkeyAt? ctx.data 32 with
    | some expectedKey, some expectedOwner =>
      let k0 : UInt64 := (a.key.toBytes[0]?.getD 0).toUInt64
      let k1 : UInt64 := (a.key.toBytes[1]?.getD 0).toUInt64
      let o0 : UInt64 := (a.owner.toBytes[0]?.getD 0).toUInt64
      let o1 : UInt64 := (a.owner.toBytes[1]?.getD 0).toUInt64
      let bytes := (((k0 * 256 + k1) * 256 + o0) * 256 + o1)
      let (mIdx, mActual, mExpected) := firstMismatch a.key.toBytes expectedKey.toBytes
      (((bytes * 4 + bit (a.key == expectedKey) * 2 + bit (a.owner == expectedOwner)) * 256
        + mIdx) * 256 + mActual) * 256 + mExpected
    | _, _ => 0xEE00

end DiagKey
