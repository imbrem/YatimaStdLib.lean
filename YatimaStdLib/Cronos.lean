import YatimaStdLib.RBMap

structure Cronos where
  refs : Batteries.RBMap String Nat compare
  data : Batteries.RBMap String Nat compare
  deriving Inhabited

namespace Cronos

def new : Cronos :=
  default

variable (c : Cronos)

def clock (tag : String) : IO Cronos := do
  let now ← IO.monoNanosNow
  match c.refs.find? tag with
  | none => return { c with refs := c.refs.insert tag now }
  | some ref => return {
    refs := c.refs.insert tag now,
    data := c.data.insert tag (now - ref) }

def summary : String :=
  let timings := c.data.foldl (init := "")
    fun acc tag time => s!"{acc}\n  {tag} | {(Float.ofNat time) / 1000000000}s"
  s!"Timings:{timings}"

end Cronos
