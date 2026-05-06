/-! Probe: structure with mixed scalar/object fields and projection. -/
structure Point where
  x : UInt64
  y : UInt64
  label : String

structure Line where
  start : Point
  finish : Point

@[export lean_wasm_main]
def entry (_x : UInt64) : UInt64 :=
  let l : Line :=
    { start := { x := 10, y := 20, label := "origin" }
    , finish := { x := 30, y := 32, label := "end" } }
  let dx := l.finish.x - l.start.x
  let dy := l.finish.y - l.start.y
  if dx + dy == 32 && l.start.label.length == 6 then 0 else 99
