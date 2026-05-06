/-! Probe: mutually-defined structures via forward references through
`Option`. Each structure references the other through a wrapper type, so
the codegen must handle the cycle-breaking via boxing. -/

mutual
  structure Forest where
    trees : List Tree

  structure Tree where
    value : UInt64
    children : Forest
end

def emptyForest : Forest := { trees := [] }

def leaf (v : UInt64) : Tree :=
  { value := v, children := emptyForest }

def branch (v : UInt64) (kids : List Tree) : Tree :=
  { value := v, children := { trees := kids } }

mutual
  partial def sumTree (t : Tree) : UInt64 :=
    t.value + sumForest t.children

  partial def sumForest (f : Forest) : UInt64 :=
    f.trees.foldl (fun acc t => acc + sumTree t) 0
end

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  -- A small tree: 1 -> [2 -> [4, 5], 3 -> [6]]
  let t := branch 1 [
    branch 2 [leaf 4, leaf 5],
    branch 3 [leaf 6]
  ]
  let s := sumTree t
  -- 1 + (2 + 4 + 5) + (3 + 6) = 21
  if s == 21 then 0 else 99
