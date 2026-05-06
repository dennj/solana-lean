/- Negative test: IO.FS.readFile is denied on wasm32-* by Std.Wasm. -/
import Std.Wasm

def main : IO Unit := do
  let _ ← IO.FS.readFile "/etc/passwd"
  pure ()
