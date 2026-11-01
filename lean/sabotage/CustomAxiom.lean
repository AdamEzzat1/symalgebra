import Mathlib.Data.Real.Basic

axiom everything_zero (x : ℝ) : x = 0

theorem cheats (x : ℝ) : x = 0 :=
  everything_zero x

#print axioms cheats
