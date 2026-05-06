/- Eight pure-context msg! calls survive DCE into the .so. -/
import Std.Solana

open Std.Solana

@[export lean_sol_entry_typed]
def entry (_ctx : ProgramContext) : UInt64 :=
  let _ := Std.Solana.msg! "log line 1"
  let _ := Std.Solana.msg! "log line 2"
  let _ := Std.Solana.msg! "log line 3"
  let _ := Std.Solana.msg! "log line 4"
  let _ := Std.Solana.msg! "log line 5"
  let _ := Std.Solana.msg! "log line 6"
  let _ := Std.Solana.msg! "log line 7"
  let _ := Std.Solana.msg! "log line 8"
  0x42
