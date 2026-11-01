import Mathlib.Tactic.LinearCombination
import Mathlib.Basic.Real.Basic

theorem bad_certificate (x : ℝ) (h : 2 * x = 6) : x = 3 := by
  linear_combination h / 3
