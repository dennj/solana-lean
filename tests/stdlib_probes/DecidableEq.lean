/-! Probe: `deriving DecidableEq` on a custom inductive. The compiler
synthesises a `decEq` instance that case-splits the constructors and
recursively decides field equality. The resulting decidable proof reduces
to `isTrue rfl` / `isFalse _` which we observe via `decide`. -/

inductive Color where
  | red
  | green
  | blue
  deriving DecidableEq

inductive Shape where
  | circle (r : UInt64)
  | square (side : UInt64)
  | triangle (a b c : UInt64)
  deriving DecidableEq

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let cEq := decide (Color.red = Color.red)
  let cNe := decide (Color.red = Color.blue)
  let sEqualPayload := decide (Shape.circle 10 = Shape.circle 10)
  let sUnequalPayload := decide (Shape.circle 10 = Shape.circle 11)
  let sUnequalCtor := decide (Shape.circle 10 = Shape.square 10)
  let sTriEq := decide (Shape.triangle 3 4 5 = Shape.triangle 3 4 5)
  let sTriNe := decide (Shape.triangle 3 4 5 = Shape.triangle 3 4 6)
  if cEq && !cNe && sEqualPayload && !sUnequalPayload && !sUnequalCtor
     && sTriEq && !sTriNe then 0 else 99
