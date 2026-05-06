import Lake
open Lake DSL

package cross_freestanding

lean_lib Kernel

@[default_target]
target «kernel.elf» : System.FilePath := do
  let some mod := (← findModule? `Kernel) | error "missing Kernel module"
  buildFreestandingProgram
    (mods         := #[mod])
    (extraSources := #["boot.S"])
    (linkerScript := "kernel.ld")
    (entry        := "_start")
