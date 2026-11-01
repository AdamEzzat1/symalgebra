import Mathlib.Tactic.LinearCombination
import Mathlib.Data.Real.Basic

theorem bad_certificate (x : ℝ) (h : 2 * x = 6) : x = 3 := by
  linear_combination h / 3
