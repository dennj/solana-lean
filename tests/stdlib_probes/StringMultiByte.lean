/-! Probe: multi-byte UTF-8 strings. Exercises
`lean_freestanding_utf8_encode` and `lean_freestanding_utf8_strlen` on
characters wider than ASCII (1-byte), including 2-byte (Latin-1
supplement), 3-byte (CJK), and 4-byte (emoji / supplementary plane).

Reference encoded sizes:
  "héllo"  -> h(1) é(2) l(1) l(1) o(1)         = 6 bytes, 5 chars
  "日本"    -> 日(3) 本(3)                       = 6 bytes, 2 chars
  "𝕃ean"   -> 𝕃(4) e(1) a(1) n(1)              = 7 bytes, 4 chars
-/
@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let s2 := "héllo"
  let s3 := "日本"
  let s4 := "𝕃ean"
  let ok :=
    (s2.length == 5) &&
    (s2.toUTF8.size == 6) &&
    (s3.length == 2) &&
    (s3.toUTF8.size == 6) &&
    (s4.length == 4) &&
    (s4.toUTF8.size == 7) &&
    -- Round-trip each through ByteArray.
    (match String.fromUTF8? s2.toUTF8 with | some t => t == s2 | none => false) &&
    (match String.fromUTF8? s3.toUTF8 with | some t => t == s3 | none => false) &&
    (match String.fromUTF8? s4.toUTF8 with | some t => t == s4 | none => false)
  if ok then 0 else 99
