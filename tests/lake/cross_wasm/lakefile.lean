import Lake
open Lake DSL

package cross_wasm

lean_lib Hello

@[default_target]
target «Hello.wasm» : System.FilePath := do
  let some mod := (← findModule? `Hello) | error "missing Hello module"
  buildWasmProgram mod
