import Lake
open Lake DSL

package cross_solana

lean_lib Vault

@[default_target]
target «Vault.so» : System.FilePath := do
  let some mod := (← findModule? `Vault) | error "missing Vault module"
  buildSolanaProgram mod
