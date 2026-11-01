import SymAlgebra.Semantics

/-! Cancelling a common factor, and why its guard cannot be dropped. -/

namespace SymAlgebra

/-- `c` has a value and that value is not zero. -/
def NZ (c : Option ℝ) : Prop := ∃ v, c = some v ∧ v ≠ 0

theorem cancel_factor (a b c : Option ℝ) (hc : NZ c) :
    pdiv (pmul a c) (pmul b c) = pdiv a b := by
  obtain ⟨v, rfl, hv⟩ := hc
  cases a with
  | none => cases b <;> simp [pmul, pdiv]
  | some x =>
    cases b with
    | none => simp [pmul, pdiv]
    | some y =>
      by_cases hy : y = 0
      · simp [pmul, pdiv, hy]
      · have hyv : y * v ≠ 0 := mul_ne_zero hy hv
        simp only [pmul, pdiv, if_neg hyv, if_neg hy, mul_div_mul_right _ _ hv]

/-- A factor of zero: cancelling `x` from `x·1 / x·1` at `x = 0` invents a value. -/
theorem cancel_needs_nonzero :
    ¬ ∀ a b c : Option ℝ, pdiv (pmul a c) (pmul b c) = pdiv a b := by
  intro h
  have := h (some 1) (some 1) (some 0)
  simp [pmul, pdiv] at this

/-- A factor with no value: the same rule fails when `c` is undefined. -/
theorem cancel_needs_defined :
    ¬ ∀ a b c : Option ℝ, pdiv (pmul a c) (pmul b c) = pdiv a b := by
  intro h
  have := h (some 1) (some 1) none
  simp [pmul, pdiv] at this

end SymAlgebra
