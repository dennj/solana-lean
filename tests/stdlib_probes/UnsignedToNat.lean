/-! Probe: round-trips between fixed-width unsigned ints and `Nat`.
Exercises `lean_unsigned_to_nat`, `lean_uint64_of_nat`, `lean_uint64_to_nat`,
`lean_usize_of_nat`, `lean_usize_to_nat`. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let n64 : Nat := 1000000
  let u64 : UInt64 := UInt64.ofNat n64
  let back64 : Nat := u64.toNat

  let nz : Nat := 0
  let uz : UInt64 := UInt64.ofNat nz
  let backz : Nat := uz.toNat

  let big : UInt64 := 0xFFFFFFFFFFFFFFFF
  let bigBack : Nat := big.toNat
  let bigRound : UInt64 := UInt64.ofNat bigBack

  let nsz : Nat := 4096
  let usz : USize := USize.ofNat nsz
  let backsz : Nat := usz.toNat

  let ok :=
    (back64 == 1000000) &&
    (backz == 0) &&
    (uz == 0) &&
    (bigBack == 0xFFFFFFFFFFFFFFFF) &&
    (bigRound == big) &&
    (backsz == 4096) &&
    (usz == (4096 : USize))
  if ok then 0 else 99
