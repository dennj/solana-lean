/- WASM: eight Std.Wasm.log calls survive DCE via BaseIO sequencing. -/
import Std.Wasm

@[export lean_wasm_main_io]
def entry : BaseIO UInt64 := do
  Std.Wasm.log "log line 1"
  Std.Wasm.log "log line 2"
  Std.Wasm.log "log line 3"
  Std.Wasm.log "log line 4"
  Std.Wasm.log "log line 5"
  Std.Wasm.log "log line 6"
  Std.Wasm.log "log line 7"
  Std.Wasm.log "log line 8"
  return 42
