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

/-- **Safety theorem (deposit).** For any vault `v` satisfying the
    invariant, depositing `amount` preserves the invariant — provided
    neither `balance + amount` nor `totalIn + amount` overflows
    `UInt64`. -/
theorem deposit_preserves_ok
    (v : Vault) (amount : UInt64)
    (h_ok : v.ok = true)
    (h_bal : v.balance.toNat + amount.toNat < UInt64.size)
    (h_in  : v.totalIn.toNat  + amount.toNat < UInt64.size) :
    (v.deposit amount).ok = true := by
  simp only [Vault.ok, Vault.deposit, UInt64.toNat_add, beq_iff_eq] at *
  rw [Nat.mod_eq_of_lt h_bal, Nat.mod_eq_of_lt h_in]
  omega

/-- **Safety theorem (withdraw).** For any vault `v` satisfying the
    invariant, withdrawing `amount` preserves the invariant — provided
    `amount ≤ balance` (no underflow) and `totalOut + amount` does not
    overflow `UInt64`. Removing the `balance := v.balance - amount`
    line in `Vault.withdraw` makes this theorem unprovable. -/
theorem withdraw_preserves_ok
    (v : Vault) (amount : UInt64)
    (h_ok  : v.ok = true)
    (h_pre : amount ≤ v.balance)
    (h_out : v.totalOut.toNat + amount.toNat < UInt64.size) :
    (v.withdraw amount).ok = true := by
  have h_pre_nat : amount.toNat ≤ v.balance.toNat := UInt64.le_iff_toNat_le.mp h_pre
  simp only [Vault.ok, Vault.withdraw, UInt64.toNat_add, beq_iff_eq] at *
  rw [UInt64.toNat_sub_of_le _ _ h_pre, Nat.mod_eq_of_lt h_out]
  omega

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
