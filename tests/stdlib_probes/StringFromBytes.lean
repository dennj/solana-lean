/-! Probe: round-trip a String through ByteArray. Exercises
`lean_string_to_utf8`, `lean_mk_string_from_bytes` (or
`lean_mk_string_from_bytes_unchecked`), and `lean_freestanding_utf8_strlen`.
Validates that the freestanding runtime's UTF-8 path agrees with host. -/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let original := "Hello, world!"
  let bytes := original.toUTF8
  let nbytes := bytes.size
  match String.fromUTF8? bytes with
  | none => 1
  | some round =>
    let ok :=
      (nbytes == 13) &&
      (round == original) &&
      (round.length == 13)
    if ok then 0 else 99
