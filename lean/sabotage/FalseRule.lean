import SymAlgebra.Semantics

open SymAlgebra

/-- The classic wrong distribution, attacked with the tactics that prove the real rule. -/
theorem bad_distribute (a b c : E) (x : ℝ) :
    ev (.mul a (.add b c)) x = ev (.add (.mul a b) c) x := by
  simp only [ev]
  generalize ev a x = p
  generalize ev b x = q
  generalize ev c x = r
  cases p <;> cases q <;> cases r <;> simp [pmul, padd, mul_add]
