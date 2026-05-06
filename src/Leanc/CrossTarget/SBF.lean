/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Leanc.CrossTarget

open System (FilePath)

namespace Leanc
namespace SBF

private def findPlatformTools : IO FilePath := do
  if let some p ← IO.getEnv "LEAN_SOLANA_TOOLS" then
    let fp := FilePath.mk p
    if (← fp.pathExists) then
      return fp
    throw <| IO.userError s!"LEAN_SOLANA_TOOLS={p} does not exist"
  if let some home ← IO.getEnv "HOME" then
    let cache := FilePath.mk home / ".cache" / "solana"
    if (← cache.pathExists) then
      let mut newest? : Option FilePath := none
      for entry in (← cache.readDir) do
        let pt := entry.path / "platform-tools"
        if (← pt.pathExists) then
          newest? := some pt
      if let some pt := newest? then
        return pt
  throw <| IO.userError <|
    "platform-tools not found. Set LEAN_SOLANA_TOOLS=<path>, or install via " ++
    "`agave-install init` (https://docs.solanalabs.com/cli/install)."

private def link (root : FilePath) (a : CrossArgs) : IO UInt32 := do
  let pt ← findPlatformTools
  let llvmBin := pt / "llvm" / "bin"
  let clang := (llvmBin / "clang").toString
  let llc   := (llvmBin / "llc").toString
  let lld   := (llvmBin / "ld.lld").toString
  let sbfDir := root / "lib" / "lean" / "sbf"
  let freestandingDir := root / "lib" / "lean" / "freestanding"
  let sbfLd := sbfDir / "sbf.ld"
  let entrypointC := sbfDir / "entrypoint.c"
  let stubsC := sbfDir / "stubs.c"
  let runtimeC := sbfDir / "runtime.c"
  let freestandingRuntimeC := freestandingDir / "runtime.c"
  unless (← sbfLd.pathExists) do
    throw <| IO.userError s!"missing SBF runtime adapter at {sbfDir} \
      (expected sbf.ld, entrypoint.c, stubs.c, runtime.c)"
  unless (← freestandingRuntimeC.pathExists) do
    throw <| IO.userError s!"missing freestanding runtime at {freestandingDir} \
      (expected runtime.c)"
  let some output := a.output
    | throw <| IO.userError "leanc --target=sbf-*: -o <file> is required"

  IO.FS.withTempDir fun tmp => do
    let mut objects : Array String := #[]
    let freestandingIncludeArgs : Array String := #["-I", freestandingDir.toString]

    let compileBc (bc : FilePath) (objName : String) : IO String := do
      let obj := (tmp / objName).toString
      runOrFail llc #["-O2", "-relocation-model=pic", "--filetype=obj",
                      bc.toString, "-o", obj]
      return obj
    let compileUserC (c : FilePath) (objName : String) : IO String := do
      let obj := (tmp / objName).toString
      runOrFail clang (#[s!"--target={a.triple}", "-O2", "-fPIC"] ++
        freestandingIncludeArgs ++ a.compileArgs ++ #["-c", c.toString, "-o", obj])
      return obj
    -- SBF VM heap layout: 32 KB at 0x3_0000_0000, with a 24-byte prefix
    -- reserving slots for bump-pointer + loader-input pointer + account-table
    -- pointer. These are SBF-specific and must be passed to the otherwise-
    -- target-agnostic freestanding runtime.
    let sbfHeapDefs : Array String :=
      #["-DLEAN_FREESTANDING_HEAP_BASE=0x300000000UL",
        "-DLEAN_FREESTANDING_HEAP_BYTES=(32*1024)",
        "-DLEAN_FREESTANDING_HEAP_PREFIX=24"]
    let compileRuntimeC (c : FilePath) (objName : String) : IO String := do
      let obj := (tmp / objName).toString
      runOrFail clang (#[s!"--target={a.triple}", "-O2", "-fPIC"] ++
        freestandingIncludeArgs ++ sbfHeapDefs ++ #["-c", c.toString, "-o", obj])
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
        else if ext == "o" then
          leanObjs := leanObjs.push inp.toString
          pure inp.toString
        else
          throw <| IO.userError s!"unsupported input extension '.{ext}': {inp}"
      objects := objects.push obj

    objects := objects.push (← compileRuntimeC entrypointC "entrypoint.o")
    objects := objects.push (← compileRuntimeC stubsC "stubs.o")
    objects := objects.push (← compileRuntimeC freestandingRuntimeC "freestanding_runtime.o")
    objects := objects.push (← compileRuntimeC runtimeC "runtime.o")

    let mut initSymbol? : Option String := none
    let mut hasTypedEntry := false
    let readelf := (llvmBin / "llvm-readelf").toString
    for objPath in leanObjs do
      let out ← IO.Process.output { cmd := readelf, args := #["--syms", objPath] }
      if out.exitCode != 0 then
        throw <| IO.userError s!"llvm-readelf failed on {objPath}: {out.stderr}"
      for ln in out.stdout.splitOn "\n" do
        let parts := ln.trimAscii.toString.splitOn " " |>.filter (·.length > 0)
        if parts.length == 8 then
          let typ := parts[3]!
          let ndx := parts[6]!
          let name := parts[7]!
          let defined := ndx != "UND" && typ == "FUNC"
          if defined then
            if name.startsWith "initialize_" && name != "initialize_Init"
                && initSymbol?.isNone then
              initSymbol? := some name
            if name == "lean_sol_entry_typed" then hasTypedEntry := true

    let initWrapper := match initSymbol? with
      | some sym =>
        s!"extern void *{sym}(unsigned char, void *);
void *lean_sbf_module_init(unsigned char b) \{ return {sym}(b, (void *)0); }
"
      | none =>
        "void *lean_sbf_module_init(unsigned char b) { (void)b; return (void *)1; }
"
    unless hasTypedEntry do
      throw <| IO.userError <|
        "leanc --target=sbf-*: program exports no recognised entry symbol; " ++
        "expected `lean_sol_entry_typed` " ++
        "(use `@[export lean_sol_entry_typed]` on your `(ProgramContext) -> UInt64` entry def, " ++
        "or import `Std.Solana`)."
    let entryWrapper :=
      "extern unsigned long long lean_sol_entry_typed(void *);
extern void *lean_sbf_make_program_context(const unsigned char *);
unsigned long long lean_sbf_invoke_entry(const unsigned char *input) {
  return lean_sol_entry_typed(lean_sbf_make_program_context(input));
}
"
    let glueC := tmp / "lean_sbf_glue.c"
    IO.FS.writeFile glueC (initWrapper ++ entryWrapper)
    objects := objects.push (← compileRuntimeC glueC "lean_sbf_glue.o")

    let mut linkArgs : Array String :=
      #["-z", "notext", "-shared", "--Bdynamic",
        "-T", sbfLd.toString,
        "--entry", "entrypoint",
        "-o", output.toString]
    linkArgs := linkArgs ++ objects ++ a.linkArgs
    runOrFail lld linkArgs
    return 0

private def linkCross (root : FilePath) (args : List String) (triple : String) : IO UInt32 := do
  link root (← parseCrossArgs args triple)

def target : CrossTarget :=
  { triplePrefix := "sbf-", link := linkCross }

end SBF
end Leanc
