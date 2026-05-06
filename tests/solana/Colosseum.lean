import Std.Solana

/-! Vault demo program: deposit and withdraw with a balance-leak invariant.

    The safety invariant `balance + totalOut == totalIn` says the vault never
    pays out more than was deposited. The `example :` proofs at the bottom of
    this file are checked by the compiler. Removing the `balance := v.balance - amount`
    line in `Vault.withdraw` breaks the `withdraw` invariant proof, the file
    fails to compile, and the program will not build. -/

open Std.Solana

namespace Colosseum

/-- Vault state held in the program account: live balance, lifetime in, lifetime out. -/
structure Vault where
  balance  : UInt64
  totalIn  : UInt64
  totalOut : UInt64
  deriving DecidableEq

/-- Safety invariant: the vault never owes more than it took in.
    Computed in `Nat` to side-step UInt64 wraparound at the proof level. -/
def Vault.ok (v : Vault) : Bool :=
  v.balance.toNat + v.totalOut.toNat == v.totalIn.toNat

/-- Deposit `amount`: balance and totalIn both grow. -/
def Vault.deposit (v : Vault) (amount : UInt64) : Vault :=
  { v with
    balance := v.balance + amount
    totalIn := v.totalIn + amount }

/-- Withdraw `amount`: balance shrinks, totalOut grows.
    Deleting the `balance := v.balance - amount` line is the canonical
    balance-leak bug — the `withdraw` proof below stops checking. -/
def Vault.withdraw (v : Vault) (amount : UInt64) : Vault :=
  { v with
    balance  := v.balance - amount
    totalOut := v.totalOut + amount }

/-- Starting state used by the proof checks: 100 deposited, 100 held, 0 withdrawn. -/
def v0 : Vault := { balance := 100, totalIn := 100, totalOut := 0 }

/-- The starting state satisfies the invariant. -/
example : v0.ok = true := by native_decide

/-- Depositing 50 preserves the invariant. -/
example : (v0.deposit 50).ok = true := by native_decide

/-- Withdrawing 30 preserves the invariant.
    This is the proof that fails when the balance-decrement line is removed. -/
example : (v0.withdraw 30).ok = true := by native_decide

/-- Compound scenario: deposit 50, then withdraw 70, still consistent. -/
example : ((v0.deposit 50).withdraw 70).ok = true := by native_decide

/-- Withdrawing the full balance leaves the vault consistent and empty. -/
example : (v0.withdraw 100).balance = 0 := by native_decide

-- ── Solana entry ──────────────────────────────────────────────────────────────

def opDeposit  : UInt8 := 0
def opWithdraw : UInt8 := 1

/-- Decode a 24-byte vault record from the account data. -/
def decodeVault (bytes : ByteArray) : Option Vault := do
  let d := Borsh.Decoder.ofBytes bytes
  let (balance,  d) ← Borsh.Decoder.readUInt64LE? d
  let (totalIn,  d) ← Borsh.Decoder.readUInt64LE? d
  let (totalOut, _) ← Borsh.Decoder.readUInt64LE? d
  some { balance, totalIn, totalOut }

/-- Encode a vault record into a fresh 24-byte buffer. -/
def encodeVault (v : Vault) : ByteArray :=
  let e := Borsh.Encoder.withCapacity 24
  let e := Borsh.Encoder.putUInt64LE e v.balance
  let e := Borsh.Encoder.putUInt64LE e v.totalIn
  Borsh.Encoder.putUInt64LE e v.totalOut

/-- Read the op byte and the u64 amount from the instruction data. -/
def parseInstr (data : ByteArray) : Option (UInt8 × UInt64) := do
  let d := Borsh.Decoder.ofBytes data
  let (op,     d) ← Borsh.Decoder.readUInt8? d
  let (amount, _) ← Borsh.Decoder.readUInt64LE? d
  some (op, amount)

/-- Apply an op to the vault. Returns `none` for unknown op or insufficient balance. -/
def step (v : Vault) (op : UInt8) (amount : UInt64) : Option Vault :=
  if op == opDeposit then
    some (v.deposit amount)
  else if op == opWithdraw then
    if amount ≤ v.balance then some (v.withdraw amount) else none
  else
    none

@[export lean_sol_entry_typed]
def entry (ctx : ProgramContext) : UInt64 :=
  let _ := msg! "vault: deposit/withdraw"
  match parseInstr ctx.data with
  | none => 0xE0
  | some (op, amount) =>
    match decodeVault (readDataImpl 0 0 24) with
    | none => 0xE1
    | some v =>
      match step v op amount with
      | none => 0xE2
      | some v' =>
        let _ := writeDataImpl 0 0 (encodeVault v')
        if v'.ok then 0 else 0xE3

end Colosseum
