/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Leanc.CrossTarget

open System (FilePath)

namespace Leanc
namespace Wasm

private inductive Mode where
  | wasi
  | web
  deriving BEq

private def modeForTriple (triple : String) : Mode :=
  if triple == "wasm32-unknown-unknown" then .web else .wasi

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
    FilePath.mk s!"/opt/homebrew/bin/{tool}",
    FilePath.mk s!"/usr/local/opt/llvm/bin/{tool}",
    FilePath.mk s!"/usr/lib/llvm-19/bin/{tool}",
    FilePath.mk s!"/usr/lib/llvm-18/bin/{tool}",
    FilePath.mk s!"/usr/bin/{tool}-19",
    FilePath.mk s!"/usr/bin/{tool}-18",
    FilePath.mk s!"/usr/bin/{tool}"]

private def scanRustlibWasmLd (root : FilePath) : IO (Array FilePath) := do
  let mut acc : Array FilePath := #[]
  unless (← root.pathExists) do return acc
  for entry in (← root.readDir) do
    let rustlib := entry.path / "lib" / "rustlib"
    unless (← rustlib.pathExists) do continue
    for tripleEntry in (← rustlib.readDir) do
      let p := tripleEntry.path / "bin" / "gcc-ld" / "wasm-ld"
      if (← p.pathExists) then acc := acc.push p
  return acc

private def findTools (needWebTools : Bool) : IO (FilePath × FilePath × FilePath × Option FilePath × Option FilePath) := do
  let clangPath ← match (← IO.getEnv "LEAN_WASM_CLANG") with
    | some p => pure (FilePath.mk p)
    | none =>
      let some p ← firstExisting clangCandidates
        | throw <| IO.userError "wasm clang not found. Set LEAN_WASM_CLANG=<path> or install LLVM (e.g. `brew install llvm@19` / `apt install llvm-19`)."
      pure p
  let ldPath ← match (← IO.getEnv "LEAN_WASM_LD") with
    | some p => pure (FilePath.mk p)
    | none =>
      let mut candidates := llvmToolCandidates "wasm-ld"
      if let some home ← IO.getEnv "HOME" then
        candidates := candidates ++ (← scanRustlibWasmLd (FilePath.mk home / ".rustup" / "toolchains"))
        let solanaCache := FilePath.mk home / ".cache" / "solana"
        if (← solanaCache.pathExists) then
          for v in (← solanaCache.readDir) do
            candidates := candidates ++ (← scanRustlibWasmLd (v.path / "platform-tools" / "rust"))
      let some p ← firstExisting candidates
        | throw <| IO.userError "wasm-ld not found. Set LEAN_WASM_LD=<path>, install LLVM with wasm-ld, or run `agave-install init`."
      pure p
  let nmPath ← match (← IO.getEnv "LEAN_WASM_NM") with
    | some p => pure (FilePath.mk p)
    | none =>
      let nextToClang := (clangPath.parent.getD (FilePath.mk ".")) / "llvm-nm"
      let candidates := #[nextToClang] ++ llvmToolCandidates "llvm-nm"
      let some p ← firstExisting candidates
        | throw <| IO.userError "llvm-nm not found. Set LEAN_WASM_NM=<path> or install LLVM."
      pure p
  let readobjPath? : Option FilePath ←
    if needWebTools then
      match (← IO.getEnv "LEAN_WASM_READOBJ") with
      | some p => pure (some (FilePath.mk p))
      | none =>
        let nextToClang := (clangPath.parent.getD (FilePath.mk ".")) / "llvm-readobj"
        let candidates := #[nextToClang] ++ llvmToolCandidates "llvm-readobj"
        let some p ← firstExisting candidates
          | throw <| IO.userError "llvm-readobj not found. Set LEAN_WASM_READOBJ=<path> or install LLVM."
        pure (some p)
    else
      pure none
  let objcopyPath? : Option FilePath ←
    if needWebTools then
      match (← IO.getEnv "LEAN_WASM_OBJCOPY") with
      | some p => pure (some (FilePath.mk p))
      | none =>
        let nextToClang := (clangPath.parent.getD (FilePath.mk ".")) / "llvm-objcopy"
        let candidates := #[nextToClang] ++ llvmToolCandidates "llvm-objcopy"
        let some p ← firstExisting candidates
          | throw <| IO.userError "llvm-objcopy not found. Set LEAN_WASM_OBJCOPY=<path> or install LLVM."
        pure (some p)
    else
      pure none
  return (clangPath, ldPath, nmPath, readobjPath?, objcopyPath?)

private def lean4WasmMetadata (triple : String) : String :=
  "{\n" ++
  "  \"generator\": \"Lean4Wasm\",\n" ++
  "  \"language\": \"Lean 4\",\n" ++
  "  \"runtime\": \"Lean browser freestanding runtime\",\n" ++
  s!"  \"target\": \"{triple}\",\n" ++
  "  \"format\": 1\n" ++
  "}\n"

private def shouldExportWasmSymbol (name : String) : Bool :=
  !name.startsWith "initialize_" &&
  name != "__stack_pointer" &&
  name != "__heap_base" &&
  name != "__data_end"

private def parseDefinedExportedWasmFunctions (out : String) : Array String := Id.run do
  let mut acc : Array String := #[]
  let mut inSymbol := false
  let mut name? : Option String := none
  let mut isFunction := false
  let mut blocked := false
  for raw in out.splitOn "\n" do
    let ln := raw.trimAscii.toString
    if ln == "Symbol {" then
      inSymbol := true
      name? := none
      isFunction := false
      blocked := false
    else if inSymbol then
      if ln.startsWith "Name:" then
        name? := some ((ln.drop "Name:".length).trimAscii.toString)
      else if ln.startsWith "Type: FUNCTION" then
        isFunction := true
      else if ln.contains "UNDEFINED" || ln.contains "BINDING_LOCAL" || ln.contains "VISIBILITY_HIDDEN" then
        blocked := true
      else if ln == "}" then
        if isFunction && !blocked then
          if let some name := name? then
            if shouldExportWasmSymbol name && !acc.contains name then
              acc := acc.push name
        inSymbol := false
  return acc

private def link (root : FilePath) (a : CrossArgs) : IO UInt32 := do
  let mode := modeForTriple a.triple
  let (clangPath, ldPath, nmPath, readobjPath?, objcopyPath?) ← findTools (mode == .web)
  let clang := clangPath.toString
  let lld := ldPath.toString
  let nm := nmPath.toString
  let readobj? := readobjPath?.map (fun p => p.toString)
  let wasmDir := root / "lib" / "lean" / "wasm"
  let webDir := root / "lib" / "lean" / "web"
  let freestandingDir := root / "lib" / "lean" / "freestanding"
  let adapterDir := if mode == .web then webDir else wasmDir
  let entrypointC := adapterDir / "entrypoint.c"
  let stubsC := adapterDir / "stubs.c"
  let runtimeC := adapterDir / "runtime.c"
  let freestandingRuntimeC := freestandingDir / "runtime.c"
  if mode == .wasi then
    unless (← entrypointC.pathExists) do
      throw <| IO.userError s!"missing WASI runtime adapter at {adapterDir} \
        (expected entrypoint.c, stubs.c, runtime.c)"
  unless (← stubsC.pathExists) && (← runtimeC.pathExists) do
    throw <| IO.userError s!"missing WASM runtime adapter at {adapterDir} \
      (expected stubs.c and runtime.c)"
  unless (← freestandingRuntimeC.pathExists) do
    throw <| IO.userError s!"missing freestanding runtime at {freestandingDir} \
      (expected runtime.c)"
  let some output := a.output
    | throw <| IO.userError "leanc --target=wasm32-*: -o <file> is required"

  IO.FS.withTempDir fun tmp => do
    let mut objects : Array String := #[]
    let freestandingIncludeArgs : Array String := #["-I", freestandingDir.toString]
    let wasmHeapDefs : Array String :=
      #["-DLEAN_FREESTANDING_HEAP_BASE=0x100000U",
        "-DLEAN_FREESTANDING_HEAP_BYTES=4194304U",
        "-DLEAN_FREESTANDING_HEAP_PREFIX=8U"]
    let compileBc (bc : FilePath) (objName : String) : IO String := do
      let obj := (tmp / objName).toString
      runOrFail clang #[s!"--target={a.triple}", "-O2", "-c", bc.toString, "-o", obj]
      return obj
    let compileUserC (c : FilePath) (objName : String) : IO String := do
      let obj := (tmp / objName).toString
      let args := #[s!"--target={a.triple}", "-O2", "-nostdlibinc",
                    "-fno-stack-protector"] ++ freestandingIncludeArgs ++ wasmHeapDefs ++
                  a.compileArgs ++ #["-c", c.toString, "-o", obj]
      runOrFail clang args
      return obj
    let compileRuntimeC (c : FilePath) (objName : String) : IO String := do
      let obj := (tmp / objName).toString
      let args := #[s!"--target={a.triple}", "-O2", "-nostdlibinc",
                    "-fno-stack-protector"] ++ freestandingIncludeArgs ++ wasmHeapDefs ++
                  #["-c", c.toString, "-o", obj]
      runOrFail clang args
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

    if mode == .wasi then
      objects := objects.push (← compileRuntimeC entrypointC "entrypoint.o")
    objects := objects.push (← compileRuntimeC stubsC "stubs.o")
    objects := objects.push (← compileRuntimeC freestandingRuntimeC "freestanding_runtime.o")
    objects := objects.push (← compileRuntimeC runtimeC "runtime.o")

    let mut initSymbol? : Option String := none
    let mut hasU64Main := false
    let mut hasIOMain := false
    let mut webExportSymbols : Array String := #[]
    for objPath in leanObjs do
      let out ← IO.Process.output { cmd := nm, args := #["--defined-only", objPath] }
      if out.exitCode != 0 then
        throw <| IO.userError s!"llvm-nm failed on {objPath}: {out.stderr}"
      for ln in out.stdout.splitOn "\n" do
        let parts := ln.trimAscii.toString.splitOn " " |>.filter (·.length > 0)
        if let some (name : String) := parts.toArray.back? then
          if name.startsWith "initialize_" && name != "initialize_Init"
              && name != "initialize_Std_Wasm" && name != "initialize_Std_Web"
              && initSymbol?.isNone then
            initSymbol? := some name
          if name == "lean_wasm_main" then hasU64Main := true
          if name == "lean_wasm_main_io" then hasIOMain := true
      if mode == .web then
        let some readobj := readobj?
          | throw <| IO.userError "internal error: web wasm link missing llvm-readobj path"
        let out ← IO.Process.output { cmd := readobj, args := #["--symbols", objPath] }
        if out.exitCode != 0 then
          throw <| IO.userError s!"llvm-readobj failed on {objPath}: {out.stderr}"
        for name in parseDefinedExportedWasmFunctions out.stdout do
          if !webExportSymbols.contains name then
            webExportSymbols := webExportSymbols.push name

    let initWrapper := match initSymbol? with
      | some sym =>
        s!"extern void *{sym}(unsigned char, void *);
void *lean_wasm_module_init(unsigned char b, void *w) \{ return {sym}(b, w); }
"
      | none =>
        "void *lean_wasm_module_init(unsigned char b, void *w) { (void)b; (void)w; return (void *)1; }
"
    let entryWrapper ←
      if mode == .wasi then do
        unless hasIOMain || hasU64Main do
          throw <| IO.userError <|
            "leanc --target=wasm32-wasip1: program exports no recognised entry symbol; " ++
            "expected `lean_wasm_main : UInt64 → UInt64` or `lean_wasm_main_io : BaseIO UInt64` " ++
            "(use `@[export <symbol>]` on your entry def)."
        pure <| if hasIOMain then
          "extern unsigned long long lean_wasm_main_io(void *);
unsigned long long lean_wasm_invoke_entry(void) {
  return lean_wasm_main_io((void *)0);
}
"
        else
          "extern unsigned long long lean_wasm_main(unsigned long long);
unsigned long long lean_wasm_invoke_entry(void) { return lean_wasm_main(0); }
"
      else
        pure
          "unsigned lean_web_init(void) {
  (void)lean_wasm_module_init(1, (void *)0);
  return 0;
}
"
    let glueC := tmp / "lean_wasm_glue.c"
    IO.FS.writeFile glueC (initWrapper ++ entryWrapper)
    objects := objects.push (← compileRuntimeC glueC "lean_wasm_glue.o")

    let mut linkArgs : Array String :=
      if mode == .web then
        #["--no-entry",
          "--export-memory",
          "--export=lean_web_init",
          "--export=lean_web_string_byte_size",
          "--export=lean_web_string_data",
          "--export=lean_web_alloc_bytes",
          "--export=lean_web_mk_string_from_bytes",
          "--import-undefined",
          "--initial-memory=8388608",
          "-o", output.toString]
      else
        #["--no-entry",
          "--export=_start",
          "--initial-memory=8388608",
          "-o", output.toString]
    if mode == .web then
      for name in webExportSymbols do
        linkArgs := linkArgs.push s!"--export={name}"
    linkArgs := linkArgs ++ objects ++ a.linkArgs
    runOrFail lld linkArgs
    if mode == .web then
      let some objcopyPath := objcopyPath?
        | throw <| IO.userError "internal error: web wasm link missing llvm-objcopy path"
      let objcopy := objcopyPath.toString
      let metadataFile := tmp / "lean4wasm.json"
      let patchedOutput := tmp / "lean4wasm.patched.wasm"
      IO.FS.writeFile metadataFile (lean4WasmMetadata a.triple)
      runOrFail objcopy
        #["--add-section", s!"lean4wasm={metadataFile}", output.toString, patchedOutput.toString]
      try
        IO.FS.removeFile output
      catch
        | _ => pure ()
      IO.FS.rename patchedOutput output
    return 0

private def linkCross (root : FilePath) (args : List String) (triple : String) : IO UInt32 := do
  link root (← parseCrossArgs args triple)

def target : CrossTarget :=
  { triplePrefix := "wasm32-", link := linkCross }

end Wasm
end Leanc
