import FreestandingTypeCheckerCore

namespace Lean4Lean.FreestandingTypeCheckerMain

@[extern "lean4lean_string_from_bytes"]
opaque stringFromBytes (ptr len : UInt32) : String

@[export lean4lean_check_text]
def checkTextEntry (ptr len : UInt32) : UInt32 :=
  Lean4Lean.FreestandingTypeCheckerCore.checkAstText (stringFromBytes ptr len)

@[export lean4lean_typechecker_main]
def entry (_token : UInt32) : UInt32 :=
  Lean4Lean.FreestandingTypeCheckerCore.runFixtureDag ()

@[export lean_wasm_main_io]
def wasmMain : BaseIO UInt64 :=
  pure (Lean4Lean.FreestandingTypeCheckerCore.runFixtureDag ()).toUInt64

end Lean4Lean.FreestandingTypeCheckerMain
