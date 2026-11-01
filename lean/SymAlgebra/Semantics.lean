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

open Classical in
def pdiv : Option ℝ → Option ℝ → Option ℝ
  | some x, some y => if y = 0 then none else some (x / y)
  | _, _ => none

inductive E where
  | var : E
  | lit : ℚ → E
  | add : E → E → E
  | mul : E → E → E
  | div : E → E → E

def ev : E → ℝ → Option ℝ
  | .var, x => some x
  | .lit q, _ => some (q : ℝ)
  | .add a b, x => padd (ev a x) (ev b x)
  | .mul a b, x => pmul (ev a x) (ev b x)
  | .div a b, x => pdiv (ev a x) (ev b x)

def Sol (l r : E) : Set ℝ :=
  {x | ∃ v, ev l x = some v ∧ ev r x = some v}

/-- `1/x` has no value at 0, so `1/x = 0` cannot have root 0. -/
theorem ev_one_div_var_zero : ev (.div (.lit 1) .var) 0 = none := by
  simp [ev, pdiv]

end

end SymAlgebra
