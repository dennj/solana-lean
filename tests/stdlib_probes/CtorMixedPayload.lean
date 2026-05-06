/-! Probe: ctor with mixed object pointer + scalar tail fields. Exercises
`lean_alloc_ctor`, `lean_ctor_get_uint64/32/16/8`, `lean_ctor_set_uint64/...`,
and `lean_ctor_set_tag`. The freestanding ABI must compute the scalar tail
offset as `sizeof(lean_ctor_object) + sizeof(void*) * num_objs`; if it
drifts from the inline `lean.h` layout, this probe miscomputes silently. -/

inductive Mixed where
  | leaf
  | bar : UInt64 -> UInt32 -> UInt16 -> UInt8 -> List UInt64 -> String -> Mixed

@[noinline]
def mkBar (a : UInt64) (b : UInt32) (c : UInt16) (d : UInt8)
    (xs : List UInt64) (s : String) : Mixed :=
  Mixed.bar a b c d xs s

@[noinline]
def proj (m : Mixed) : UInt64 :=
  match m with
  | .leaf => 0
  | .bar a b c d xs s =>
    a + b.toUInt64 + c.toUInt64 + d.toUInt64 + xs.length.toUInt64 + s.length.toUInt64

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let m := mkBar 0x1000000000000 0x10000 0x100 0x10 [1, 2, 3, 4, 5] "hello"
  let n := proj m
  let leaf := proj .leaf
  let expected : UInt64 := 0x1000000000000 + 0x10000 + 0x100 + 0x10 + 5 + 5
  if n == expected && leaf == 0 then 0 else 99
