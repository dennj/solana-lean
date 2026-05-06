/-! Probe: polymorphic functions and the @[specialize] specialiser. -/
@[specialize]
def myId {α : Type} (x : α) : α := x

@[specialize]
def myConst {α β : Type} (x : α) (_ : β) : α := x

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let a : UInt64 := myId 42
  let b : UInt64 := myConst 7 "ignored"
  let s : String := myId "hi"
  let n : UInt64 := s.length.toUInt64
  if (a - b + n) == 37 then 0 else 99
