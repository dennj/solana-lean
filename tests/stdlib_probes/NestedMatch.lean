/-! Probe: deeply nested pattern match over a Tree inductive. -/
inductive Tree where
  | leaf : UInt64 → Tree
  | node : Tree → Tree → Tree

partial def sumTree : Tree → UInt64
  | Tree.leaf n => n
  | Tree.node l r => sumTree l + sumTree r

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let t : Tree :=
    Tree.node
      (Tree.node (Tree.leaf 1) (Tree.leaf 2))
      (Tree.node (Tree.leaf 3) (Tree.node (Tree.leaf 4) (Tree.leaf 32)))
  if sumTree t == 42 then 0 else 99
