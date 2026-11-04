import Mathlib.Analysis.Real.Sqrt
import Mathlib.Basic.Real.Basic

/-! School-algebra semantics. A zero divisor has no value, unlike Mathlib's `x / 0 = 0`. -/

namespace SymAlgebra

noncomputable section

def padd : Option ℝ → Option ℝ → Option ℝ
  | some x, some y => some (x + y)
  | _, _ => none

def pmul : Option ℝ → Option ℝ → Option ℝ
  | some x, some y => some (x * y)
  | _, _ => none

def psub : Option ℝ → Option ℝ → Option ℝ
  | some x, some y => some (x - y)
  | _, _ => none

def pneg : Option ℝ → Option ℝ
  | some x => some (-x)
  | none => none

def ppow : Option ℝ → ℕ → Option ℝ
  | some x, n => some (x ^ n)
  | none, _ => none

open Classical in
def pdiv : Option ℝ → Option ℝ → Option ℝ
  | some x, some y => if y = 0 then none else some (x / y)
  | _, _ => none

open Classical in
/-- A negative number has no real square root here, unlike Mathlib's `√x = 0`. -/
def psqrt : Option ℝ → Option ℝ
  | some x => if 0 ≤ x then some (Real.sqrt x) else none
  | none => none

inductive E where
  | var : E
  | lit : ℚ → E
  | add : E → E → E
  | mul : E → E → E
  | div : E → E → E
  | sub : E → E → E
  | neg : E → E
  | pow : E → ℕ → E
  | sqrt : E → E

def ev : E → ℝ → Option ℝ
  | .var, x => some x
  | .lit q, _ => some (q : ℝ)
  | .add a b, x => padd (ev a x) (ev b x)
  | .mul a b, x => pmul (ev a x) (ev b x)
  | .div a b, x => pdiv (ev a x) (ev b x)
  | .sub a b, x => psub (ev a x) (ev b x)
  | .neg a, x => pneg (ev a x)
  | .pow a n, x => ppow (ev a x) n
  | .sqrt a, x => psqrt (ev a x)

def Sol (l r : E) : Set ℝ :=
  {x | ∃ v, ev l x = some v ∧ ev r x = some v}

/-- The meaning of the `total` guard: `a` has a value at every x. -/
def Total (a : E) : Prop :=
  ∀ x, ∃ v, ev a x = some v

/-- `1/x` has no value at 0, so `1/x = 0` cannot have root 0. -/
theorem ev_one_div_var_zero : ev (.div (.lit 1) .var) 0 = none := by
  simp [ev, pdiv]

end

end SymAlgebra
