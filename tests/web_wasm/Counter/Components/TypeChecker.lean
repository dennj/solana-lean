import Counter.Common

namespace Counter

def checkerExamplePackage : String :=
  "# Lean4Lean kernel package\n" ++
  "# checked by Lean4Lean compiled to WebAssembly\n" ++
  "module Tx\n" ++
  "level zero\n" ++
  "expr 0 sort 0\n" ++
  "expr 1 bvar 0\n" ++
  "expr 2 bvar 1\n" ++
  "expr 3 forall h 1 2\n" ++
  "expr 4 forall P 0 3\n" ++
  "expr 5 lam h 1 1\n" ++
  "expr 6 lam P 0 5\n" ++
  "decl def idProp 4 6\n" ++
  "decl theorem idPropThm 4 6\n"

def componentTypecheckerHtml : String :=
  componentHeaderHtml "Lean4Lean typechecker" "Edit or upload a serialized kernel declaration package and check it in browser WebAssembly." ++
  "<div class=\"component-preview checker-preview\">" ++
    "<div class=\"artifact-upload\">" ++
      "<label class=\"artifact-picker\" for=\"checker-file\">Upload package</label>" ++
      "<input id=\"checker-file\" type=\"file\" accept=\".lean4kernel,.txt,text/plain\">" ++
      "<span id=\"checker-file-name\">Using sample package</span>" ++
    "</div>" ++
    "<textarea id=\"checker-input\" spellcheck=\"false\" autocomplete=\"off\">" ++ checkerExamplePackage ++ "</textarea>" ++
    "<div class=\"checker-actions\">" ++
      "<button id=\"checker-button\" class=\"button primary\" type=\"button\">Check package</button>" ++
      "<span id=\"checker-status\" class=\"checker-status pending\">Typechecker wasm loading</span>" ++
    "</div>" ++
    "<p class=\"component-note\">The browser passes text bytes to Lean4Lean compiled as WebAssembly. Parsing, declaration reconstruction, and type checking run inside Lean code.</p>" ++
  "</div>"

end Counter
