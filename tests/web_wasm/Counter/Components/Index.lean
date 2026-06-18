import Counter.Common

namespace Counter

structure ComponentSpec where
  anchor : String
  name : String
  state : String
  detail : String

def components : Array ComponentSpec := #[
  { anchor := "component-calendar", name := "Calendar", state := "stateful", detail := "Lean selects and formats days." },
  { anchor := "component-checklist", name := "Todo list", state := "editable", detail := "Lean renders task rows and completion state." },
  { anchor := "component-plot", name := "Plot", state := "signal", detail := "Lean chooses waveform amplitude and frequency." },
  { anchor := "component-typechecker", name := "Artifact checker", state := "wasm kernel", detail := "Lean4Lean checks uploaded declaration packages." }
]

theorem component_count_checked : components.size = 4 := rfl

def componentCopyHtml : String :=
  "A shadcn-style component catalog rendered from Lean data. The browser shell owns layout slots; " ++
  "Lean fills the component registry, previews, computed labels, and event-dependent state."

def componentIndexItemHtml (c : ComponentSpec) : String :=
  "<a href=\"#" ++ c.anchor ++ "\">" ++
    "<strong>" ++ c.name ++ "</strong>" ++
    "<span>" ++ c.state ++ "</span>" ++
  "</a>"

def componentIndexHtml : String :=
  "<p>Lean component registry</p>" ++
  components.foldl (fun acc c => acc ++ componentIndexItemHtml c) ""

end Counter
