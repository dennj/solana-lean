/- WASM: program links against an extra C helper via @[extern]. -/
@[extern "lean_extra_answer"]
opaque extraAnswer (_ : UInt64) : UInt64

@[export lean_wasm_main]
def entry (_ : UInt64) : UInt64 :=
  extraAnswer 0
