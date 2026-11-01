import Mathlib.Tactic.LinearCombination
import Mathlib.Data.Real.Basic

/-! M0 smoke theorem. Proves only that the pinned toolchain and tactics work. -/

namespace SymAlgebra

theorem two_x_eq_six (x : ℝ) (h : 2 * x = 6) : x = 3 := by
  linear_combination h / 2

end SymAlgebra
