import Counter.Common

namespace Counter

def todoMaxItems : Nat := 6

def pow2Small (exp : Nat) : Nat :=
  go exp 1
where
  go : Nat -> Nat -> Nat
    | 0, acc => acc
    | n + 1, acc => go n (acc + acc)

def todoBit (idx : Nat) : UInt32 :=
  UInt32.ofNat (pow2Small idx)

def todoDone (mask : UInt32) (idx : Nat) : Bool :=
  (mask &&& todoBit idx) != 0

def todoCountNat (count : UInt32) : Nat :=
  min count.toNat todoMaxItems

def todoDoneCount (mask count : UInt32) : Nat :=
  (natRange (todoCountNat count)).foldl
    (fun total idx => if todoDone mask idx then total + 1 else total)
    0

def todoItemHtml (mask : UInt32) (idx : Nat) : String :=
  let index := natString idx
  let done := todoDone mask idx
  let doneClass := if done then " done" else ""
  let checked := if done then " checked" else ""
  "<li class=\"todo-item" ++ doneClass ++ "\">" ++
    "<label class=\"todo-check-row\">" ++
      "<input type=\"checkbox\" data-lean-state=\"todo-toggle\" data-lean-index=\"" ++ index ++ "\"" ++ checked ++ ">" ++
      "<span id=\"todo-text-" ++ index ++ "\"></span>" ++
    "</label>" ++
  "</li>"

def todoItemsHtml (count mask : UInt32) : String :=
  let visible := todoCountNat count
  if visible == 0 then
    "<li class=\"todo-empty\">No tasks yet.</li>"
  else
    concatMapHtml (natRange visible) (todoItemHtml mask)

def todoSummaryHtml (count mask : UInt32) : String :=
  let visible := todoCountNat count
  if visible == 0 then
    "Add a task to begin."
  else
    "Lean todo state: " ++ smallNatString (todoDoneCount mask count) ++ "/" ++ smallNatString visible ++ " done"

def componentTodoHtml (count mask : UInt32) : String :=
  componentHeaderHtml "Todo list" "Lean renders task rows and checkbox state; JS only stores the textbox strings." ++
  "<div class=\"component-preview\">" ++
    "<form class=\"todo-add-row\" data-lean-form=\"todo\">" ++
      "<input id=\"todo-input\" type=\"text\" autocomplete=\"off\" placeholder=\"Add a task\">" ++
      "<button class=\"button primary\" type=\"submit\">Add</button>" ++
    "</form>" ++
    "<ul class=\"todo-list\">" ++ todoItemsHtml count mask ++ "</ul>" ++
    "<p class=\"component-note\">" ++ todoSummaryHtml count mask ++ "</p>" ++
  "</div>"

@[export lean_render_todo]
def renderTodo (count mask : UInt32) : BaseIO Unit := do
  Std.Web.setHtml "component-checklist" (componentTodoHtml count mask)

end Counter
