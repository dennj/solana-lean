/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
-/
import Init.System.IO

open System (FilePath)

namespace Leanc

def findTarget? : List String → Option String
  | [] => none
  | "--target" :: triple :: _ => some triple
  | a :: rest =>
    if a.startsWith "--target=" then
      some ((a.drop "--target=".length).toString)
    else
      findTarget? rest

structure CrossTarget where
  triplePrefix : String
  link         : FilePath → List String → String → IO UInt32

def CrossTarget.matches (t : CrossTarget) (triple : String) : Bool :=
  triple.startsWith t.triplePrefix

structure CrossArgs where
  triple      : String
  output      : Option FilePath := none
  inputs      : Array FilePath := #[]
  compileArgs : Array String := #[]
  linkArgs    : Array String := #[]
  deriving Inhabited

private def hasInputExt (arg : String) : Bool :=
  arg.endsWith ".bc" || arg.endsWith ".c" || arg.endsWith ".s" ||
  arg.endsWith ".S" || arg.endsWith ".o"

private def splitWlArg (arg : String) : Array String :=
  ((arg.drop "-Wl,".length).toString.splitOn ",").toArray.filter (!·.isEmpty)

private def compileArgsWithValue : Array String :=
  #["-I", "-D", "-U", "-include", "-isystem", "-iquote", "-idirafter",
    "-imacros", "-isysroot", "-Xclang"]

private def linkArgsWithValue : Array String :=
  #["-L", "-l", "-T", "-e", "-u", "-z", "--entry", "--export",
    "--export-if-defined", "--undefined", "--initial-memory", "--max-memory", "--global-base",
    "--allow-undefined-file", "-Xlinker"]

private def isCompileArg (arg : String) : Bool :=
  arg.startsWith "-I" || arg.startsWith "-D" || arg.startsWith "-U" ||
  arg.startsWith "-isystem" || arg.startsWith "-iquote" ||
  arg.startsWith "-idirafter" || arg.startsWith "-std=" ||
  arg.startsWith "-O" || arg.startsWith "-g" ||
  arg.startsWith "-f" || arg.startsWith "-m" ||
  (arg.startsWith "-W" && !arg.startsWith "-Wl,")

private def isLinkArg (arg : String) : Bool :=
  arg.startsWith "-L" || arg.startsWith "-l" ||
  arg.startsWith "--entry=" || arg.startsWith "--export=" ||
  arg.startsWith "--export-if-defined=" ||
  arg.startsWith "--undefined=" || arg.startsWith "--initial-memory=" ||
  arg.startsWith "--max-memory=" || arg.startsWith "--global-base=" ||
  arg == "--no-entry" || arg == "--allow-undefined" ||
  arg == "--import-undefined" || arg == "--export-memory" ||
  arg == "--strip-all" || arg == "--gc-sections"

def parseCrossArgs (args : List String) (triple : String) : IO CrossArgs := do
  let mut acc : CrossArgs := { triple }
  let mut rest := args
  while !rest.isEmpty do
    match rest with
    | "-o" :: v :: t =>
      acc := { acc with output := some (FilePath.mk v) }
      rest := t
    | "--target" :: _ :: t =>
      rest := t
    | a :: t =>
      if a.startsWith "--target=" then
        rest := t
      else if a.startsWith "-o" && a.length > 2 then
        acc := { acc with output := some (FilePath.mk ((a.drop 2).toString)) }
        rest := t
      else if hasInputExt a then
        acc := { acc with inputs := acc.inputs.push (FilePath.mk a) }
        rest := t
      else if a == "--leanc-link-arg" then
        match t with
        | v :: t' =>
          acc := { acc with linkArgs := acc.linkArgs.push v }
          rest := t'
        | [] =>
          throw <| IO.userError s!"argument missing for option '{a}'"
      else if a.startsWith "--leanc-link-arg=" then
        acc := { acc with linkArgs := acc.linkArgs.push ((a.drop "--leanc-link-arg=".length).toString) }
        rest := t
      else if a.startsWith "-Wl," then
        acc := { acc with linkArgs := acc.linkArgs ++ splitWlArg a }
        rest := t
      else if compileArgsWithValue.any (· == a) then
        match t with
        | v :: t' =>
          acc := { acc with compileArgs := acc.compileArgs ++ #[a, v] }
          rest := t'
        | [] =>
          throw <| IO.userError s!"argument missing for option '{a}'"
      else if linkArgsWithValue.any (· == a) then
        match t with
        | v :: t' =>
          acc := { acc with linkArgs := acc.linkArgs ++ #[a, v] }
          rest := t'
        | [] =>
          throw <| IO.userError s!"argument missing for option '{a}'"
      else if isCompileArg a then
        acc := { acc with compileArgs := acc.compileArgs.push a }
        rest := t
      else if isLinkArg a then
        acc := { acc with linkArgs := acc.linkArgs.push a }
        rest := t
      else
        acc := { acc with linkArgs := acc.linkArgs.push a }
        rest := t
    | [] => break
  return acc

def runOrFail (cmd : String) (args : Array String) : IO Unit := do
  let child ← IO.Process.spawn { cmd, args }
  let code ← child.wait
  if code != 0 then
    throw <| IO.userError s!"command failed (exit {code}): {cmd} {" ".intercalate args.toList}"

def firstExisting (paths : Array FilePath) : IO (Option FilePath) := do
  for p in paths do
    if (← p.pathExists) then
      return some p
  return none

end Leanc
