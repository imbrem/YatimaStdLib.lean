import Batteries.Data.RBMap
import YatimaStdLib.Nat
import LSpec

/--
A `MultilinearPolynomial α` ("MLP" for short) represents a multivariate linear
polynomial on `α`. Each `(b, c)` pair in the `RBMap` represents a summand with
coefficient `c : α` and variables encoded in `b : Nat`.

The encoding in `b` assumes that the variables are indexed from 0 and their
presence (or absence) on the respective summand are indicated by `1` or `0`, in
binary form, from right to left.

For example, `(6, 9)` encodes `9x₁x₂` because
* `9` is the coefficient
* `6₁₀ = 110₂`, so the variables on indexes `1` and `2` are present
-/
abbrev MultilinearPolynomial α := Batteries.RBMap Nat α compare

namespace MultilinearPolynomial

/-- The indices of variables in a summand -/
abbrev Indices := Batteries.RBSet Nat compare

/-- Extracts the variable indices encoded on a base -/
def Indices.ofBase (b : Nat) : Indices :=
  List.range b.log2.succ |>.foldl (init := default) fun acc idx =>
    if b >>> idx % 2 == 0 then acc else acc.insert idx

/-- Encodes variable indices into a base -/
def Indices.toBase (is : Indices) : Nat :=
  is.foldl (init := 0) fun acc i => acc + 1 <<< i

/-- Instantiates a MLP from the list of raw `(b, c)` pairs -/
def ofPairs (pairs : List $ Nat × α) : MultilinearPolynomial α :=
  .ofList pairs _

/-- Instantiates a MLP from a list of summands -/
def ofSummands (summands : List $ α × Indices) : MultilinearPolynomial α :=
  summands.foldl (init := default) fun acc (c, is) =>
    acc.insert is.toBase c

/-- Similar to `ofSummands`, but the consumed indices are lists of `Nat` -/
def ofSummandsL (summands : List $ α × List Nat) : MultilinearPolynomial α :=
  summands.foldl (init := default) fun acc (c, is) =>
    acc.insert (Indices.toBase (.ofList is _)) c

variable (mlp : MultilinearPolynomial α)

/-- Turns a MLP into a list of its summands -/
def toSummands : List $ α × Indices :=
  mlp.foldl (init := []) fun acc b c => (c, Indices.ofBase b) :: acc

/-- Similar to `toSummands`, but the resulting indices are lists of `Nat` -/
def toSummandsL : List $ α × List Nat :=
  mlp.foldl (init := []) fun acc b c => (c, Indices.ofBase b |>.toList) :: acc

protected def toString [ToString α] : String :=
  " + ".intercalate $ mlp.toSummands.map fun (c, is) =>
    is.foldl (init := toString c) fun acc i => s!"{acc}x{i.toSubscriptString}"

instance [ToString α] : ToString $ MultilinearPolynomial α where
  toString x := x.toString

variable [HMul α α α] [HAdd α α α] [OfNat α $ nat_lit 0] [BEq α]

/-- Scales the coefficients of a MLP by a factor `a : α` -/
@[specialize] def scale (a : α) : MultilinearPolynomial α :=
  mlp.foldl (init := default) fun acc b c => acc.insert b $ a * c

/--
The sum of two MLPs defined on the same domain `a`.

Efficiency note: provide the smaller polynomial on the right.
-/
@[specialize] def add (mlp' : MultilinearPolynomial α) : MultilinearPolynomial α :=
  mlp'.foldl (init := mlp) fun acc b' c' => match mlp.find? b' with
    | some c => acc.insert b' (c + c')
    | none => acc.insert b' c'

instance : HAdd (MultilinearPolynomial α) (MultilinearPolynomial α)
  (MultilinearPolynomial α) where hAdd x y := x.add y

/--
Multiplying two MLPs to obtain a MLP is not as straightforward because
multiplication may increase the power of some variable if it's present on
summands of the two initial MLPs, resulting on a polynomial that would no
longer be linear.

Thus we implement a "disjoint" multiplication, which considers that no variable
is present on summands of both input MLPs.

For example, `(x + 1) * (y + x + 2)` wouldn't be a disjoint multiplication, but
`(x + 1) * (y + 2)` would.
-/
@[specialize] def disjointMul (mlp' : MultilinearPolynomial α) : MultilinearPolynomial α :=
  mlp.foldl (init := default) fun pol b c =>
    mlp'.foldl (init := pol) fun pol b' c' =>
      pol.insert (b ||| b') (c * c')

instance : HMul (MultilinearPolynomial α) (MultilinearPolynomial α)
  (MultilinearPolynomial α) where hMul x y := x.disjointMul y

/--
Evaluates a MLP on an array whose values represent the values of the variables
indexed from 0, matching the indexes of the array. Variables on indexes beyond
the range of the array are considered to have value 0.
-/
@[specialize] def eval (input : Array α) : α :=
  let inputSize := input.size
  mlp.foldl (init := 0) fun acc b c => HAdd.hAdd acc $
    Indices.ofBase b |>.foldl (init := c) fun acc i =>
      acc * (if h : i < inputSize then input[i]'h else 0)

/--
Evaluates a MLP on a map that indicates the value of the variables indexed from
0. Variables whose indexes aren't in the map are considered to have value 0.
-/
@[specialize] def eval' (input : Batteries.RBMap Nat α compare) : α :=
  mlp.foldl (init := 0) fun acc b c => HAdd.hAdd acc $
    Indices.ofBase b |>.foldl (init := c) fun acc i =>
      acc * (input.find? i |>.getD 0)

/-- Similar to `eval'`, but takes a list of `(index, value)` instead -/
@[specialize, inline] def eval'L (input : List $ Nat × α) : α :=
  mlp.eval' $ .ofList input _

/-- Strips away pairs with coefficients equal to zero -/
@[specialize] def prune : MultilinearPolynomial α :=
  mlp.foldl (init := default) fun acc b c =>
    if c == 0 then acc else acc.insert b c

instance : BEq $ MultilinearPolynomial α where
  beq x y := x.prune == y.prune

namespace Tests

open LSpec

-- TODO : prove this as a theorem
#lspec check "roundtripping" $ ∀ n, (Indices.ofBase n).toBase = n

/-- 3x₀x₄ + 2x₁ + 4 -/
def pol1 := ofSummandsL [(2, [1]), (3, [4, 0]), (4, [])]

/-- 2x₁x₄ + 4x₀x₄ + 1x₁x₃ + 3 -/
def pol2 := ofSummandsL [(1, [1, 3]), (4, [4, 0]), (2, [4, 1]), (3, [])]

/-- 9x₀x₄ + 6x₁ + 12 -/
def pol1Scaled3 := ofSummandsL [(6, [1]), (9, [4, 0]), (12, [])]

/-- 2x₁x₄ + 7x₀x₄ + 1x₁x₃ + 2x₁ + 7 -/
def pol1AddPol2 :=
  ofSummandsL [(1, [1, 3]), (2, [1]), (7, [4, 0]), (2, [4, 1]), (7, [])]

/-- 4x₂x₃ + 12x₂ + 5 -/
def pol3 := ofSummandsL [(12, [2]), (4, [2, 3]), (5, [])]

/-- 12x₀x₂x₃x₄ + 36x₀x₂x₄ + 15x₀x₄ + 8x₁x₂x₃ + 16x₂x₃ + 24x₁x₂ + 48x₂ + 10x₁ + 20 -/
def pol1MulPol3 := ofSummandsL [
  (12, [0, 2, 3, 4]), (36, [0, 2, 4]), (15, [0, 4]),
  (8, [1, 2, 3]), (24, [1, 2]), (10, [1]),
  (16, [2, 3]), (48, [2]), (20, [])]

#lspec
  test "scaling works" (pol1.scale 3 == pol1Scaled3) $
  test "addition is correct" (pol1.add pol2 == pol1AddPol2) $
  test "disjoint multiplication is correct" (pol1.disjointMul pol3 == pol1MulPol3) $
  test "evaluation is correct" (pol1MulPol3.eval #[0, 1, 2, 0, 4] == 174) $
  test "scaling with zero results on zero" (pol1.scale 0 == default) $
  test "zero is right-neutral on addition" (pol1 + default == pol1) $
  test "zero is left-neutral on addition" (default + pol1 == pol1) $
  test "multiplying by zero takes to zero" (pol1 * default == default) $
  test "zero multiplied by anything goes to zero" (default * pol1 == default)

end Tests

end MultilinearPolynomial
