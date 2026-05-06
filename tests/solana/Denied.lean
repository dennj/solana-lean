/- Negative test: IO.FS.readFile is denied on sbf-* by Std.Solana. -/
import Std.Solana

def main : IO Unit := do
  let _ ← IO.FS.readFile "/etc/passwd"
  pure ()
