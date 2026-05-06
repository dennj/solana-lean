/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
module

prelude
public import Init.Data.String.Basic
public import Init.Data.ByteArray.Basic
public import Init.Data.Array.Basic
public import Init.Data.Range.Basic
public import Init.System.IO
public import Std.Solana.Unsupported

/-! User-facing entry point for writing Solana programs in Lean 4. Primitives
lower onto the SBF syscall surface exposed by `src/runtime/sbf/` via
`lean --target=sbf-solana-solana`. -/

public section

namespace Std.Solana

/-- Attribute shorthand for the canonical Solana typed entrypoint export.

Use
```
@[solana_entrypoint]
def entry (ctx : Std.Solana.ProgramContext) : UInt64 := ...
```
instead of writing `@[export lean_sol_entry_typed]` directly. -/
macro "solana_entrypoint" : attr => do
  let exportName := Lean.mkIdentFrom (← Lean.getRef) `lean_sol_entry_typed (canonical := true)
  `(attr| export $exportName:ident)

@[inline, expose]
def byteArrayBEq (a b : ByteArray) : Bool :=
  if a.size == b.size then
    Id.run do
      for i in [0:a.size] do
        if a[i]? != b[i]? then
          return false
      return true
  else
    false

/-- Forwards a Lean `String` to the Solana `sol_log_` syscall. Use `msg` or
`msg!` rather than calling directly. -/
@[extern "lean_sol_log", never_extract]
opaque solLogImpl (s : @&String) : Unit

/-- Log a message to the validator's program log (IO form). -/
def msg (s : String) : BaseIO Unit :=
  pure (solLogImpl s)

/-- `dbg_trace`-shaped logging for embedding inside pure-typed entry functions. -/
@[inline, expose]
def msg! (s : String) : Unit :=
  solLogImpl s

/-- A Solana public key (32 bytes): account address, program ID, etc. -/
structure Pubkey where
  mk ::
  bytes : ByteArray
  size_eq : bytes.size = 32

namespace Pubkey

@[inline, expose]
def ofBytes? (b : ByteArray) : Option Pubkey :=
  if h : b.size = 32 then some ⟨b, h⟩ else none

@[inline, expose]
def toBytes (p : Pubkey) : ByteArray := p.bytes

instance : BEq Pubkey where
  beq p q := byteArrayBEq p.bytes q.bytes

end Pubkey

/-- A 32-byte hash (sha256 digest, recent blockhash, etc.). -/
structure Hash where
  mk ::
  bytes : ByteArray
  size_eq : bytes.size = 32

namespace Hash

@[inline, expose]
def ofBytes? (b : ByteArray) : Option Hash :=
  if h : b.size = 32 then some ⟨b, h⟩ else none

@[inline, expose]
def toBytes (h : Hash) : ByteArray := h.bytes

instance : BEq Hash where
  beq a b := byteArrayBEq a.bytes b.bytes

end Hash

/-- A 64-byte Ed25519 signature. -/
structure Signature where
  mk ::
  bytes : ByteArray
  size_eq : bytes.size = 64

namespace Signature

@[inline, expose]
def ofBytes? (b : ByteArray) : Option Signature :=
  if h : b.size = 64 then some ⟨b, h⟩ else none

@[inline, expose]
def toBytes (s : Signature) : ByteArray := s.bytes

instance : BEq Signature where
  beq a b := byteArrayBEq a.bytes b.bytes

end Signature

/-! Base58 encoding/decoding.

The implementation uses byte-array base conversion instead of converting the
whole input to a `Nat`; that keeps 32-byte public keys within the bounded Nat
subset used by the freestanding runtime. -/

namespace Base58

@[inline, expose]
def alphabet : ByteArray :=
  ByteArray.mk #[
    49, 50, 51, 52, 53, 54, 55, 56,
    57, 65, 66, 67, 68, 69, 70, 71,
    72, 74, 75, 76, 77, 78, 80, 81,
    82, 83, 84, 85, 86, 87, 88, 89,
    90, 97, 98, 99, 100, 101, 102, 103,
    104, 105, 106, 107, 109, 110, 111, 112,
    113, 114, 115, 116, 117, 118, 119, 120,
    121, 122]

def zeroChar : UInt8 := 49

@[inline, expose]
def alphabetChar? (idx : Nat) : Option UInt8 :=
  alphabet[idx]?

@[inline, expose]
def alphabetIndex? (c : UInt8) : Option UInt8 := Id.run do
  for i in [0:58] do
    if alphabet[i]?.getD 0 == c then
      return some i.toUInt8
  return none

@[inline, expose]
def countLeading (bytes : ByteArray) (value : UInt8) : Nat := Id.run do
  let mut count : Nat := 0
  let mut done := false
  for i in [0:bytes.size] do
    let b := bytes[i]?.getD 0
    if !done then
      if b == value then
        count := count + 1
      else
        done := true
  return count

@[inline, expose]
def encodeBytes (input : ByteArray) : ByteArray := Id.run do
  let leading := countLeading input 0
  let mut digits := ByteArray.empty
  for inputIdx in [0:input.size] do
    let b := input[inputIdx]?.getD 0
    let mut carry : Nat := b.toNat
    for i in [0:digits.size] do
      let value := (digits[i]?.getD 0).toNat * 256 + carry
      digits := digits.set! i (value % 58).toUInt8
      carry := value / 58
    if carry > 0 then
      digits := digits.push (carry % 58).toUInt8
      carry := carry / 58
    if carry > 0 then
      digits := digits.push (carry % 58).toUInt8

  let mut out := ByteArray.emptyWithCapacity (leading + digits.size)
  for _ in [0:leading] do
    out := out.push zeroChar
  for i in [0:digits.size] do
    let digit := digits[digits.size - 1 - i]?.getD 0
    out := out.push (alphabetChar? digit.toNat |>.getD zeroChar)
  return out

@[inline, expose]
def decodeBytes? (encoded : ByteArray) : Option ByteArray := Id.run do
  let leading := countLeading encoded zeroChar
  let mut digits := ByteArray.empty
  for inputIdx in [0:encoded.size] do
    let c := encoded[inputIdx]?.getD 0
    match alphabetIndex? c with
    | none => return none
    | some value =>
        let mut carry : Nat := value.toNat
        for i in [0:digits.size] do
          let n := (digits[i]?.getD 0).toNat * 58 + carry
          digits := digits.set! i (n % 256).toUInt8
          carry := n / 256
        if carry > 0 then
          digits := digits.push (carry % 256).toUInt8

  let mut out := ByteArray.emptyWithCapacity (leading + digits.size)
  for _ in [0:leading] do
    out := out.push 0
  for i in [0:digits.size] do
    out := out.push (digits[digits.size - 1 - i]?.getD 0)
  return some out

@[inline, expose]
def encode (input : ByteArray) : String :=
  match String.fromUTF8? (encodeBytes input) with
  | some s => s
  | none => ""

@[inline, expose]
def decode? (encoded : String) : Option ByteArray :=
  decodeBytes? encoded.toUTF8

@[inline, expose]
def decodePubkeyBytes? (encoded : ByteArray) : Option Pubkey :=
  Pubkey.ofBytes? =<< decodeBytes? encoded

@[inline, expose]
def decodePubkey? (encoded : String) : Option Pubkey :=
  decodePubkeyBytes? encoded.toUTF8

end Base58

namespace Pubkey

@[inline, expose]
def toBase58Bytes (p : Pubkey) : ByteArray :=
  Base58.encodeBytes p.toBytes

@[inline, expose]
def toBase58 (p : Pubkey) : String :=
  Base58.encode p.toBytes

@[inline, expose]
def ofBase58Bytes? (encoded : ByteArray) : Option Pubkey :=
  Base58.decodePubkeyBytes? encoded

@[inline, expose]
def ofBase58? (encoded : String) : Option Pubkey :=
  Base58.decodePubkey? encoded

end Pubkey

/-! Program errors/results. Solana entrypoints return `0` for success and a
non-zero custom error code for failure; these helpers keep internal code in
`Except` form and collapse to a return code at the boundary. -/

abbrev ProgramError := UInt64
abbrev ProgramResult (α : Type) := Except ProgramError α

namespace ProgramError

def success : ProgramError := 0
def invalidInstructionData : ProgramError := 1
def invalidAccountData : ProgramError := 2
def notEnoughAccounts : ProgramError := 3
def accountConstraint : ProgramError := 4
def invalidDiscriminator : ProgramError := 5
def arithmeticOverflow : ProgramError := 6
def unsupportedInstruction : ProgramError := 7
def cpiFailed : ProgramError := 8
def customBase : ProgramError := 0x100

end ProgramError

namespace ProgramResult

@[inline, expose]
def toReturnCode : ProgramResult Unit → UInt64
  | .ok () => ProgramError.success
  | .error err => err

@[inline, expose]
def toReturnCodeWith (ok : α → UInt64) : ProgramResult α → UInt64
  | .ok value => ok value
  | .error err => err

@[inline, expose]
def fromOption (value : Option α) (err : ProgramError) : ProgramResult α :=
  match value with
  | some value => .ok value
  | none => .error err

@[inline, expose]
def require (condition : Bool) (err : ProgramError) : ProgramResult Unit :=
  if condition then .ok () else .error err

@[inline, expose]
def requireEq [BEq α] (actual expected : α) (err : ProgramError) : ProgramResult Unit :=
  require (actual == expected) err

@[inline, expose]
def requireSome (value : Option α) (err : ProgramError) : ProgramResult α :=
  fromOption value err

@[inline, expose]
def mapError (f : ProgramError → ProgramError) : ProgramResult α → ProgramResult α
  | .ok value => .ok value
  | .error err => .error (f err)

@[inline, expose]
def logOnError! (message : String) : ProgramResult α → ProgramResult α
  | .ok value => .ok value
  | .error err =>
      let _ := msg! message
      .error err

@[inline, expose]
def logAndReturnCode! (message : String) (result : ProgramResult Unit) : UInt64 :=
  toReturnCode (logOnError! message result)

end ProgramResult

/-! Byte-level helpers. These are intentionally Solana-agnostic: they are
small building blocks for instruction data, account layouts, and Borsh codecs. -/

namespace Bytes

@[inline, expose]
def maxUnsigned (width : Nat) : Nat :=
  256 ^ width

@[inline, expose]
def fitsUnsigned (width value : Nat) : Bool :=
  decide (value < maxUnsigned width)

@[inline, expose]
def maxSignedMagnitude (width : Nat) : Nat :=
  2 ^ (8 * width - 1)

@[inline, expose]
def fitsSigned (width : Nat) (value : Int) : Bool :=
  let bound := Int.ofNat (maxSignedMagnitude width)
  decide (-bound <= value ∧ value < bound)

@[inline, expose]
def hasRange (bytes : ByteArray) (offset len : Nat) : Bool :=
  decide (offset + len <= bytes.size)

@[inline, expose]
def readBytesAt? (bytes : ByteArray) (offset len : Nat) : Option ByteArray :=
  if offset + len <= bytes.size then
    some <| Id.run do
      let mut out := ByteArray.emptyWithCapacity len
      for i in [0:len] do
        out := out.push (bytes[offset + i]?.getD 0)
      out
  else
    none

@[inline, expose]
def readUInt8At? (bytes : ByteArray) (offset : Nat) : Option UInt8 :=
  bytes[offset]?

@[inline, expose]
def readBoolAt? (bytes : ByteArray) (offset : Nat) : Option Bool :=
  match bytes[offset]? with
  | some 0 => some false
  | some 1 => some true
  | _ => none

@[inline, expose]
def allZero (bytes : ByteArray) : Bool := Id.run do
  for b in bytes do
    if b != 0 then
      return false
  return true

@[inline, expose]
def readNatLEAt? (bytes : ByteArray) (offset width : Nat) : Option Nat :=
  if offset + width <= bytes.size then
    some <| Id.run do
      let mut acc : Nat := 0
      let mut factor : Nat := 1
      for i in [0:width] do
        let b := bytes[offset + i]?.getD 0
        acc := acc + b.toNat * factor
        factor := factor * 256
      acc
  else
    none

@[inline]
def readUInt64LowLEUnchecked (bytes : ByteArray) (offset width : Nat) : UInt64 := Id.run do
  let mut acc : UInt64 := 0
  for i in [0:width] do
    let b := bytes[offset + i]?.getD 0
    acc := acc ||| (b.toUInt64 <<< (i.toUInt64 * 8))
  acc

@[inline, expose]
def readUInt16LEAt? (bytes : ByteArray) (offset : Nat) : Option UInt16 :=
  if offset + 2 <= bytes.size then
    some (readUInt64LowLEUnchecked bytes offset 2).toUInt16
  else
    none

@[inline, expose]
def readUInt32LEAt? (bytes : ByteArray) (offset : Nat) : Option UInt32 :=
  if offset + 4 <= bytes.size then
    some (readUInt64LowLEUnchecked bytes offset 4).toUInt32
  else
    none

@[inline, expose]
def readUInt64LEAt? (bytes : ByteArray) (offset : Nat) : Option UInt64 :=
  if offset + 8 <= bytes.size then
    some (readUInt64LowLEUnchecked bytes offset 8)
  else
    none

@[inline, expose]
def readUInt128LEAt? (bytes : ByteArray) (offset : Nat) : Option Nat :=
  readNatLEAt? bytes offset 16

@[inline, expose]
def readIntLEAt? (bytes : ByteArray) (offset width : Nat) : Option Int := do
  let raw ← readNatLEAt? bytes offset width
  let bits := 8 * width
  let signedBound := 2 ^ (bits - 1)
  let modulus := 2 ^ bits
  if raw < signedBound then
    some (Int.ofNat raw)
  else
    some (Int.ofNat raw - Int.ofNat modulus)

@[inline, expose]
def readInt8At? (bytes : ByteArray) (offset : Nat) : Option Int :=
  readIntLEAt? bytes offset 1

@[inline, expose]
def readInt16LEAt? (bytes : ByteArray) (offset : Nat) : Option Int :=
  readIntLEAt? bytes offset 2

@[inline, expose]
def readInt32LEAt? (bytes : ByteArray) (offset : Nat) : Option Int :=
  readIntLEAt? bytes offset 4

@[inline, expose]
def readInt64LEAt? (bytes : ByteArray) (offset : Nat) : Option Int :=
  readIntLEAt? bytes offset 8

@[inline, expose]
def readInt128LEAt? (bytes : ByteArray) (offset : Nat) : Option Int :=
  readIntLEAt? bytes offset 16

@[inline, expose]
def readPubkeyAt? (bytes : ByteArray) (offset : Nat) : Option Pubkey :=
  Pubkey.ofBytes? =<< readBytesAt? bytes offset 32

@[inline, expose]
def appendNatLE (bytes : ByteArray) (width : Nat) (value : Nat) : ByteArray := Id.run do
  let mut out := bytes
  let mut rest := value
  for _ in [0:width] do
    out := out.push (rest % 256).toUInt8
    rest := rest / 256
  out

@[inline, expose]
def appendRepeated (bytes : ByteArray) (value : UInt8) (count : Nat) : ByteArray := Id.run do
  let mut out := bytes
  for _ in [0:count] do
    out := out.push value
  out

@[inline, expose]
def appendBoundedNatLE? (bytes : ByteArray) (width : Nat) (value : Nat) : Option ByteArray :=
  if value < maxUnsigned width then
    some (appendNatLE bytes width value)
  else
    none

@[inline]
def appendUInt64LowLE (bytes : ByteArray) (width : Nat) (value : UInt64) : ByteArray :=
  Id.run do
    let mut out := bytes
    for i in [0:width] do
      out := out.push ((value >>> (i.toUInt64 * 8)).toUInt8)
    out

@[inline, expose]
def appendUInt8 (bytes : ByteArray) (value : UInt8) : ByteArray :=
  bytes.push value

@[inline, expose]
def appendBool (bytes : ByteArray) (value : Bool) : ByteArray :=
  bytes.push (if value then 1 else 0)

@[inline, expose]
def appendUInt16LE (bytes : ByteArray) (value : UInt16) : ByteArray :=
  appendUInt64LowLE bytes 2 value.toUInt64

@[inline, expose]
def appendUInt32LE (bytes : ByteArray) (value : UInt32) : ByteArray :=
  appendUInt64LowLE bytes 4 value.toUInt64

@[inline, expose]
def appendUInt64LE (bytes : ByteArray) (value : UInt64) : ByteArray :=
  appendUInt64LowLE bytes 8 value

@[inline, expose]
def appendUInt128LE (bytes : ByteArray) (value : Nat) : ByteArray :=
  appendNatLE bytes 16 value

@[inline, expose]
def appendUInt128LE? (bytes : ByteArray) (value : Nat) : Option ByteArray :=
  appendBoundedNatLE? bytes 16 value

@[inline, expose]
def appendIntLE? (bytes : ByteArray) (width : Nat) (value : Int) : Option ByteArray :=
  if fitsSigned width value then
    let modulus := Int.ofNat (maxUnsigned width)
    let raw : Nat := if value < 0 then (modulus + value).toNat else value.toNat
    some (appendNatLE bytes width raw)
  else
    none

@[inline, expose]
def appendInt8? (bytes : ByteArray) (value : Int) : Option ByteArray :=
  appendIntLE? bytes 1 value

@[inline, expose]
def appendInt16LE? (bytes : ByteArray) (value : Int) : Option ByteArray :=
  appendIntLE? bytes 2 value

@[inline, expose]
def appendInt32LE? (bytes : ByteArray) (value : Int) : Option ByteArray :=
  appendIntLE? bytes 4 value

@[inline, expose]
def appendInt64LE? (bytes : ByteArray) (value : Int) : Option ByteArray :=
  appendIntLE? bytes 8 value

@[inline, expose]
def appendInt128LE? (bytes : ByteArray) (value : Int) : Option ByteArray :=
  appendIntLE? bytes 16 value

@[inline, expose]
def appendPubkey (bytes : ByteArray) (key : Pubkey) : ByteArray :=
  bytes.append key.toBytes

end Bytes

/-! Minimal Borsh cursor and encoder primitives. The decoder keeps an offset
inside a `ByteArray`; reads fail with `none` instead of panicking. -/

namespace Borsh

structure Decoder where
  bytes  : ByteArray
  offset : Nat

namespace Decoder

@[inline, expose]
def ofBytes (bytes : ByteArray) : Decoder :=
  { bytes, offset := 0 }

@[inline, expose]
def position (d : Decoder) : Nat :=
  d.offset

@[inline, expose]
def remaining (d : Decoder) : Nat :=
  d.bytes.size - d.offset

@[inline, expose]
def done (d : Decoder) : Bool :=
  d.offset == d.bytes.size

@[inline, expose]
def exact (d : Decoder) : Option Unit :=
  if d.done then some () else none

@[inline, expose]
def take? (d : Decoder) (len : Nat) : Option (ByteArray × Decoder) := do
  let bytes ← Bytes.readBytesAt? d.bytes d.offset len
  some (bytes, { d with offset := d.offset + len })

@[inline, expose]
def skip? (d : Decoder) (len : Nat) : Option Decoder :=
  (take? d len).map Prod.snd

@[inline, expose]
def readPadding? (d : Decoder) (len : Nat) : Option Decoder :=
  skip? d len

@[inline, expose]
def readZeroPadding? (d : Decoder) (len : Nat) : Option Decoder := do
  let (bytes, d) ← take? d len
  if Bytes.allZero bytes then
    some d
  else
    none

@[inline, expose]
def readUInt8? (d : Decoder) : Option (UInt8 × Decoder) := do
  let value ← Bytes.readUInt8At? d.bytes d.offset
  some (value, { d with offset := d.offset + 1 })

@[inline, expose]
def readBool? (d : Decoder) : Option (Bool × Decoder) := do
  let value ← Bytes.readBoolAt? d.bytes d.offset
  some (value, { d with offset := d.offset + 1 })

@[inline, expose]
def readUInt16LE? (d : Decoder) : Option (UInt16 × Decoder) := do
  let value ← Bytes.readUInt16LEAt? d.bytes d.offset
  some (value, { d with offset := d.offset + 2 })

@[inline, expose]
def readUInt32LE? (d : Decoder) : Option (UInt32 × Decoder) := do
  let value ← Bytes.readUInt32LEAt? d.bytes d.offset
  some (value, { d with offset := d.offset + 4 })

@[inline, expose]
def readUInt64LE? (d : Decoder) : Option (UInt64 × Decoder) := do
  let value ← Bytes.readUInt64LEAt? d.bytes d.offset
  some (value, { d with offset := d.offset + 8 })

@[inline, expose]
def readUInt128LE? (d : Decoder) : Option (Nat × Decoder) := do
  let value ← Bytes.readUInt128LEAt? d.bytes d.offset
  some (value, { d with offset := d.offset + 16 })

@[inline, expose]
def readInt8? (d : Decoder) : Option (Int × Decoder) := do
  let value ← Bytes.readInt8At? d.bytes d.offset
  some (value, { d with offset := d.offset + 1 })

@[inline, expose]
def readInt16LE? (d : Decoder) : Option (Int × Decoder) := do
  let value ← Bytes.readInt16LEAt? d.bytes d.offset
  some (value, { d with offset := d.offset + 2 })

@[inline, expose]
def readInt32LE? (d : Decoder) : Option (Int × Decoder) := do
  let value ← Bytes.readInt32LEAt? d.bytes d.offset
  some (value, { d with offset := d.offset + 4 })

@[inline, expose]
def readInt64LE? (d : Decoder) : Option (Int × Decoder) := do
  let value ← Bytes.readInt64LEAt? d.bytes d.offset
  some (value, { d with offset := d.offset + 8 })

@[inline, expose]
def readInt128LE? (d : Decoder) : Option (Int × Decoder) := do
  let value ← Bytes.readInt128LEAt? d.bytes d.offset
  some (value, { d with offset := d.offset + 16 })

@[inline, expose]
def readNatLE? (d : Decoder) (width : Nat) : Option (Nat × Decoder) := do
  let value ← Bytes.readNatLEAt? d.bytes d.offset width
  some (value, { d with offset := d.offset + width })

@[inline, expose]
def readBytes? (d : Decoder) (len : Nat) : Option (ByteArray × Decoder) :=
  take? d len

@[inline, expose]
def readPubkey? (d : Decoder) : Option (Pubkey × Decoder) := do
  let value ← Bytes.readPubkeyAt? d.bytes d.offset
  some (value, { d with offset := d.offset + 32 })

@[inline, expose]
def readString? (d : Decoder) : Option (String × Decoder) := do
  let (len, d) ← readUInt32LE? d
  let (bytes, d) ← readBytes? d len.toNat
  let s ← String.fromUTF8? bytes
  some (s, d)

@[inline, expose]
def readEnumTag? (d : Decoder) : Option (UInt8 × Decoder) :=
  readUInt8? d

@[inline, expose]
def readArray? (d : Decoder) (len : Nat)
    (readElem : Decoder → Option (α × Decoder)) : Option (Array α × Decoder) := Id.run do
  let mut cur := d
  let mut out : Array α := Array.empty
  for _ in [0:len] do
    match readElem cur with
    | none => return none
    | some (value, next) =>
        out := out.push value
        cur := next
  return some (out, cur)

@[inline, expose]
def readVector? (d : Decoder)
    (readElem : Decoder → Option (α × Decoder)) : Option (Array α × Decoder) := do
  let (len, d) ← readUInt32LE? d
  readArray? d len.toNat readElem

@[inline, expose]
def readOption? (d : Decoder)
    (readSome : Decoder → Option (α × Decoder)) : Option (Option α × Decoder) := do
  let (tag, d) ← readUInt8? d
  match tag with
  | 0 => some (none, d)
  | 1 =>
      let (value, d) ← readSome d
      some (some value, d)
  | _ => none

end Decoder

@[inline, expose]
def decodeExact? (bytes : ByteArray)
    (read : Decoder → Option (α × Decoder)) : Option α := do
  let (value, d) ← read (Decoder.ofBytes bytes)
  let _ ← d.exact
  some value

namespace Encoder

@[inline, expose]
def empty : ByteArray :=
  ByteArray.empty

@[inline, expose]
def withCapacity (capacity : Nat) : ByteArray :=
  ByteArray.emptyWithCapacity capacity

@[inline, expose]
def putUInt8 (out : ByteArray) (value : UInt8) : ByteArray :=
  Bytes.appendUInt8 out value

@[inline, expose]
def putBool (out : ByteArray) (value : Bool) : ByteArray :=
  Bytes.appendBool out value

@[inline, expose]
def putUInt16LE (out : ByteArray) (value : UInt16) : ByteArray :=
  Bytes.appendUInt16LE out value

@[inline, expose]
def putUInt32LE (out : ByteArray) (value : UInt32) : ByteArray :=
  Bytes.appendUInt32LE out value

@[inline, expose]
def putUInt64LE (out : ByteArray) (value : UInt64) : ByteArray :=
  Bytes.appendUInt64LE out value

@[inline, expose]
def putUInt128LE (out : ByteArray) (value : Nat) : ByteArray :=
  Bytes.appendUInt128LE out value

@[inline, expose]
def putUInt128LE? (out : ByteArray) (value : Nat) : Option ByteArray :=
  Bytes.appendUInt128LE? out value

@[inline, expose]
def putInt8? (out : ByteArray) (value : Int) : Option ByteArray :=
  Bytes.appendInt8? out value

@[inline, expose]
def putInt16LE? (out : ByteArray) (value : Int) : Option ByteArray :=
  Bytes.appendInt16LE? out value

@[inline, expose]
def putInt32LE? (out : ByteArray) (value : Int) : Option ByteArray :=
  Bytes.appendInt32LE? out value

@[inline, expose]
def putInt64LE? (out : ByteArray) (value : Int) : Option ByteArray :=
  Bytes.appendInt64LE? out value

@[inline, expose]
def putInt128LE? (out : ByteArray) (value : Int) : Option ByteArray :=
  Bytes.appendInt128LE? out value

@[inline, expose]
def putNatLE (out : ByteArray) (width : Nat) (value : Nat) : ByteArray :=
  Bytes.appendNatLE out width value

@[inline, expose]
def putBytes (out bytes : ByteArray) : ByteArray :=
  out.append bytes

@[inline, expose]
def putRepeated (out : ByteArray) (value : UInt8) (count : Nat) : ByteArray :=
  Bytes.appendRepeated out value count

@[inline, expose]
def putZeroPadding (out : ByteArray) (count : Nat) : ByteArray :=
  putRepeated out 0 count

@[inline, expose]
def putBytesWithLen (out bytes : ByteArray) : ByteArray :=
  putBytes (putUInt32LE out bytes.size.toUInt32) bytes

@[inline, expose]
def putString (out : ByteArray) (value : String) : ByteArray :=
  putBytesWithLen out value.toUTF8

@[inline, expose]
def putPubkey (out : ByteArray) (key : Pubkey) : ByteArray :=
  Bytes.appendPubkey out key

@[inline, expose]
def putEnumTag (out : ByteArray) (tag : UInt8) : ByteArray :=
  putUInt8 out tag

@[inline, expose]
def putArray (out : ByteArray) (values : Array α)
    (writeElem : ByteArray → α → ByteArray) : ByteArray := Id.run do
  let mut cur := out
  for value in values do
    cur := writeElem cur value
  cur

@[inline, expose]
def putVector (out : ByteArray) (values : Array α)
    (writeElem : ByteArray → α → ByteArray) : ByteArray :=
  putArray (putUInt32LE out values.size.toUInt32) values writeElem

@[inline, expose]
def putVector? (out : ByteArray) (values : Array α)
    (writeElem : ByteArray → α → Option ByteArray) : Option ByteArray := do
  let mut cur ← Bytes.appendBoundedNatLE? out 4 values.size
  for value in values do
    let next ← writeElem cur value
    cur := next
  some cur

@[inline, expose]
def putOption (out : ByteArray) (value : Option α)
    (writeSome : ByteArray → α → ByteArray) : ByteArray :=
  match value with
  | none => putUInt8 out 0
  | some value => writeSome (putUInt8 out 1) value

@[inline, expose]
def putOption? (out : ByteArray) (value : Option α)
    (writeSome : ByteArray → α → Option ByteArray) : Option ByteArray :=
  match value with
  | none => some (putUInt8 out 0)
  | some value => writeSome (putUInt8 out 1) value

end Encoder

end Borsh

namespace ProgramResult

@[inline, expose]
def decodeExact (decoder : Borsh.Decoder)
    (read : Borsh.Decoder → Option (α × Borsh.Decoder))
    (err : ProgramError) : ProgramResult α :=
  match read decoder with
  | some (value, next) =>
      if next.done then .ok value else .error err
  | none => .error err

@[inline, expose]
def decodeExactBytes (bytes : ByteArray)
    (read : Borsh.Decoder → Option (α × Borsh.Decoder))
    (err : ProgramError) : ProgramResult α :=
  decodeExact (Borsh.Decoder.ofBytes bytes) read err

end ProgramResult

/-! Anchor-compatible account-layout helpers.

This layer deliberately does not compute Anchor discriminators from type names:
programs should pass the precomputed first eight SHA-256 bytes. -/

namespace Anchor

def discriminatorLen : Nat := 8

/-- Anchor's 8-byte account/instruction discriminator. -/
structure Discriminator where
  mk ::
  bytes : ByteArray
  size_eq : bytes.size = discriminatorLen

namespace Discriminator

@[inline, expose]
def ofBytes? (bytes : ByteArray) : Option Discriminator :=
  if h : bytes.size = discriminatorLen then some ⟨bytes, h⟩ else none

@[inline, expose]
def toBytes (d : Discriminator) : ByteArray :=
  d.bytes

instance : BEq Discriminator where
  beq a b := byteArrayBEq a.bytes b.bytes

end Discriminator

@[inline, expose]
def discriminatorAt? (bytes : ByteArray) (offset : Nat) : Option Discriminator :=
  Discriminator.ofBytes? =<< Bytes.readBytesAt? bytes offset discriminatorLen

@[inline, expose]
def accountDiscriminator? (bytes : ByteArray) : Option Discriminator :=
  discriminatorAt? bytes 0

@[inline, expose]
def withDiscriminator (disc : Discriminator) (payload : ByteArray) : ByteArray :=
  disc.toBytes.append payload

@[inline, expose]
def stripDiscriminator? (expected : Discriminator) (bytes : ByteArray) : Option ByteArray := do
  let actual ← accountDiscriminator? bytes
  if actual == expected then
    Bytes.readBytesAt? bytes discriminatorLen (bytes.size - discriminatorLen)
  else
    none

@[inline, expose]
def requireDiscriminator (bytes : ByteArray) (expected : Discriminator)
    (err : ε) : Except ε Unit :=
  match accountDiscriminator? bytes with
  | some actual =>
      if actual == expected then .ok () else .error err
  | none => .error err

@[inline, expose]
def decoderAfterDiscriminator? (bytes : ByteArray)
    (expected : Discriminator) : Option Borsh.Decoder := do
  let payload ← stripDiscriminator? expected bytes
  some (Borsh.Decoder.ofBytes payload)

@[inline, expose]
def decoderAfterDiscriminator (bytes : ByteArray)
    (expected : Discriminator) (err : ε) : Except ε Borsh.Decoder :=
  match decoderAfterDiscriminator? bytes expected with
  | some d => .ok d
  | none => .error err

end Anchor

namespace FixedLayout

@[inline, expose]
def accountLen (payloadLen : Nat) (hasDiscriminator : Bool) : Nat :=
  payloadLen + if hasDiscriminator then Anchor.discriminatorLen else 0

@[inline, expose]
def requireSize (bytes : ByteArray) (len : Nat) (err : ε) : Except ε Unit :=
  if bytes.size == len then .ok () else .error err

@[inline, expose]
def requireSizeAtLeast (bytes : ByteArray) (len : Nat) (err : ε) : Except ε Unit :=
  if decide (len <= bytes.size) then .ok () else .error err

@[inline, expose]
def payloadLenWithDiscriminator (accountLen : Nat) : Nat :=
  accountLen - Anchor.discriminatorLen

end FixedLayout

/-- Snapshot of one account passed to a Solana program. Fields are read-only;
use the `ProgramContext` mutators below to write back to the loader buffer. -/
structure AccountInfo where
  key        : Pubkey
  owner      : Pubkey
  lamports   : UInt64
  data       : ByteArray
  rentEpoch  : UInt64
  isSigner   : Bool
  isWritable : Bool
  executable : Bool

/-- Structured input a typed entrypoint receives: accounts, instruction data, and program ID. -/
structure ProgramContext where
  accounts  : Array AccountInfo
  data      : ByteArray
  programId : Pubkey

/-- Per-account metadata in a CPI: target key plus access flags. -/
structure AccountMeta where
  pubkey     : Pubkey
  isWritable : Bool
  isSigner   : Bool

/-- A CPI instruction: target program, account list, and opaque data payload. -/
structure Instruction where
  programId : Pubkey
  accounts  : Array AccountMeta
  data      : ByteArray

/-- Reusable validation bundle for Anchor-style account constraints. -/
structure AccountConstraints where
  key            : Option Pubkey := none
  owner          : Option Pubkey := none
  signer         : Bool := false
  writable       : Bool := false
  executable     : Option Bool := none
  dataLenAtLeast : Nat := 0

/-- Codec for typed account data. `decodePayload` and `encodePayload` operate
on bytes after the optional Anchor discriminator. -/
structure AccountCodec (α : Type) where
  discriminator  : Option Anchor.Discriminator := none
  fixedPayloadLen : Option Nat := none
  decodePayload  : Borsh.Decoder → Option (α × Borsh.Decoder)
  encodePayload  : α → Option ByteArray

namespace AccountCodec

@[inline, expose]
def payloadOffset (codec : AccountCodec α) : Nat :=
  match codec.discriminator with
  | none => 0
  | some _ => Anchor.discriminatorLen

@[inline, expose]
def payloadLen? (codec : AccountCodec α) (data : ByteArray) : Option Nat :=
  let offset := codec.payloadOffset
  if offset <= data.size then
    some (data.size - offset)
  else
    none

@[inline, expose]
def checkFixedPayloadLen? (codec : AccountCodec α) (payload : ByteArray) : Option Unit :=
  match codec.fixedPayloadLen with
  | none => some ()
  | some len => if payload.size == len then some () else none

@[inline, expose]
def payloadBytes? (codec : AccountCodec α) (data : ByteArray) : Option ByteArray := do
  match codec.discriminator with
  | none => pure ()
  | some disc =>
      match Anchor.requireDiscriminator data disc () with
      | .ok () => pure ()
      | .error () => none
  let offset := codec.payloadOffset
  let len ← codec.payloadLen? data
  let payload ← Bytes.readBytesAt? data offset len
  let _ ← codec.checkFixedPayloadLen? payload
  some payload

@[inline, expose]
def decode? (codec : AccountCodec α) (data : ByteArray) : Option α := do
  let payload ← codec.payloadBytes? data
  Borsh.decodeExact? payload codec.decodePayload

@[inline, expose]
def decodeOr (codec : AccountCodec α) (data : ByteArray) (err : ε) : Except ε α :=
  match codec.decode? data with
  | some value => .ok value
  | none => .error err

@[inline, expose]
def encode? (codec : AccountCodec α) (value : α) : Option ByteArray := do
  let payload ← codec.encodePayload value
  let _ ← codec.checkFixedPayloadLen? payload
  match codec.discriminator with
  | none => some payload
  | some disc => some (Anchor.withDiscriminator disc payload)

@[inline, expose]
def encodeOr (codec : AccountCodec α) (value : α) (err : ε) : Except ε ByteArray :=
  match codec.encode? value with
  | some bytes => .ok bytes
  | none => .error err

end AccountCodec

/-- A typed view of an account at a specific index. -/
structure LoadedAccount (α : Type) where
  index   : Nat
  account : AccountInfo
  value   : α

/-! Sysvar account layouts. These helpers decode sysvars that were passed as
ordinary accounts, which keeps them usable without adding new runtime syscall
surface area. -/

namespace Sysvar

namespace Clock

/-- `SysvarC1ock11111111111111111111111111111111`. -/
@[inline, expose]
def id : Pubkey :=
  { bytes := ByteArray.mk #[
      6, 167, 213, 23, 24, 199, 116, 201,
      40, 86, 99, 152, 105, 29, 94, 182,
      139, 94, 184, 163, 155, 75, 109, 92,
      115, 85, 91, 33, 0, 0, 0, 0]
    size_eq := by native_decide }

@[extern "lean_sbf_get_clock_sysvar", never_extract]
opaque getBytesImpl (_ : UInt64) : Option ByteArray

end Clock

structure Clock where
  slot                : UInt64
  epochStartTimestamp : Int
  epoch               : UInt64
  leaderScheduleEpoch : UInt64
  unixTimestamp       : Int

namespace Clock

def dataLen : Nat := 40

@[inline, expose]
def decodePayload (d : Borsh.Decoder) : Option (Clock × Borsh.Decoder) := do
  let (slot, d) ← Borsh.Decoder.readUInt64LE? d
  let (epochStartTimestamp, d) ← Borsh.Decoder.readInt64LE? d
  let (epoch, d) ← Borsh.Decoder.readUInt64LE? d
  let (leaderScheduleEpoch, d) ← Borsh.Decoder.readUInt64LE? d
  let (unixTimestamp, d) ← Borsh.Decoder.readInt64LE? d
  some ({ slot, epochStartTimestamp, epoch, leaderScheduleEpoch, unixTimestamp }, d)

@[inline, expose]
def decode? (data : ByteArray) : Option Clock :=
  Borsh.decodeExact? data decodePayload

@[inline, expose]
def get? (nonce : UInt64 := 0) : Option Clock := do
  let bytes ← getBytesImpl nonce
  decode? bytes

@[inline, expose]
def get (nonce : UInt64 := 0)
    (err : ProgramError := ProgramError.invalidAccountData) :
    ProgramResult Clock :=
  ProgramResult.fromOption (get? nonce) err

@[inline, expose]
def fromAccount? (account : AccountInfo) : Option Clock :=
  if account.key == id then
    decode? account.data
  else
    none

@[inline, expose]
def fromAccount (account : AccountInfo)
    (err : ProgramError := ProgramError.invalidAccountData) : ProgramResult Clock :=
  ProgramResult.fromOption (fromAccount? account) err

end Clock

namespace Rent

/-- `SysvarRent111111111111111111111111111111111`. -/
@[inline, expose]
def id : Pubkey :=
  { bytes := ByteArray.mk #[
      6, 167, 213, 23, 25, 44, 92, 81,
      33, 140, 201, 76, 61, 74, 241, 127,
      88, 218, 238, 8, 155, 161, 253, 68,
      227, 219, 217, 138, 0, 0, 0, 0]
    size_eq := by native_decide }

end Rent

/-- Solana rent sysvar. The exemption threshold is kept as raw f64 bits so the
library does not depend on floating-point runtime support on SBF. -/
structure Rent where
  lamportsPerByteYear  : UInt64
  exemptionThresholdBits : UInt64
  burnPercent          : UInt8

namespace Rent

def dataLen : Nat := 17

def twoYearExemptionNumerator : UInt64 := 2
def twoYearExemptionDenominator : UInt64 := 1

@[inline, expose]
def decodePayload (d : Borsh.Decoder) : Option (Rent × Borsh.Decoder) := do
  let (lamportsPerByteYear, d) ← Borsh.Decoder.readUInt64LE? d
  let (exemptionThresholdBits, d) ← Borsh.Decoder.readUInt64LE? d
  let (burnPercent, d) ← Borsh.Decoder.readUInt8? d
  some ({ lamportsPerByteYear, exemptionThresholdBits, burnPercent }, d)

@[inline, expose]
def decode? (data : ByteArray) : Option Rent :=
  Borsh.decodeExact? data decodePayload

@[inline, expose]
def checkedUInt64? (value : Nat) : Option UInt64 :=
  if value < 2 ^ 64 then
    some value.toUInt64
  else
    none

@[inline, expose]
def minimumBalanceForExemption? (lamportsPerByteYear dataLen yearsNumerator
    yearsDenominator : UInt64) : Option UInt64 :=
  if yearsDenominator == 0 then
    none
  else
    let numerator :=
      lamportsPerByteYear.toNat * dataLen.toNat * yearsNumerator.toNat
    let denominator := yearsDenominator.toNat
    checkedUInt64? ((numerator + denominator - 1) / denominator)

@[inline, expose]
def minimumBalanceDefault? (rent : Rent) (dataLen : UInt64) : Option UInt64 :=
  minimumBalanceForExemption? rent.lamportsPerByteYear dataLen
    twoYearExemptionNumerator twoYearExemptionDenominator

@[inline, expose]
def isExemptWithMinimum (lamports minimumBalance : UInt64) : Bool :=
  minimumBalance <= lamports

@[inline, expose]
def requireExemptWithMinimum (lamports minimumBalance : UInt64)
    (err : ε) : Except ε Unit :=
  if isExemptWithMinimum lamports minimumBalance then .ok () else .error err

@[inline, expose]
def fromAccount? (account : AccountInfo) : Option Rent :=
  if account.key == id then
    decode? account.data
  else
    none

@[inline, expose]
def fromAccount (account : AccountInfo)
    (err : ProgramError := ProgramError.invalidAccountData) : ProgramResult Rent :=
  ProgramResult.fromOption (fromAccount? account) err

end Rent

end Sysvar

namespace AccountInfo

@[inline, expose]
def dataSize (account : AccountInfo) : Nat :=
  account.data.size

@[inline, expose]
def hasKey (account : AccountInfo) (key : Pubkey) : Bool :=
  account.key == key

@[inline, expose]
def hasOwner (account : AccountInfo) (owner : Pubkey) : Bool :=
  account.owner == owner

@[inline, expose]
def hasDataLenAtLeast (account : AccountInfo) (len : Nat) : Bool :=
  decide (len <= account.data.size)

@[inline, expose]
def requireSigner (account : AccountInfo) (err : ε) : Except ε Unit :=
  if account.isSigner then .ok () else .error err

@[inline, expose]
def requireWritable (account : AccountInfo) (err : ε) : Except ε Unit :=
  if account.isWritable then .ok () else .error err

@[inline, expose]
def requireExecutable (account : AccountInfo) (err : ε) : Except ε Unit :=
  if account.executable then .ok () else .error err

@[inline, expose]
def requireKey (account : AccountInfo) (key : Pubkey) (err : ε) : Except ε Unit :=
  if account.hasKey key then .ok () else .error err

@[inline, expose]
def requireOwner (account : AccountInfo) (owner : Pubkey) (err : ε) : Except ε Unit :=
  if account.hasOwner owner then .ok () else .error err

@[inline, expose]
def requireDataLenAtLeast (account : AccountInfo) (len : Nat) (err : ε) : Except ε Unit :=
  if account.hasDataLenAtLeast len then .ok () else .error err

@[inline, expose]
def validate (account : AccountInfo) (constraints : AccountConstraints)
    (err : ε) : Except ε Unit := do
  match constraints.key with
  | none => pure ()
  | some key => account.requireKey key err
  match constraints.owner with
  | none => pure ()
  | some owner => account.requireOwner owner err
  if constraints.signer then
    account.requireSigner err
  else
    pure ()
  if constraints.writable then
    account.requireWritable err
  else
    pure ()
  match constraints.executable with
  | none => pure ()
  | some expected =>
      if account.executable == expected then .ok () else .error err
  account.requireDataLenAtLeast constraints.dataLenAtLeast err

@[inline, expose]
def requireDiscriminator (account : AccountInfo)
    (expected : Anchor.Discriminator) (err : ε) : Except ε Unit :=
  Anchor.requireDiscriminator account.data expected err

@[inline, expose]
def dataDecoder (account : AccountInfo) : Borsh.Decoder :=
  Borsh.Decoder.ofBytes account.data

@[inline, expose]
def decodeWith? (account : AccountInfo) (codec : AccountCodec α) : Option α :=
  codec.decode? account.data

@[inline, expose]
def decodeWith (account : AccountInfo) (codec : AccountCodec α) (err : ε) : Except ε α :=
  codec.decodeOr account.data err

@[inline, expose]
def payloadDecoderAfterDiscriminator (account : AccountInfo)
    (expected : Anchor.Discriminator) (err : ε) : Except ε Borsh.Decoder :=
  Anchor.decoderAfterDiscriminator account.data expected err

end AccountInfo

namespace AccountMeta

@[inline, expose]
def readonly (pubkey : Pubkey) : AccountMeta :=
  { pubkey, isWritable := false, isSigner := false }

@[inline, expose]
def writable (pubkey : Pubkey) : AccountMeta :=
  { pubkey, isWritable := true, isSigner := false }

@[inline, expose]
def readonlySigner (pubkey : Pubkey) : AccountMeta :=
  { pubkey, isWritable := false, isSigner := true }

@[inline, expose]
def writableSigner (pubkey : Pubkey) : AccountMeta :=
  { pubkey, isWritable := true, isSigner := true }

end AccountMeta

namespace Instruction

@[inline, expose]
def new (programId : Pubkey) (accounts : Array AccountMeta) (data : ByteArray) : Instruction :=
  { programId, accounts, data }

end Instruction

namespace InstructionData

@[inline, expose]
def decoder (data : ByteArray) : Borsh.Decoder :=
  Borsh.Decoder.ofBytes data

@[inline, expose]
def tag? (data : ByteArray) : Option (UInt8 × Borsh.Decoder) :=
  Borsh.Decoder.readUInt8? (decoder data)

@[inline, expose]
def anchorDiscriminator? (data : ByteArray) : Option Anchor.Discriminator :=
  Anchor.accountDiscriminator? data

@[inline, expose]
def anchorPayloadDecoder? (data : ByteArray)
    (expected : Anchor.Discriminator) : Option Borsh.Decoder :=
  Anchor.decoderAfterDiscriminator? data expected

end InstructionData

namespace Dispatch

abbrev Handler (α : Type) := Borsh.Decoder → ProgramResult α

structure TagCase (α : Type) where
  tag : UInt8
  run : Handler α

structure AnchorCase (α : Type) where
  discriminator : Anchor.Discriminator
  run : Handler α

@[inline, expose]
def exact (read : Borsh.Decoder → Option (α × Borsh.Decoder))
    (err : ProgramError := ProgramError.invalidInstructionData) : Handler α :=
  fun decoder => ProgramResult.decodeExact decoder read err

@[inline, expose]
def findTag? (cases : Array (TagCase α)) (tag : UInt8) : Option (Handler α) := Id.run do
  for c in cases do
    if c.tag == tag then
      return some c.run
  return none

@[inline, expose]
def findAnchor? (cases : Array (AnchorCase α))
    (disc : Anchor.Discriminator) : Option (Handler α) := Id.run do
  for c in cases do
    if c.discriminator == disc then
      return some c.run
  return none

@[inline, expose]
def byTag (data : ByteArray) (cases : Array (TagCase α))
    (unknownErr : ProgramError := ProgramError.unsupportedInstruction)
    (decodeErr : ProgramError := ProgramError.invalidInstructionData) : ProgramResult α :=
  match InstructionData.tag? data with
  | none => .error decodeErr
  | some (tag, decoder) =>
      match findTag? cases tag with
      | none => .error unknownErr
      | some handler => handler decoder

@[inline, expose]
def byAnchor (data : ByteArray) (cases : Array (AnchorCase α))
    (unknownErr : ProgramError := ProgramError.unsupportedInstruction)
    (decodeErr : ProgramError := ProgramError.invalidInstructionData) : ProgramResult α :=
  match InstructionData.anchorDiscriminator? data with
  | none => .error decodeErr
  | some disc =>
      match findAnchor? cases disc with
      | none => .error unknownErr
      | some handler =>
          match InstructionData.anchorPayloadDecoder? data disc with
          | some decoder => handler decoder
          | none => .error decodeErr

@[inline, expose]
def toReturnCode (dispatch : ByteArray → ProgramResult Unit)
    (data : ByteArray) : UInt64 :=
  ProgramResult.toReturnCode (dispatch data)

@[inline, expose]
def toReturnCodeWith (dispatch : ByteArray → ProgramResult α)
    (ok : α → UInt64) (data : ByteArray) : UInt64 :=
  ProgramResult.toReturnCodeWith ok (dispatch data)

end Dispatch

@[extern "lean_sbf_invoke_signed", never_extract]
opaque invokeSignedImpl
  (instruction : @&Instruction)
  (signers : @&Array (Array ByteArray))
  : Unit

/-- CPI without PDA signer seeds. -/
def invoke (inst : Instruction) : BaseIO Unit :=
  pure (invokeSignedImpl inst (Array.empty))

/-- CPI with PDA signer seeds (one inner array per signer). -/
def invokeSigned (inst : Instruction) (signers : Array (Array ByteArray)) : BaseIO Unit :=
  pure (invokeSignedImpl inst signers)

namespace SystemProgram

/-- `11111111111111111111111111111111`. -/
@[inline, expose]
def id : Pubkey :=
  { bytes := ByteArray.mk #[
      0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0]
    size_eq := by native_decide }

@[inline, expose]
def createAccountData (lamports space : UInt64) (owner : Pubkey) : ByteArray :=
  Id.run do
    let mut out := Borsh.Encoder.withCapacity 52
    out := Borsh.Encoder.putUInt32LE out 0
    out := Borsh.Encoder.putUInt64LE out lamports
    out := Borsh.Encoder.putUInt64LE out space
    out := Borsh.Encoder.putPubkey out owner
    out

@[inline, expose]
def assignData (owner : Pubkey) : ByteArray :=
  Id.run do
    let mut out := Borsh.Encoder.withCapacity 36
    out := Borsh.Encoder.putUInt32LE out 1
    out := Borsh.Encoder.putPubkey out owner
    out

@[inline, expose]
def transferData (lamports : UInt64) : ByteArray :=
  Id.run do
    let mut out := Borsh.Encoder.withCapacity 12
    out := Borsh.Encoder.putUInt32LE out 2
    out := Borsh.Encoder.putUInt64LE out lamports
    out

@[inline, expose]
def allocateData (space : UInt64) : ByteArray :=
  Id.run do
    let mut out := Borsh.Encoder.withCapacity 12
    out := Borsh.Encoder.putUInt32LE out 8
    out := Borsh.Encoder.putUInt64LE out space
    out

@[inline, expose]
def createAccountInstruction (payer newAccount : Pubkey) (lamports space : UInt64)
    (owner : Pubkey) : Instruction :=
  Instruction.new id
    #[AccountMeta.writableSigner payer, AccountMeta.writableSigner newAccount]
    (createAccountData lamports space owner)

@[inline, expose]
def assignInstruction (account owner : Pubkey) : Instruction :=
  Instruction.new id
    #[AccountMeta.writableSigner account]
    (assignData owner)

@[inline, expose]
def transferInstruction (source destination : Pubkey) (lamports : UInt64) : Instruction :=
  Instruction.new id
    #[AccountMeta.writableSigner source, AccountMeta.writable destination]
    (transferData lamports)

@[inline, expose]
def allocateInstruction (account : Pubkey) (space : UInt64) : Instruction :=
  Instruction.new id
    #[AccountMeta.writableSigner account]
    (allocateData space)

@[inline, expose]
def createAccountSigned (payer newAccount : Pubkey) (lamports space : UInt64)
    (owner : Pubkey) (signers : Array (Array ByteArray)) : BaseIO Unit :=
  invokeSigned (createAccountInstruction payer newAccount lamports space owner) signers

@[inline, expose]
def createAccount (payer newAccount : Pubkey) (lamports space : UInt64)
    (owner : Pubkey) : BaseIO Unit :=
  invoke (createAccountInstruction payer newAccount lamports space owner)

@[inline, expose]
def assignSigned (account owner : Pubkey)
    (signers : Array (Array ByteArray)) : BaseIO Unit :=
  invokeSigned (assignInstruction account owner) signers

@[inline, expose]
def assign (account owner : Pubkey) : BaseIO Unit :=
  invoke (assignInstruction account owner)

@[inline, expose]
def transferSigned (source destination : Pubkey) (lamports : UInt64)
    (signers : Array (Array ByteArray)) : BaseIO Unit :=
  invokeSigned (transferInstruction source destination lamports) signers

@[inline, expose]
def transfer (source destination : Pubkey) (lamports : UInt64) : BaseIO Unit :=
  invoke (transferInstruction source destination lamports)

@[inline, expose]
def allocateSigned (account : Pubkey) (space : UInt64)
    (signers : Array (Array ByteArray)) : BaseIO Unit :=
  invokeSigned (allocateInstruction account space) signers

@[inline, expose]
def allocate (account : Pubkey) (space : UInt64) : BaseIO Unit :=
  invoke (allocateInstruction account space)

end SystemProgram

namespace TokenProgram

/-- Canonical SPL Token program: `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA`. -/
@[inline, expose]
def id : Pubkey :=
  { bytes := ByteArray.mk #[
      6, 221, 246, 225, 215, 101, 161, 147,
      217, 203, 225, 70, 206, 235, 121, 172,
      28, 180, 133, 237, 95, 91, 55, 145,
      58, 140, 245, 133, 126, 255, 0, 169]
    size_eq := by native_decide }

/-- Token-2022 program: `TokenzQdBNbLqP5VEhdkAS6EPF5M3bFpNYEJ7tV5QFh`. -/
@[inline, expose]
def token2022Id : Pubkey :=
  { bytes := ByteArray.mk #[
      6, 221, 246, 225, 238, 117, 143, 222,
      24, 66, 93, 188, 228, 108, 205, 218,
      182, 26, 252, 74, 113, 26, 172, 45,
      92, 82, 141, 194, 45, 90, 77, 208]
    size_eq := by native_decide }

/-- Wrapped SOL mint: `So11111111111111111111111111111111111111112`. -/
@[inline, expose]
def nativeMint : Pubkey :=
  { bytes := ByteArray.mk #[
      6, 155, 136, 87, 254, 171, 129, 132,
      251, 104, 127, 99, 70, 24, 192, 53,
      218, 196, 57, 220, 26, 235, 59, 85,
      152, 160, 240, 0, 0, 0, 0, 1]
    size_eq := by native_decide }

def transferTag : UInt8 := 3
def approveTag : UInt8 := 4
def revokeTag : UInt8 := 5
def mintToTag : UInt8 := 7
def burnTag : UInt8 := 8
def closeAccountTag : UInt8 := 9
def freezeAccountTag : UInt8 := 10
def thawAccountTag : UInt8 := 11
def transferCheckedTag : UInt8 := 12
def approveCheckedTag : UInt8 := 13
def mintToCheckedTag : UInt8 := 14
def burnCheckedTag : UInt8 := 15
def syncNativeTag : UInt8 := 17
def initializeAccount3Tag : UInt8 := 18
def initializeImmutableOwnerTag : UInt8 := 22

@[inline, expose]
def amountData (tag : UInt8) (amount : UInt64) : ByteArray :=
  Id.run do
    let mut out := Borsh.Encoder.withCapacity 9
    out := Borsh.Encoder.putUInt8 out tag
    out := Borsh.Encoder.putUInt64LE out amount
    out

@[inline, expose]
def checkedAmountData (tag : UInt8) (amount : UInt64) (decimals : UInt8) : ByteArray :=
  Id.run do
    let mut out := Borsh.Encoder.withCapacity 10
    out := Borsh.Encoder.putUInt8 out tag
    out := Borsh.Encoder.putUInt64LE out amount
    out := Borsh.Encoder.putUInt8 out decimals
    out

@[inline, expose]
def emptyData (tag : UInt8) : ByteArray :=
  (ByteArray.emptyWithCapacity 1).push tag

@[inline, expose]
def ownerData (tag : UInt8) (owner : Pubkey) : ByteArray :=
  Id.run do
    let mut out := Borsh.Encoder.withCapacity 33
    out := Borsh.Encoder.putUInt8 out tag
    out := Borsh.Encoder.putPubkey out owner
    out

@[inline, expose]
def authorityMetas (authority : Pubkey) (extraSigners : Array Pubkey) : Array AccountMeta :=
  if extraSigners.isEmpty then
    #[AccountMeta.readonlySigner authority]
  else
    Id.run do
      let mut metas := #[AccountMeta.readonly authority]
      for signer in extraSigners do
        metas := metas.push (AccountMeta.readonlySigner signer)
      metas

@[inline, expose]
def transferData (amount : UInt64) : ByteArray :=
  amountData transferTag amount

@[inline, expose]
def approveData (amount : UInt64) : ByteArray :=
  amountData approveTag amount

@[inline, expose]
def mintToData (amount : UInt64) : ByteArray :=
  amountData mintToTag amount

@[inline, expose]
def burnData (amount : UInt64) : ByteArray :=
  amountData burnTag amount

@[inline, expose]
def transferCheckedData (amount : UInt64) (decimals : UInt8) : ByteArray :=
  checkedAmountData transferCheckedTag amount decimals

@[inline, expose]
def approveCheckedData (amount : UInt64) (decimals : UInt8) : ByteArray :=
  checkedAmountData approveCheckedTag amount decimals

@[inline, expose]
def mintToCheckedData (amount : UInt64) (decimals : UInt8) : ByteArray :=
  checkedAmountData mintToCheckedTag amount decimals

@[inline, expose]
def burnCheckedData (amount : UInt64) (decimals : UInt8) : ByteArray :=
  checkedAmountData burnCheckedTag amount decimals

@[inline, expose]
def transferInstructionWithProgram (programId source destination authority : Pubkey)
    (amount : UInt64) (extraSigners : Array Pubkey := #[]) : Instruction :=
  Instruction.new programId
    (#[AccountMeta.writable source, AccountMeta.writable destination]
      ++ authorityMetas authority extraSigners)
    (transferData amount)

@[inline, expose]
def transferInstruction (source destination authority : Pubkey) (amount : UInt64)
    (extraSigners : Array Pubkey := #[]) : Instruction :=
  transferInstructionWithProgram id source destination authority amount extraSigners

@[inline, expose]
def approveInstructionWithProgram (programId source delegate owner : Pubkey)
    (amount : UInt64) (extraSigners : Array Pubkey := #[]) : Instruction :=
  Instruction.new programId
    (#[AccountMeta.writable source, AccountMeta.readonly delegate]
      ++ authorityMetas owner extraSigners)
    (approveData amount)

@[inline, expose]
def approveInstruction (source delegate owner : Pubkey) (amount : UInt64)
    (extraSigners : Array Pubkey := #[]) : Instruction :=
  approveInstructionWithProgram id source delegate owner amount extraSigners

@[inline, expose]
def revokeInstructionWithProgram (programId source owner : Pubkey)
    (extraSigners : Array Pubkey := #[]) : Instruction :=
  Instruction.new programId
    (#[AccountMeta.writable source] ++ authorityMetas owner extraSigners)
    (emptyData revokeTag)

@[inline, expose]
def revokeInstruction (source owner : Pubkey)
    (extraSigners : Array Pubkey := #[]) : Instruction :=
  revokeInstructionWithProgram id source owner extraSigners

@[inline, expose]
def mintToInstructionWithProgram (programId mint destination authority : Pubkey)
    (amount : UInt64) (extraSigners : Array Pubkey := #[]) : Instruction :=
  Instruction.new programId
    (#[AccountMeta.writable mint, AccountMeta.writable destination]
      ++ authorityMetas authority extraSigners)
    (mintToData amount)

@[inline, expose]
def mintToInstruction (mint destination authority : Pubkey) (amount : UInt64)
    (extraSigners : Array Pubkey := #[]) : Instruction :=
  mintToInstructionWithProgram id mint destination authority amount extraSigners

@[inline, expose]
def burnInstructionWithProgram (programId account mint authority : Pubkey)
    (amount : UInt64) (extraSigners : Array Pubkey := #[]) : Instruction :=
  Instruction.new programId
    (#[AccountMeta.writable account, AccountMeta.writable mint]
      ++ authorityMetas authority extraSigners)
    (burnData amount)

@[inline, expose]
def burnInstruction (account mint authority : Pubkey) (amount : UInt64)
    (extraSigners : Array Pubkey := #[]) : Instruction :=
  burnInstructionWithProgram id account mint authority amount extraSigners

@[inline, expose]
def closeAccountInstructionWithProgram (programId account destination authority : Pubkey)
    (extraSigners : Array Pubkey := #[]) : Instruction :=
  Instruction.new programId
    (#[AccountMeta.writable account, AccountMeta.writable destination]
      ++ authorityMetas authority extraSigners)
    (emptyData closeAccountTag)

@[inline, expose]
def closeAccountInstruction (account destination authority : Pubkey)
    (extraSigners : Array Pubkey := #[]) : Instruction :=
  closeAccountInstructionWithProgram id account destination authority extraSigners

@[inline, expose]
def freezeAccountInstructionWithProgram (programId account mint authority : Pubkey)
    (extraSigners : Array Pubkey := #[]) : Instruction :=
  Instruction.new programId
    (#[AccountMeta.writable account, AccountMeta.readonly mint]
      ++ authorityMetas authority extraSigners)
    (emptyData freezeAccountTag)

@[inline, expose]
def freezeAccountInstruction (account mint authority : Pubkey)
    (extraSigners : Array Pubkey := #[]) : Instruction :=
  freezeAccountInstructionWithProgram id account mint authority extraSigners

@[inline, expose]
def thawAccountInstructionWithProgram (programId account mint authority : Pubkey)
    (extraSigners : Array Pubkey := #[]) : Instruction :=
  Instruction.new programId
    (#[AccountMeta.writable account, AccountMeta.readonly mint]
      ++ authorityMetas authority extraSigners)
    (emptyData thawAccountTag)

@[inline, expose]
def thawAccountInstruction (account mint authority : Pubkey)
    (extraSigners : Array Pubkey := #[]) : Instruction :=
  thawAccountInstructionWithProgram id account mint authority extraSigners

@[inline, expose]
def transferCheckedInstructionWithProgram (programId source mint destination authority : Pubkey)
    (amount : UInt64) (decimals : UInt8) (extraSigners : Array Pubkey := #[]) : Instruction :=
  Instruction.new programId
    (#[AccountMeta.writable source, AccountMeta.readonly mint, AccountMeta.writable destination]
      ++ authorityMetas authority extraSigners)
    (transferCheckedData amount decimals)

@[inline, expose]
def transferCheckedInstruction (source mint destination authority : Pubkey)
    (amount : UInt64) (decimals : UInt8) (extraSigners : Array Pubkey := #[]) : Instruction :=
  transferCheckedInstructionWithProgram id source mint destination authority amount decimals extraSigners

@[inline, expose]
def approveCheckedInstructionWithProgram (programId source mint delegate owner : Pubkey)
    (amount : UInt64) (decimals : UInt8) (extraSigners : Array Pubkey := #[]) : Instruction :=
  Instruction.new programId
    (#[AccountMeta.writable source, AccountMeta.readonly mint, AccountMeta.readonly delegate]
      ++ authorityMetas owner extraSigners)
    (approveCheckedData amount decimals)

@[inline, expose]
def approveCheckedInstruction (source mint delegate owner : Pubkey)
    (amount : UInt64) (decimals : UInt8) (extraSigners : Array Pubkey := #[]) : Instruction :=
  approveCheckedInstructionWithProgram id source mint delegate owner amount decimals extraSigners

@[inline, expose]
def mintToCheckedInstructionWithProgram (programId mint destination authority : Pubkey)
    (amount : UInt64) (decimals : UInt8) (extraSigners : Array Pubkey := #[]) : Instruction :=
  Instruction.new programId
    (#[AccountMeta.writable mint, AccountMeta.writable destination]
      ++ authorityMetas authority extraSigners)
    (mintToCheckedData amount decimals)

@[inline, expose]
def mintToCheckedInstruction (mint destination authority : Pubkey)
    (amount : UInt64) (decimals : UInt8) (extraSigners : Array Pubkey := #[]) : Instruction :=
  mintToCheckedInstructionWithProgram id mint destination authority amount decimals extraSigners

@[inline, expose]
def burnCheckedInstructionWithProgram (programId account mint authority : Pubkey)
    (amount : UInt64) (decimals : UInt8) (extraSigners : Array Pubkey := #[]) : Instruction :=
  Instruction.new programId
    (#[AccountMeta.writable account, AccountMeta.writable mint]
      ++ authorityMetas authority extraSigners)
    (burnCheckedData amount decimals)

@[inline, expose]
def burnCheckedInstruction (account mint authority : Pubkey)
    (amount : UInt64) (decimals : UInt8) (extraSigners : Array Pubkey := #[]) : Instruction :=
  burnCheckedInstructionWithProgram id account mint authority amount decimals extraSigners

@[inline, expose]
def syncNativeInstructionWithProgram (programId account : Pubkey) : Instruction :=
  Instruction.new programId #[AccountMeta.writable account] (emptyData syncNativeTag)

@[inline, expose]
def syncNativeInstruction (account : Pubkey) : Instruction :=
  syncNativeInstructionWithProgram id account

@[inline, expose]
def initializeAccount3InstructionWithProgram (programId account mint owner : Pubkey) : Instruction :=
  Instruction.new programId
    #[AccountMeta.writable account, AccountMeta.readonly mint]
    (ownerData initializeAccount3Tag owner)

@[inline, expose]
def initializeAccount3Instruction (account mint owner : Pubkey) : Instruction :=
  initializeAccount3InstructionWithProgram id account mint owner

@[inline, expose]
def initializeImmutableOwnerInstructionWithProgram (programId account : Pubkey) : Instruction :=
  Instruction.new programId
    #[AccountMeta.writable account]
    (emptyData initializeImmutableOwnerTag)

@[inline, expose]
def initializeImmutableOwnerInstruction (account : Pubkey) : Instruction :=
  initializeImmutableOwnerInstructionWithProgram id account

@[inline, expose]
def transferSignedWithProgram (programId source destination authority : Pubkey)
    (amount : UInt64) (signers : Array (Array ByteArray)) : BaseIO Unit :=
  invokeSigned (transferInstructionWithProgram programId source destination authority amount) signers

@[inline, expose]
def transferSigned (source destination authority : Pubkey) (amount : UInt64)
    (signers : Array (Array ByteArray)) : BaseIO Unit :=
  transferSignedWithProgram id source destination authority amount signers

@[inline, expose]
def transfer (source destination authority : Pubkey) (amount : UInt64) : BaseIO Unit :=
  transferSigned source destination authority amount Array.empty

@[inline, expose]
def transferCheckedSignedWithProgram (programId source mint destination authority : Pubkey)
    (amount : UInt64) (decimals : UInt8) (signers : Array (Array ByteArray)) : BaseIO Unit :=
  invokeSigned
    (transferCheckedInstructionWithProgram programId source mint destination authority amount decimals)
    signers

@[inline, expose]
def transferCheckedSigned (source mint destination authority : Pubkey)
    (amount : UInt64) (decimals : UInt8) (signers : Array (Array ByteArray)) : BaseIO Unit :=
  transferCheckedSignedWithProgram id source mint destination authority amount decimals signers

@[inline, expose]
def transferChecked (source mint destination authority : Pubkey)
    (amount : UInt64) (decimals : UInt8) : BaseIO Unit :=
  transferCheckedSigned source mint destination authority amount decimals Array.empty

@[inline, expose]
def mintToSignedWithProgram (programId mint destination authority : Pubkey)
    (amount : UInt64) (signers : Array (Array ByteArray)) : BaseIO Unit :=
  invokeSigned (mintToInstructionWithProgram programId mint destination authority amount) signers

@[inline, expose]
def mintToSigned (mint destination authority : Pubkey) (amount : UInt64)
    (signers : Array (Array ByteArray)) : BaseIO Unit :=
  mintToSignedWithProgram id mint destination authority amount signers

@[inline, expose]
def mintTo (mint destination authority : Pubkey) (amount : UInt64) : BaseIO Unit :=
  mintToSigned mint destination authority amount Array.empty

@[inline, expose]
def burnSignedWithProgram (programId account mint authority : Pubkey)
    (amount : UInt64) (signers : Array (Array ByteArray)) : BaseIO Unit :=
  invokeSigned (burnInstructionWithProgram programId account mint authority amount) signers

@[inline, expose]
def burnSigned (account mint authority : Pubkey) (amount : UInt64)
    (signers : Array (Array ByteArray)) : BaseIO Unit :=
  burnSignedWithProgram id account mint authority amount signers

@[inline, expose]
def burn (account mint authority : Pubkey) (amount : UInt64) : BaseIO Unit :=
  burnSigned account mint authority amount Array.empty

@[inline, expose]
def closeAccountSignedWithProgram (programId account destination authority : Pubkey)
    (signers : Array (Array ByteArray)) : BaseIO Unit :=
  invokeSigned (closeAccountInstructionWithProgram programId account destination authority) signers

@[inline, expose]
def closeAccountSigned (account destination authority : Pubkey)
    (signers : Array (Array ByteArray)) : BaseIO Unit :=
  closeAccountSignedWithProgram id account destination authority signers

@[inline, expose]
def closeAccount (account destination authority : Pubkey) : BaseIO Unit :=
  closeAccountSigned account destination authority Array.empty

end TokenProgram

namespace Token

namespace COption

@[inline, expose]
def readPubkey? (d : Borsh.Decoder) : Option (Option Pubkey × Borsh.Decoder) := do
  let (tag, d) ← Borsh.Decoder.readUInt32LE? d
  let (key, d) ← Borsh.Decoder.readPubkey? d
  match tag with
  | 0 => some (none, d)
  | 1 => some (some key, d)
  | _ => none

@[inline, expose]
def readUInt64? (d : Borsh.Decoder) : Option (Option UInt64 × Borsh.Decoder) := do
  let (tag, d) ← Borsh.Decoder.readUInt32LE? d
  let (value, d) ← Borsh.Decoder.readUInt64LE? d
  match tag with
  | 0 => some (none, d)
  | 1 => some (some value, d)
  | _ => none

@[inline, expose]
def putPubkey (out : ByteArray) : Option Pubkey → ByteArray
  | none => Borsh.Encoder.putRepeated (Borsh.Encoder.putUInt32LE out 0) 0 32
  | some key => Borsh.Encoder.putPubkey (Borsh.Encoder.putUInt32LE out 1) key

@[inline, expose]
def putUInt64 (out : ByteArray) : Option UInt64 → ByteArray
  | none => Borsh.Encoder.putUInt64LE (Borsh.Encoder.putUInt32LE out 0) 0
  | some value => Borsh.Encoder.putUInt64LE (Borsh.Encoder.putUInt32LE out 1) value

end COption

inductive AccountState where
  | uninitialized
  | initialized
  | frozen
  deriving DecidableEq, BEq

namespace AccountState

@[inline, expose]
def decode? : UInt8 → Option AccountState
  | 0 => some .uninitialized
  | 1 => some .initialized
  | 2 => some .frozen
  | _ => none

@[inline, expose]
def toUInt8 : AccountState → UInt8
  | .uninitialized => 0
  | .initialized => 1
  | .frozen => 2

end AccountState

structure Mint where
  mintAuthority : Option Pubkey
  supply        : UInt64
  decimals      : UInt8
  isInitialized : Bool
  freezeAuthority : Option Pubkey

namespace Mint

def dataLen : Nat := 82

@[inline, expose]
def decodePayload (d : Borsh.Decoder) : Option (Mint × Borsh.Decoder) := do
  let (mintAuthority, d) ← COption.readPubkey? d
  let (supply, d) ← Borsh.Decoder.readUInt64LE? d
  let (decimals, d) ← Borsh.Decoder.readUInt8? d
  let (isInitialized, d) ← Borsh.Decoder.readBool? d
  let (freezeAuthority, d) ← COption.readPubkey? d
  some ({ mintAuthority, supply, decimals, isInitialized, freezeAuthority }, d)

@[inline, expose]
def decode? (data : ByteArray) : Option Mint :=
  Borsh.decodeExact? data decodePayload

@[inline, expose]
def fromAccount? (account : AccountInfo) : Option Mint :=
  if account.owner == TokenProgram.id || account.owner == TokenProgram.token2022Id then
    decode? account.data
  else
    none

@[inline, expose]
def fromAccount (account : AccountInfo)
    (err : ProgramError := ProgramError.invalidAccountData) : ProgramResult Mint :=
  ProgramResult.fromOption (fromAccount? account) err

end Mint

structure Account where
  mint            : Pubkey
  owner           : Pubkey
  amount          : UInt64
  delegate        : Option Pubkey
  state           : AccountState
  isNative        : Option UInt64
  delegatedAmount : UInt64
  closeAuthority  : Option Pubkey

namespace Account

def dataLen : Nat := 165

@[inline, expose]
def decodePayload (d : Borsh.Decoder) : Option (Account × Borsh.Decoder) := do
  let (mint, d) ← Borsh.Decoder.readPubkey? d
  let (owner, d) ← Borsh.Decoder.readPubkey? d
  let (amount, d) ← Borsh.Decoder.readUInt64LE? d
  let (delegate, d) ← COption.readPubkey? d
  let (stateTag, d) ← Borsh.Decoder.readUInt8? d
  let state ← AccountState.decode? stateTag
  let (isNative, d) ← COption.readUInt64? d
  let (delegatedAmount, d) ← Borsh.Decoder.readUInt64LE? d
  let (closeAuthority, d) ← COption.readPubkey? d
  some ({ mint, owner, amount, delegate, state, isNative, delegatedAmount, closeAuthority }, d)

@[inline, expose]
def decode? (data : ByteArray) : Option Account :=
  Borsh.decodeExact? data decodePayload

@[inline, expose]
def fromAccount? (account : AccountInfo) : Option Account :=
  if account.owner == TokenProgram.id || account.owner == TokenProgram.token2022Id then
    decode? account.data
  else
    none

@[inline, expose]
def fromAccount (account : AccountInfo)
    (err : ProgramError := ProgramError.invalidAccountData) : ProgramResult Account :=
  ProgramResult.fromOption (fromAccount? account) err

end Account

end Token

namespace AssociatedTokenProgram

/-- Associated Token Account program: `ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL`. -/
@[inline, expose]
def id : Pubkey :=
  { bytes := ByteArray.mk #[
      140, 151, 37, 143, 78, 36, 137, 241,
      187, 61, 16, 41, 20, 142, 13, 131,
      11, 90, 19, 153, 218, 255, 16, 132,
      4, 142, 123, 216, 219, 233, 248, 89]
    size_eq := by native_decide }

@[inline, expose]
def createData : ByteArray :=
  ByteArray.empty

@[inline, expose]
def createIdempotentData : ByteArray :=
  ByteArray.mk #[1]

@[inline, expose]
def recoverNestedData : ByteArray :=
  ByteArray.mk #[2]

@[inline, expose]
def addressSeeds (wallet mint tokenProgramId : Pubkey) : Array ByteArray :=
  #[wallet.toBytes, tokenProgramId.toBytes, mint.toBytes]

@[inline, expose]
def createInstructionWithProgram (associatedTokenProgramId payer associatedAccount
    wallet mint tokenProgramId : Pubkey) : Instruction :=
  Instruction.new associatedTokenProgramId
    #[AccountMeta.writableSigner payer,
      AccountMeta.writable associatedAccount,
      AccountMeta.readonly wallet,
      AccountMeta.readonly mint,
      AccountMeta.readonly SystemProgram.id,
      AccountMeta.readonly tokenProgramId]
    createData

@[inline, expose]
def createInstruction (payer associatedAccount wallet mint : Pubkey)
    (tokenProgramId : Pubkey := TokenProgram.id) : Instruction :=
  createInstructionWithProgram id payer associatedAccount wallet mint tokenProgramId

@[inline, expose]
def createIdempotentInstructionWithProgram (associatedTokenProgramId payer associatedAccount
    wallet mint tokenProgramId : Pubkey) : Instruction :=
  { createInstructionWithProgram associatedTokenProgramId payer associatedAccount wallet mint tokenProgramId with
    data := createIdempotentData }

@[inline, expose]
def createIdempotentInstruction (payer associatedAccount wallet mint : Pubkey)
    (tokenProgramId : Pubkey := TokenProgram.id) : Instruction :=
  createIdempotentInstructionWithProgram id payer associatedAccount wallet mint tokenProgramId

@[inline, expose]
def createSigned (payer associatedAccount wallet mint : Pubkey)
    (tokenProgramId : Pubkey) (signers : Array (Array ByteArray)) : BaseIO Unit :=
  invokeSigned (createInstruction payer associatedAccount wallet mint tokenProgramId) signers

@[inline, expose]
def create (payer associatedAccount wallet mint : Pubkey)
    (tokenProgramId : Pubkey := TokenProgram.id) : BaseIO Unit :=
  invoke (createInstruction payer associatedAccount wallet mint tokenProgramId)

@[inline, expose]
def createIdempotentSigned (payer associatedAccount wallet mint : Pubkey)
    (tokenProgramId : Pubkey) (signers : Array (Array ByteArray)) : BaseIO Unit :=
  invokeSigned (createIdempotentInstruction payer associatedAccount wallet mint tokenProgramId) signers

@[inline, expose]
def createIdempotent (payer associatedAccount wallet mint : Pubkey)
    (tokenProgramId : Pubkey := TokenProgram.id) : BaseIO Unit :=
  invoke (createIdempotentInstruction payer associatedAccount wallet mint tokenProgramId)

end AssociatedTokenProgram

@[extern "lean_sbf_find_program_address", never_extract]
opaque findProgramAddressImpl
  (seeds : @&Array ByteArray) (programId : @&Pubkey)
  : Option (Pubkey × UInt8)

@[extern "lean_sbf_create_program_address", never_extract]
opaque createProgramAddressImpl
  (seeds : @&Array ByteArray) (programId : @&Pubkey)
  : Option Pubkey

/-- Find the canonical PDA for `seeds` under `programId`; returns the address
paired with the bump byte that produced it. -/
def findProgramAddress (seeds : Array ByteArray) (programId : Pubkey)
    : BaseIO (Option (Pubkey × UInt8)) :=
  pure (findProgramAddressImpl seeds programId)

/-- Compute a PDA from explicit seeds (last seed is the bump). Returns `none` if
the result lands on the Ed25519 curve. -/
def createProgramAddress (seeds : Array ByteArray) (programId : Pubkey)
    : BaseIO (Option Pubkey) :=
  pure (createProgramAddressImpl seeds programId)

namespace Pda

@[inline, expose]
def bumpSeed (bump : UInt8) : ByteArray :=
  (ByteArray.emptyWithCapacity 1).push bump

@[inline, expose]
def seedsWithBump (seeds : Array ByteArray) (bump : UInt8) : Array ByteArray :=
  seeds.push (bumpSeed bump)

@[inline, expose]
def find? (seeds : Array ByteArray) (programId : Pubkey) : Option (Pubkey × UInt8) :=
  findProgramAddressImpl seeds programId

@[inline, expose]
def create? (seeds : Array ByteArray) (programId : Pubkey) : Option Pubkey :=
  createProgramAddressImpl seeds programId

@[inline, expose]
def requireCanonical (actual : Pubkey) (seeds : Array ByteArray)
    (programId : Pubkey) (err : ε) : Except ε UInt8 :=
  match find? seeds programId with
  | some (expected, bump) =>
      if expected == actual then .ok bump else .error err
  | none => .error err

@[inline, expose]
def requireDerived (actual : Pubkey) (seeds : Array ByteArray)
    (programId : Pubkey) (err : ε) : Except ε Unit :=
  match create? seeds programId with
  | some expected =>
      if expected == actual then .ok () else .error err
  | none => .error err

end Pda

namespace AssociatedTokenProgram

@[inline, expose]
def findAddress? (wallet mint : Pubkey)
    (tokenProgramId : Pubkey := TokenProgram.id) : Option (Pubkey × UInt8) :=
  Pda.find? (addressSeeds wallet mint tokenProgramId) id

end AssociatedTokenProgram

/-! Mutable account state. The `ctx.accounts` snapshot is read-only; these
mutators target the loader buffer directly so writes propagate on chain. Out-of-
bounds, write to a non-writable account, or call before `ProgramContext` exists
→ panic. Account-data growth (Solana's `realloc`) is not supported. -/

@[extern "lean_sbf_get_lamports", never_extract]
opaque getLamportsImpl (idx : UInt64) : UInt64

@[extern "lean_sbf_set_lamports", never_extract]
opaque setLamportsImpl (idx : UInt64) (value : UInt64) : Unit

@[extern "lean_sbf_get_data_byte", never_extract]
opaque getDataByteImpl (idx : UInt64) (offset : UInt64) : UInt8

@[extern "lean_sbf_set_data_byte", never_extract]
opaque setDataByteImpl (idx : UInt64) (offset : UInt64) (value : UInt8) : Unit

@[extern "lean_sbf_write_data", never_extract]
opaque writeDataImpl (idx : UInt64) (offset : UInt64) (src : @&ByteArray) : Unit

@[extern "lean_sbf_read_data", never_extract]
opaque readDataImpl (idx : UInt64) (offset : UInt64) (len : UInt64) : ByteArray

namespace ProgramContext

@[inline, expose]
def account? (ctx : ProgramContext) (idx : Nat) : Option AccountInfo :=
  ctx.accounts[idx]?

@[inline, expose]
def accountOr (ctx : ProgramContext) (idx : Nat) (err : ε) : Except ε AccountInfo :=
  match ctx.account? idx with
  | some account => .ok account
  | none => .error err

@[inline, expose]
def findAccountByKey? (ctx : ProgramContext) (key : Pubkey) : Option AccountInfo :=
  Id.run do
    for account in ctx.accounts do
      if account.key == key then
        return some account
    return none

@[inline, expose]
def sysvarClock? (ctx : ProgramContext) : Option Sysvar.Clock :=
  Sysvar.Clock.fromAccount? =<< ctx.findAccountByKey? Sysvar.Clock.id

@[inline, expose]
def sysvarClock (ctx : ProgramContext)
    (err : ProgramError := ProgramError.invalidAccountData) : ProgramResult Sysvar.Clock :=
  ProgramResult.fromOption ctx.sysvarClock? err

@[inline, expose]
def sysvarRent? (ctx : ProgramContext) : Option Sysvar.Rent :=
  Sysvar.Rent.fromAccount? =<< ctx.findAccountByKey? Sysvar.Rent.id

@[inline, expose]
def sysvarRent (ctx : ProgramContext)
    (err : ProgramError := ProgramError.invalidAccountData) : ProgramResult Sysvar.Rent :=
  ProgramResult.fromOption ctx.sysvarRent? err

@[inline, expose]
def dataDecoder (ctx : ProgramContext) : Borsh.Decoder :=
  Borsh.Decoder.ofBytes ctx.data

@[inline, expose]
def dispatchTag (ctx : ProgramContext) (cases : Array (Dispatch.TagCase α))
    (unknownErr : ProgramError := ProgramError.unsupportedInstruction)
    (decodeErr : ProgramError := ProgramError.invalidInstructionData) : ProgramResult α :=
  Dispatch.byTag ctx.data cases unknownErr decodeErr

@[inline, expose]
def dispatchAnchor (ctx : ProgramContext) (cases : Array (Dispatch.AnchorCase α))
    (unknownErr : ProgramError := ProgramError.unsupportedInstruction)
    (decodeErr : ProgramError := ProgramError.invalidInstructionData) : ProgramResult α :=
  Dispatch.byAnchor ctx.data cases unknownErr decodeErr

@[inline, expose]
def validateAccount (ctx : ProgramContext) (idx : Nat)
    (constraints : AccountConstraints) (err : ε) : Except ε AccountInfo := do
  let account ← ctx.accountOr idx err
  account.validate constraints err
  pure account

@[inline, expose]
def loadAccount (ctx : ProgramContext) (idx : Nat)
    (codec : AccountCodec α) (err : ε) : Except ε (LoadedAccount α) := do
  let account ← ctx.accountOr idx err
  let value ← account.decodeWith codec err
  pure { index := idx, account, value }

@[inline, expose]
def loadValidatedAccount (ctx : ProgramContext) (idx : Nat)
    (constraints : AccountConstraints) (codec : AccountCodec α)
    (err : ε) : Except ε (LoadedAccount α) := do
  let account ← ctx.validateAccount idx constraints err
  let value ← account.decodeWith codec err
  pure { index := idx, account, value }

def getLamports (_ctx : ProgramContext) (idx : Nat) : BaseIO UInt64 :=
  pure (getLamportsImpl idx.toUInt64)

def setLamports (_ctx : ProgramContext) (idx : Nat) (value : UInt64) : BaseIO Unit :=
  pure (setLamportsImpl idx.toUInt64 value)

def getDataByte (_ctx : ProgramContext) (idx : Nat) (offset : Nat) : BaseIO UInt8 :=
  pure (getDataByteImpl idx.toUInt64 offset.toUInt64)

def setDataByte (_ctx : ProgramContext) (idx : Nat) (offset : Nat) (value : UInt8) : BaseIO Unit :=
  pure (setDataByteImpl idx.toUInt64 offset.toUInt64 value)

def writeData (_ctx : ProgramContext) (idx : Nat) (offset : Nat) (src : ByteArray) : BaseIO Unit :=
  pure (writeDataImpl idx.toUInt64 offset.toUInt64 src)

def writeEncodedAccount (_ctx : ProgramContext) (idx : Nat)
    (codec : AccountCodec α) (value : α) (err : ε) : Except ε Unit := do
  let data ← codec.encodeOr value err
  let _ := writeDataImpl idx.toUInt64 0 data
  pure ()

def writeLoadedAccount (ctx : ProgramContext) (loaded : LoadedAccount α)
    (codec : AccountCodec α) (value : α) (err : ε) : Except ε Unit :=
  ctx.writeEncodedAccount loaded.index codec value err

def readData (_ctx : ProgramContext) (idx : Nat) (offset : Nat) (len : Nat) : BaseIO ByteArray :=
  pure (readDataImpl idx.toUInt64 offset.toUInt64 len.toUInt64)

end ProgramContext

namespace ProgramResult

@[inline, expose]
def entrypoint (handler : ProgramContext → ProgramResult Unit)
    (ctx : ProgramContext) : UInt64 :=
  toReturnCode (handler ctx)

@[inline, expose]
def entrypointWith (handler : ProgramContext → ProgramResult α)
    (ok : α → UInt64) (ctx : ProgramContext) : UInt64 :=
  toReturnCodeWith ok (handler ctx)

end ProgramResult

end Std.Solana
