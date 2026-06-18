import Counter.Components.Calendar
import Counter.Components.Index
import Counter.Components.Plot
import Counter.Components.Todo
import Counter.Components.TypeChecker
import Counter.Targets

namespace Counter

def heroCopyHtml : String :=
  "A component gallery rendered by Lean4Wasm for the Lean4 freestanding targets: " ++
  "Lean4Solana, Lean4Wasm, and Lean4Linux. The first screen is a UI registry backed by a " ++
  "persistent Lean WebAssembly reactor."

def heroActionsHtml : String :=
  "<a class=\"button primary\" href=\"#components\">Browse components</a>" ++
  "<a class=\"button secondary\" href=\"#runtime\">Runtime</a>"

def pipelineCopyHtml : String :=
  "The fork makes Lean's LLVM backend triple-aware, gives Lake cross-program targets, and " ++
  "turns unsupported host calls into source-level diagnostics before linking begins."

def pipelineStepsHtml : String :=
  "<li><span class=\"step\">01</span><span><strong>Elaborate Lean</strong>Definitions and theorems are checked by Lean's kernel.</span></li>" ++
  "<li><span class=\"step\">02</span><span><strong>Emit target bitcode</strong>Data layout, size types, Nat caps, and symbol visibility follow the triple.</span></li>" ++
  "<li><span class=\"step\">03</span><span><strong>Link an adapter</strong>SBF, WebAssembly, and Linux paths bind only the ABI they provide.</span></li>" ++
  "<li><span class=\"step\">04</span><span><strong>Ship the artifact</strong>The output is an SBF .so, browser .wasm, freestanding ELF/blob, or Linux object.</span></li>"

def runtimeCopyHtml : String :=
  "The freestanding runtime provides Lean objects, strings, arrays, closures, deterministic " ++
  "reference counting, and copy-on-write behavior without depending on the host runtime."

def runtimeContractHtml : String :=
  listItemsHtml #[
    "Embedder-supplied heap with reclaiming allocation and coalescing free blocks.",
    "Single-threaded reference counting with persistence and exclusivity semantics.",
    "Copy-on-write arrays and scalar arrays that preserve Lean semantics on aliases.",
    "Small-Nat and small-Int bounds enforced by compile-time and runtime checks."
  ]

def liveCopyHtml : String :=
  "The HTML exposes browser-detectable Lean4Wasm markers. The generated WebAssembly module " ++
  "also contains a lean4wasm custom section, so tooling can identify the artifact directly."

@[export lean_render]
def render (calendarState todoCount todoDoneMask events amplitude frequency : UInt32) : BaseIO Unit := do
  Std.Web.setHtml "hero-copy" heroCopyHtml
  Std.Web.setHtml "hero-actions" heroActionsHtml
  Std.Web.setHtml "component-copy" componentCopyHtml
  Std.Web.setHtml "component-index" componentIndexHtml
  Std.Web.setHtml "component-calendar" (componentCalendarHtml calendarState)
  renderTodo todoCount todoDoneMask
  Std.Web.setHtml "component-plot" (componentPlotHtml amplitude frequency)
  Std.Web.setHtml "component-typechecker" componentTypecheckerHtml
  Std.Web.setHtml "target-strip" targetChipsHtml
  Std.Web.setHtml "targets-copy" targetsCopyHtml
  Std.Web.setHtml "target-grid" targetGridHtml
  Std.Web.setHtml "pipeline-copy" pipelineCopyHtml
  Std.Web.setHtml "pipeline-steps" pipelineStepsHtml
  Std.Web.setHtml "runtime-copy" runtimeCopyHtml
  Std.Web.setHtml "runtime-contract" runtimeContractHtml
  Std.Web.setText "runtime-code-1" "lean --target=sbf-solana-solana Foo.lean"
  Std.Web.setText "runtime-code-2" "leanc --target=sbf-solana-solana Foo.bc -o Foo.so"
  Std.Web.setText "runtime-code-3" "lean --target=wasm32-unknown-unknown App.lean"
  Std.Web.setText "runtime-code-4" "leanc --target=wasm32-unknown-unknown App.bc -o App.wasm"
  Std.Web.setText "runtime-code-5" "lean --target=riscv64-unknown-none-elf NlAttrCore.lean"
  Std.Web.setText "runtime-code-6" "ld.lld -r lean_nlattr_core.o -o lib/lean_nlattr_core.o"
  Std.Web.setHtml "live-copy" liveCopyHtml
  Std.Web.setText "counter" (counterText events)

end Counter
