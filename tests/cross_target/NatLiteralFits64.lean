/- A Nat literal that fits 64-bit freestanding targets but not wasm32. -/

@[export nat_literal_fits64]
def natLiteralFits64 : Nat :=
  2147483648
