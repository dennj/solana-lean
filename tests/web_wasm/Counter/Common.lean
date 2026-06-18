import Std.Web

namespace Counter

def concatHtml (xs : Array String) : String :=
  xs.foldl (fun acc x => acc ++ x) ""

def concatMapHtml {α : Type} (xs : Array α) (f : α -> String) : String :=
  xs.foldl (fun acc x => acc ++ f x) ""

def joinWith (sep : String) (xs : Array String) : String :=
  go xs.size 0 ""
where
  go : Nat -> Nat -> String -> String
    | 0, _, acc => acc
    | n + 1, idx, acc =>
      let item := xs.getD idx ""
      let next := if idx == 0 then item else acc ++ sep ++ item
      go n (idx + 1) next

def listItemsHtml (xs : Array String) : String :=
  concatMapHtml xs (fun x => "<li>" ++ x ++ "</li>")

def digitString : Nat -> String
  | 0 => "0"
  | 1 => "1"
  | 2 => "2"
  | 3 => "3"
  | 4 => "4"
  | 5 => "5"
  | 6 => "6"
  | 7 => "7"
  | 8 => "8"
  | _ => "9"

def natString (n : Nat) : String :=
  if n < 10 then digitString n else natString (n / 10) ++ digitString (n % 10)
termination_by n

def uintString (n : UInt32) : String :=
  natString n.toNat

def smallNatString (n : Nat) : String :=
  natString n

def eventCountString (n : UInt32) : String :=
  uintString n

def natRangeFrom (first count : Nat) : Array Nat :=
  go count first #[]
where
  go : Nat -> Nat -> Array Nat -> Array Nat
    | 0, _, acc => acc
    | n + 1, next, acc => go n (next + 1) (acc.push next)

def natRange (count : Nat) : Array Nat :=
  natRangeFrom 0 count

def natMulSmall (x y : Nat) : Nat :=
  go y 0
where
  go : Nat -> Nat -> Nat
    | 0, acc => acc
    | n + 1, acc => go n (acc + x)

def counterText (n : UInt32) : String :=
  if n == 0 then
    "Lean4Wasm reactor ready: landing page rendered by Lean"
  else
    "Lean4Wasm reactor handled browser event #" ++ eventCountString n

def componentHeaderHtml (name detail : String) : String :=
  "<div class=\"component-title\">" ++
    "<h3>" ++ name ++ "</h3>" ++
    "<p>" ++ detail ++ "</p>" ++
  "</div>"

end Counter
