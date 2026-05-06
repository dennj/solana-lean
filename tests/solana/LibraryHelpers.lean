/- Exercises reusable `Std.Solana` helpers in SBF codegen. -/
import Std.Solana

open Std.Solana

def helperDisc : Anchor.Discriminator :=
  { bytes := ByteArray.mk #[0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]
    size_eq := by rfl }

def helperCodec : AccountCodec UInt64 :=
  { discriminator := some helperDisc
    fixedPayloadLen := some 8
    decodePayload := Borsh.Decoder.readUInt64LE?
    encodePayload := fun value => some (Borsh.Encoder.putUInt64LE Borsh.Encoder.empty value) }

def decodeInstructionBody : Dispatch.Handler UInt64 :=
  fun d =>
    ProgramResult.decodeExact d (fun d => do
      let (maybeValue, d) ← Borsh.Decoder.readOption? d Borsh.Decoder.readUInt64LE?
      let (items, d) ← Borsh.Decoder.readVector? d Borsh.Decoder.readUInt16LE?
      let (wide, d) ← Borsh.Decoder.readUInt128LE? d
      let (tag, d) ← Borsh.Decoder.readEnumTag? d
      some (maybeValue.getD 0 + items.size.toUInt64 + (wide % 251).toUInt64 + tag.toUInt64, d))
      ProgramError.invalidInstructionData

def helperCases : Array (Dispatch.TagCase UInt64) := #[
  { tag := 1, run := decodeInstructionBody }
]

@[export lean_sol_entry_typed]
def entry (ctx : ProgramContext) : UInt64 :=
  let accountValue :=
    match ctx.loadAccount 0 helperCodec (0xff : UInt64) with
    | .ok loaded => loaded.value
    | .error _ => 0
  let systemInst := SystemProgram.transferInstruction ctx.programId ctx.programId 5
  let systemTag := systemInst.data[0]?.getD 0
  let systemAccounts := systemInst.accounts.size.toUInt64
  let tokenInst := TokenProgram.transferCheckedInstructionWithProgram TokenProgram.token2022Id
    ctx.programId ctx.programId ctx.programId ctx.programId 7 6
  let tokenTag := tokenInst.data[0]?.getD 0
  let ataInst := AssociatedTokenProgram.createIdempotentInstruction
    ctx.programId ctx.programId ctx.programId ctx.programId TokenProgram.token2022Id
  let ataTag := ataInst.data[0]?.getD 0
  let program58 := ctx.programId.toBase58Bytes
  let base58RoundTrip :=
    match Pubkey.ofBase58Bytes? program58 with
    | some key => if key == ctx.programId then (1 : UInt64) else 0
    | none => 0
  let clockPresent :=
    match ctx.findAccountByKey? Sysvar.Clock.id with
    | some _ => 1
    | none => 0
  match ctx.dispatchTag helperCases with
  | .ok value =>
      accountValue + value + systemTag.toUInt64 + systemAccounts
        + tokenTag.toUInt64 + ataTag.toUInt64 + program58.size.toUInt64
        + base58RoundTrip + clockPresent
  | .error err =>
      accountValue + err + systemTag.toUInt64 + systemAccounts
        + tokenTag.toUInt64 + ataTag.toUInt64 + program58.size.toUInt64
        + base58RoundTrip + clockPresent
