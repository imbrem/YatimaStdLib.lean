import YatimaStdLib.Ring
import Batteries.Data.Rat.Basic

namespace Rat

def powAux (base : Rat) (exp : Nat) : Rat :=
  let rec go (power acc : Rat) (n : Nat) : Rat :=
    match h : n with
    | 0 => acc
    | _ + 1 =>
      let n' := n / 2
      have : n' < n := Nat.bitwise_rec_lemma (h ▸ Nat.succ_ne_zero _)
      if n % 2 == 0
      then go (power * power) acc n'
      else go (power * power) (acc * power) n'
  go base 1 exp

instance : Field Rat where
  hPow r n := powAux r n
  coe a := { num := a, reduced := by simp only [Nat.Coprime, Nat.coprime_one_right]}
  zero := 0
  one := 1
  inv x := 1/x

def abs (r : Rat) : Rat := {r with num := r.num.natAbs}

def round (r : Rat) : Int :=
  let floor := r.floor
  if abs (r - floor) ≤ (1 : Rat)/2 then floor else r.ceil

end Rat
