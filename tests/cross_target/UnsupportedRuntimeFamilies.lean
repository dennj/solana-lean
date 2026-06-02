/- Program that touches freestanding-denied host runtime families.

The cross-target test expects this module to fail during Lean code generation,
before any target linker/runtime is involved.
-/
import Std.Sync
import Std.Net

@[export unsupported_thunk_get]
def unsupportedThunkGet (x : UInt64) : UInt64 :=
  let t : Thunk UInt64 := Thunk.mk (fun _ => x)
  t.get

@[export unsupported_int_add]
def unsupportedIntAdd (x y : Int) : Int :=
  x + y

@[export unsupported_float_add]
def unsupportedFloatAdd (x y : Float) : Float :=
  x + y

@[export unsupported_string_get]
def unsupportedStringGet (s : String) : UInt32 :=
  (String.Pos.Raw.get s 0).val

@[export unsupported_ipv4_parse]
def unsupportedIPv4Parse (s : String) : Bool :=
  (Std.Net.IPv4Addr.ofString s).isSome

def unsupportedRef : BaseIO Unit := do
  let _ ← IO.mkRef (0 : UInt64)
  pure ()

def main : IO Unit := do
  let _ ← IO.getStdout
  let _ ← Std.BaseMutex.new
  unsupportedRef
