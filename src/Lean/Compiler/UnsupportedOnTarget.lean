/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Siddharth Bhat
-/
module

prelude
public import Lean.MonadEnv

public section

namespace Lean.Compiler

structure UnsupportedOnTargetData where
  triplePattern : String
  reason        : String
  deriving Inhabited, BEq

@[expose] def UnsupportedOnTargetMap := NameMap (Array UnsupportedOnTargetData)
  deriving EmptyCollection, Inhabited

initialize unsupportedOnTargetExt :
    SimplePersistentEnvExtension (Name × UnsupportedOnTargetData) UnsupportedOnTargetMap ←
  let insert := fun (m : UnsupportedOnTargetMap) (e : Name × UnsupportedOnTargetData) =>
    m.insert e.1 (((m.find? e.1).getD #[]).push e.2)
  registerSimplePersistentEnvExtension {
    addImportedFn := mkStateFromImportedEntries insert {}
    addEntryFn    := insert
    toArrayFn     := (·.toArray)
  }

/-- Glob-match a triple against a pattern; only `*` (any substring) is supported. -/
partial def tripleMatches (pattern triple : String) : Bool :=
  go pattern.toList triple.toList
where
  go : List Char → List Char → Bool
    | [],         ts      => ts.isEmpty
    | '*' :: ps,  ts      => go ps ts || (!ts.isEmpty && go ('*' :: ps) ts.tail!)
    | _ :: _,     []      => false
    | p :: ps,    t :: ts => p == t && go ps ts

def collectUnsupportedOnTarget (env : Environment) (triple : String)
    (usedSet : NameSet) : Array (Name × UnsupportedOnTargetData) :=
  unsupportedOnTargetExt.getState env |>.foldl (init := #[]) fun acc n ds =>
    if usedSet.contains n then
      ds.foldl (init := acc) fun a d =>
        if tripleMatches d.triplePattern triple then a.push (n, d) else a
    else acc

end Lean.Compiler
