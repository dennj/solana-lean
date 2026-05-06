/-! Probe: `@[specialize]` on a polymorphic function. Specialization
duplicates the function body for each concrete instantiation, eliminating
the typeclass dictionary. If specialization fails, the call goes through
generic dispatch via `lean_apply_*` and may surface a missing closure
runtime function. -/

@[specialize]
def myFold {α : Type} [Add α] [OfNat α 0] (xs : List α) : α :=
  match xs with
  | [] => (0 : α)
  | h :: t => h + myFold t

@[noinline]
def sum64 (xs : List UInt64) : UInt64 := myFold xs

@[noinline]
def sum32 (xs : List UInt32) : UInt32 := myFold xs

@[noinline]
def sumNat (xs : List Nat) : Nat := myFold xs

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let s64 := sum64 [10, 20, 30, 40]
  let s32 := sum32 [1, 2, 3, 4, 5]
  let sN := sumNat [100, 200, 300]
  if s64 == 100 && s32 == 15 && sN == 600 then 0 else 99
