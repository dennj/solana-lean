/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Leanc.CrossTarget

open System (FilePath)

namespace Leanc
namespace RiscV64Freestanding

private def clangCandidates : Array FilePath :=
  #[FilePath.mk "/opt/homebrew/opt/llvm@19/bin/clang",
    FilePath.mk "/opt/homebrew/opt/llvm/bin/clang",
    FilePath.mk "/usr/local/opt/llvm/bin/clang",
    FilePath.mk "/usr/lib/llvm-19/bin/clang",
    FilePath.mk "/usr/lib/llvm-18/bin/clang",
    FilePath.mk "/usr/bin/clang-19",
    FilePath.mk "/usr/bin/clang-18",
    FilePath.mk "/usr/bin/clang"]

private def llvmToolCandidates (tool : String) : Array FilePath :=
  #[FilePath.mk s!"/opt/homebrew/opt/llvm@19/bin/{tool}",
    FilePath.mk s!"/opt/homebrew/opt/llvm/bin/{tool}",
    FilePath.mk s!"/usr/local/opt/llvm/bin/{tool}",
    FilePath.mk s!"/usr/lib/llvm-19/bin/{tool}",
    FilePath.mk s!"/usr/lib/llvm-18/bin/{tool}",
    FilePath.mk s!"/usr/bin/{tool}-19",
    FilePath.mk s!"/usr/bin/{tool}-18",
    FilePath.mk s!"/usr/bin/{tool}"]

private def findTools : IO (FilePath × FilePath × FilePath) := do
  let clangPath ← match (← IO.getEnv "LEAN_RISCV64_CLANG") with
    | some p => pure (FilePath.mk p)
    | none =>
      let some p ← firstExisting clangCandidates
        | throw <| IO.userError "riscv64 clang not found. Set LEAN_RISCV64_CLANG=<path> or install LLVM."
      pure p
  let ldPath ← match (← IO.getEnv "LEAN_RISCV64_LD") with
    | some p => pure (FilePath.mk p)
    | none =>
      let nextToClang := (clangPath.parent.getD (FilePath.mk ".")) / "ld.lld"
      let candidates := #[nextToClang] ++ llvmToolCandidates "ld.lld"
      let some p ← firstExisting candidates
        | throw <| IO.userError "ld.lld not found. Set LEAN_RISCV64_LD=<path> or install LLVM lld."
      pure p
  let nmPath ← match (← IO.getEnv "LEAN_RISCV64_NM") with
    | some p => pure (FilePath.mk p)
    | none =>
      let nextToClang := (clangPath.parent.getD (FilePath.mk ".")) / "llvm-nm"
      let candidates := #[nextToClang] ++ llvmToolCandidates "llvm-nm"
      let some p ← firstExisting candidates
        | throw <| IO.userError "llvm-nm not found. Set LEAN_RISCV64_NM=<path> or install LLVM."
      pure p
  return (clangPath, ldPath, nmPath)

private def commonClangArgs (triple : String) : Array String :=
  #[s!"--target={triple}", "-O2", "-ffreestanding", "-fno-stack-protector",
    "-fno-builtin", "-fno-pic", "-ffunction-sections", "-fdata-sections",
    "-mcmodel=medany", "-mno-relax",
    "-msmall-data-limit=0", "-march=rv64imac", "-mabi=lp64"]

private def link (root : FilePath) (a : CrossArgs) : IO UInt32 := do
  let (clangPath, ldPath, nmPath) ← findTools
  let clang := clangPath.toString
  let lld := ldPath.toString
  let nm := nmPath.toString
  let freestandingDir := root / "lib" / "lean" / "freestanding"
  let freestandingRuntimeC := freestandingDir / "runtime.c"
  unless (← freestandingRuntimeC.pathExists) do
    throw <| IO.userError s!"missing freestanding runtime at {freestandingDir} \
      (expected runtime.c)"
  let some output := a.output
    | throw <| IO.userError "leanc --target=riscv64-unknown-none*: -o <file> is required"

  IO.FS.withTempDir fun tmp => do
    let mut objects : Array String := #[]
    let kernelHeapDefs : Array String := #["-DLEAN_FREESTANDING_HEAP_SYMBOLS"]
    let freestandingIncludeArgs : Array String := #["-I", freestandingDir.toString]
    let baseArgs := commonClangArgs a.triple
    let compileBc (bc : FilePath) (objName : String) : IO String := do
      let obj := (tmp / objName).toString
      runOrFail clang (baseArgs ++ #["-c", bc.toString, "-o", obj])
      return obj
    let compileUserC (c : FilePath) (objName : String) : IO String := do
      let obj := (tmp / objName).toString
      runOrFail clang (baseArgs ++ freestandingIncludeArgs ++ a.compileArgs ++
        #["-c", c.toString, "-o", obj])
      return obj
    let compileRuntimeC (c : FilePath) (objName : String) : IO String := do
      let obj := (tmp / objName).toString
      runOrFail clang (baseArgs ++ freestandingIncludeArgs ++ kernelHeapDefs ++
        #["-c", c.toString, "-o", obj])
      return obj
    let compileAsm (s : FilePath) (objName : String) : IO String := do
      let obj := (tmp / objName).toString
      runOrFail clang (baseArgs ++ a.compileArgs ++ #["-c", s.toString, "-o", obj])
      return obj

    let mut leanObjs : Array String := #[]
    for inp in a.inputs do
      let stem := inp.fileStem.getD "input"
      let ext := inp.extension.getD ""
      let obj ←
        if ext == "bc" then
          let o ← compileBc inp s!"{stem}.bc.o"
          leanObjs := leanObjs.push o
          pure o
        else if ext == "c" then
          let o ← compileUserC inp s!"{stem}.c.o"
          leanObjs := leanObjs.push o
          pure o
        else if ext == "s" || ext == "S" then
          let o ← compileAsm inp s!"{stem}.{ext}.o"
          leanObjs := leanObjs.push o
          pure o
        else if ext == "o" then
          leanObjs := leanObjs.push inp.toString
          pure inp.toString
        else
          throw <| IO.userError s!"unsupported input extension '.{ext}': {inp}"
      objects := objects.push obj

    objects := objects.push (← compileRuntimeC freestandingRuntimeC "freestanding_runtime.o")

    let mut initSymbol? : Option String := none
    let mut hasU64Main := false
    let mut hasIOMain := false
    for objPath in leanObjs do
      let out ← IO.Process.output { cmd := nm, args := #["--defined-only", objPath] }
      if out.exitCode != 0 then
        throw <| IO.userError s!"llvm-nm failed on {objPath}: {out.stderr}"
      for ln in out.stdout.splitOn "\n" do
        let parts := ln.trimAscii.toString.splitOn " " |>.filter (·.length > 0)
        if let some (name : String) := parts.toArray.back? then
          if name.startsWith "initialize_" && name != "initialize_Init"
              && name != "initialize_Std_Freestanding_Unsupported"
              && initSymbol?.isNone then
            initSymbol? := some name
          if name == "lean_kernel_main" then hasU64Main := true
          if name == "lean_kernel_main_io" then hasIOMain := true

    let initWrapper := match initSymbol? with
      | some sym =>
        s!"extern void *{sym}(unsigned char, void *);
void *lean_kernel_module_init(unsigned char b, void *w) \{ return {sym}(b, w); }
"
      | none =>
        "void *lean_kernel_module_init(unsigned char b, void *w) { (void)b; (void)w; return (void *)1; }
"
    unless hasIOMain || hasU64Main do
      throw <| IO.userError <|
        "leanc --target=riscv64-unknown-none*: program exports no recognised entry symbol; " ++
        "expected `lean_kernel_main : UInt64` or `lean_kernel_main_io : BaseIO UInt64` " ++
        "(use `@[export <symbol>]` on your entry def)."
    let entryWrapper :=
      if hasIOMain then
        "extern unsigned long long lean_kernel_main_io(void *);
unsigned long long lean_kernel_invoke_entry(void) {
  return lean_kernel_main_io((void *)0);
}
"
      else
        "extern unsigned long long lean_kernel_main(void);
unsigned long long lean_kernel_invoke_entry(void) { return lean_kernel_main(); }
"
    let glueC := tmp / "lean_kernel_glue.c"
    IO.FS.writeFile glueC (initWrapper ++ entryWrapper)
    objects := objects.push (← compileRuntimeC glueC "lean_kernel_glue.o")

    let mut linkArgs : Array String :=
      #["--no-relax", "--gc-sections", "-o", output.toString]
    linkArgs := linkArgs ++ objects ++ a.linkArgs
    runOrFail lld linkArgs
    return 0

private def linkCross (root : FilePath) (args : List String) (triple : String) : IO UInt32 := do
  link root (← parseCrossArgs args triple)

def target : CrossTarget :=
  { triplePrefix := "riscv64-unknown-none", link := linkCross }

end RiscV64Freestanding
end Leanc
