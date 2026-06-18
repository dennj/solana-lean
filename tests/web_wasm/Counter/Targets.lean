import Counter.Common

namespace Counter

inductive TargetKind where
  | solana
  | wasm
  | linux

namespace TargetKind

def accent : TargetKind -> String
  | solana => "var(--solana)"
  | wasm => "var(--wasm)"
  | linux => "var(--linux)"

end TargetKind

structure Target where
  kind : TargetKind
  name : String
  artifact : String
  summary : String
  points : Array String

def targets : Array Target := #[
  {
    kind := .solana,
    name := "Lean4Solana",
    artifact := "Std.Solana / SBF .so",
    summary :=
      "Solana programs written in Lean 4, with safety theorems checked before the deployable SBF object is emitted.",
    points := #[
      "The Colosseum vault proves deposit and withdraw preserve its accounting invariant.",
      "Std.Solana mirrors account, instruction, PDA, and CPI surfaces in Lean.",
      "The SBF adapter parses the loader buffer and calls lean_sol_entry_typed."
    ]
  },
  {
    kind := .wasm,
    name := "Lean4Wasm",
    artifact := "Std.Web / browser .wasm",
    summary :=
      "Browser reactor modules with no WASI imports, exported Lean callbacks, and a tiny JS import object.",
    points := #[
      "lean_web_init keeps the instance alive instead of running _start once.",
      "@[export] Lean functions become callable WebAssembly exports.",
      "Generated modules carry a lean4wasm custom section for artifact identity."
    ]
  },
  {
    kind := .linux,
    name := "Lean4Linux",
    artifact := "Linux lib/nlattr.c replacement",
    summary :=
      "A Lean-backed replacement for Linux nlattr parsing, validation, helpers, and selected builder decisions.",
    points := #[
      "NlAttrSpec.lean models layout, streams, parse tables, payload checks, ranges, and return codes.",
      "NlAttrCore.lean compiles to an allocation-free kernel-linked RISC-V object.",
      "Linux Kbuild compiles the Lean source into kernel-linked objects.",
      "QEMU boot, benchmark, and netlink stress runners exercise the replacement in Linux."
    ]
  }
]

theorem target_count_checked : targets.size = 3 := rfl

def targetChipHtml (t : Target) : String :=
  "<div class=\"target-chip\" style=\"--accent: " ++ TargetKind.accent t.kind ++ "\">" ++
    "<strong>" ++ t.name ++ "</strong>" ++
    "<span>" ++ t.artifact ++ "</span>" ++
  "</div>"

def targetCardHtml (t : Target) : String :=
  "<article class=\"target-card\" style=\"--accent: " ++ TargetKind.accent t.kind ++ "\">" ++
    "<h3>" ++ t.name ++ "</h3>" ++
    "<div class=\"artifact\">" ++ t.artifact ++ "</div>" ++
    "<p>" ++ t.summary ++ "</p>" ++
    "<ul>" ++ listItemsHtml t.points ++ "</ul>" ++
  "</article>"

def targetChipsHtml : String :=
  targets.foldl (fun acc t => acc ++ targetChipHtml t) ""

def targetGridHtml : String :=
  targets.foldl (fun acc t => acc ++ targetCardHtml t) ""

def targetsCopyHtml : String :=
  "The README describes the same core move across targets: prove the property next to the " ++
  "program, reject host-only APIs at compile time, then emit bitcode for an adapter that owns " ++
  "the target ABI."

end Counter
