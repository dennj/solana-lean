/- Probe: ByteArray construction via Array UInt8 round-trip. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let arr : Array UInt8 := #[0x10, 0x20, 0x30]
  let ba : ByteArray := ⟨arr⟩
  let n : UInt64 := ba.size.toUInt64
  if n == 3 then 0 else 99
