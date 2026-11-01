import SymAlgebra.Rules

/-! M4 five-rule trial. Statements come from `Rules.lean`, generated from the rule file. -/

namespace SymAlgebra

theorem pdiv_eq_some {p q : Option ℝ} {v : ℝ} (h : pdiv p q = some v) :
    ∃ u w, p = some u ∧ q = some w ∧ w ≠ 0 ∧ u / w = v := by
  cases p with
  | none => cases q <;> simp [pdiv] at h
  | some u =>
    cases q with
    | none => simp [pdiv] at h
    | some w =>
      by_cases hw : w = 0
      · simp [pdiv, hw] at h
      · simp only [pdiv, if_neg hw, Option.some.injEq] at h
        exact ⟨u, w, rfl, rfl, hw, h⟩

theorem proof_distribute : rule_distribute := by
  unfold rule_distribute
  intro a b c x
  simp only [ev]
  generalize ev a x = p
  generalize ev b x = q
  generalize ev c x = r
  cases p <;> cases q <;> cases r <;> simp [pmul, padd, mul_add]

theorem proof_mul_zero : rule_mul_zero := by
  unfold rule_mul_zero
  intro a x h
  obtain ⟨v, hv⟩ := h x
  simp [ev, hv, pmul]

/-- At `x = 0`, `(1/x) * 0` has no value but `0` does. -/
theorem proof_mul_zero_needs_total : rule_mul_zero_needs_total := by
  unfold rule_mul_zero_needs_total
  intro h
  have := h (.div (.lit 1) .var) 0
  simp [ev, pmul, pdiv] at this

theorem proof_div_by_fraction : rule_div_by_fraction := by
  unfold rule_div_by_fraction
  intro a b c x hc
  have hc' : (c : ℝ) ≠ 0 := by exact_mod_cast hc
  simp only [ev]
  generalize ev a x = p
  generalize ev b x = q
  cases p with
  | none => cases q <;> simp [pmul, pdiv, hc, hc']
  | some u =>
    cases q with
    | none => simp [pmul, pdiv]
    | some w =>
      by_cases hw : w = 0
      · subst hw
        simp [pmul, pdiv, hc, hc']
      · have hq : w / (c : ℝ) ≠ 0 := div_ne_zero hw hc'
        simp only [pmul, pdiv, if_neg hc', if_neg hw, if_neg hq]
        rw [div_div_eq_mul_div]

/-- With `c = 0`, `1/(1/0)` has no value but `(1 * 0)/1` does. -/
theorem proof_div_by_fraction_needs_nonzero_literal :
    rule_div_by_fraction_needs_nonzero_literal := by
  unfold rule_div_by_fraction_needs_nonzero_literal
  intro h
  have := h (.lit 1) (.lit 1) 0 0
  simp [ev, pmul, pdiv] at this

theorem proof_add_both : rule_add_both := by
  unfold rule_add_both
  intro l r t ht
  ext x
  obtain ⟨w, hw⟩ := ht x
  simp only [Sol, Set.mem_setOf_eq, ev, hw]
  generalize ev l x = p
  generalize ev r x = q
  cases p <;> cases q <;> simp [padd]

/-- `x = 0` has root 0, but `x + 1/x = 0 + 1/x` has no value there. -/
theorem proof_add_both_needs_total : rule_add_both_needs_total := by
  unfold rule_add_both_needs_total
  intro h
  have hm : (0 : ℝ) ∈ Sol .var (.lit 0) := by
    simp only [Sol, Set.mem_setOf_eq]
    exact ⟨0, by simp [ev], by simp [ev]⟩
  rw [h .var (.lit 0) (.div (.lit 1) .var)] at hm
  simp only [Sol, Set.mem_setOf_eq] at hm
  obtain ⟨v, h1, _⟩ := hm
  simp [ev, padd, pdiv] at h1

theorem proof_cross_multiply : rule_cross_multiply := by
  unfold rule_cross_multiply
  intro a b c d x hx
  simp only [Sol, Set.mem_setOf_eq, ev] at hx ⊢
  obtain ⟨v, h1, h2⟩ := hx
  obtain ⟨u, w, ha, hb, hw, huw⟩ := pdiv_eq_some h1
  obtain ⟨u', w', hc, hd, hw', huw'⟩ := pdiv_eq_some h2
  have e1 := (div_eq_iff hw).1 huw
  have e2 := (div_eq_iff hw').1 huw'
  refine ⟨u * w', ?_, ?_⟩
  · simp only [ha, hd, pmul]
  · simp only [hb, hc, pmul]
    rw [e1, e2]
    congr 1
    exact mul_right_comm v w' w

end SymAlgebra
