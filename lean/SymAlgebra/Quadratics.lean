import Mathlib.Algebra.QuadraticDiscriminant
import Mathlib.Tactic.FieldSimp
import Mathlib.Tactic.LinearCombination
import Mathlib.Tactic.Ring
import SymAlgebra.Trial

/-! Quadratics, square roots and factoring. Statements come from `Rules.lean`. -/

namespace SymAlgebra

open Real

/-- Closes an equation between two values once every subterm is known to be `some` or `none`. -/
macro "settle" : tactic =>
  `(tactic| first
    | rfl
    | (simp only [padd, psub, pmul, pneg, ppow, Option.some.injEq]; done)
    | (simp only [padd, psub, pmul, pneg, ppow, Option.some.injEq]; push_cast; ring))

theorem mem_Sol_some {l r : E} {x u w : ℝ} (h1 : ev l x = some u) (h2 : ev r x = some w) :
    x ∈ Sol l r ↔ u = w := by
  constructor
  · intro h
    obtain ⟨v, a, b⟩ := (h : ∃ v, ev l x = some v ∧ ev r x = some v)
    rw [h1] at a
    rw [h2] at b
    exact (Option.some.inj a).trans (Option.some.inj b).symm
  · intro h
    show ∃ v, ev l x = some v ∧ ev r x = some v
    exact ⟨u, h1, by rw [h2, h]⟩

theorem not_mem_Sol {l r : E} {x : ℝ} (h : ev l x = none) : x ∉ Sol l r := by
  intro hm
  obtain ⟨v, a, _⟩ := (hm : ∃ v, ev l x = some v ∧ ev r x = some v)
  rw [h] at a
  cases a

theorem ev_sqrt_lit {q : ℚ} (x : ℝ) (h : 0 ≤ q) : ev (.sqrt (.lit q)) x = some (√(q : ℝ)) := by
  have h' : (0 : ℝ) ≤ q := by exact_mod_cast h
  simp only [ev, psqrt, if_pos h']

theorem square_iff {y s : ℝ} : y ^ 2 = s * s ↔ y = s ∨ y = -s := by
  constructor
  · intro h
    have hz : (y - s) * (y + s) = 0 := by linear_combination h
    rcases mul_eq_zero.1 hz with h | h
    · exact Or.inl (sub_eq_zero.1 h)
    · exact Or.inr (eq_neg_of_add_eq_zero_left h)
  · rintro (rfl | rfl) <;> ring

theorem quad_iff {a b c y : ℝ} (ha : a ≠ 0) (hD : 0 ≤ b * b - 4 * a * c) :
    a * y ^ 2 + b * y + c = 0 ↔
      y = (-b + √(b * b - 4 * a * c)) / (2 * a) ∨ y = (-b - √(b * b - 4 * a * c)) / (2 * a) := by
  have h : discrim a b c = √(b * b - 4 * a * c) * √(b * b - 4 * a * c) := by
    rw [Real.mul_self_sqrt hD, discrim]
    ring
  rw [← quadratic_eq_zero_iff ha h y]
  constructor <;> intro h' <;> linear_combination h'

/-! Expressions. -/

theorem proof_expand_product : rule_expand_product := by
  unfold rule_expand_product
  intro a b c d x
  simp only [ev]
  generalize ev a x = p
  generalize ev b x = q
  generalize ev c x = r
  generalize ev d x = s
  cases p <;> cases q <;> cases r <;> cases s <;> settle

theorem proof_square_as_product : rule_square_as_product := by
  unfold rule_square_as_product
  intro a x
  simp only [ev]
  generalize ev a x = p
  cases p <;> settle

theorem proof_product_as_square : rule_product_as_square := by
  unfold rule_product_as_square
  intro a x
  simp only [ev]
  generalize ev a x = p
  cases p <;> settle

theorem proof_square_sum : rule_square_sum := by
  unfold rule_square_sum
  intro a b x
  simp only [ev]
  generalize ev a x = p
  generalize ev b x = q
  cases p <;> cases q <;> settle

theorem proof_square_literal : rule_square_literal := by
  unfold rule_square_literal
  intro m x
  simp only [ev]
  settle

theorem proof_factor_common : rule_factor_common := by
  unfold rule_factor_common
  intro a b c x
  simp only [ev]
  generalize ev a x = p
  generalize ev b x = q
  generalize ev c x = r
  cases p <;> cases q <;> cases r <;> settle

theorem proof_factor_trinomial : rule_factor_trinomial := by
  unfold rule_factor_trinomial
  intro a m n p s x h1 h2
  subst h1 h2
  simp only [ev]
  generalize ev a x = w
  cases w <;> settle

theorem proof_factor_squares : rule_factor_squares := by
  unfold rule_factor_squares
  intro a m p x h
  subst h
  simp only [ev]
  generalize ev a x = w
  cases w <;> settle

theorem proof_factor_perfect_square : rule_factor_perfect_square := by
  unfold rule_factor_perfect_square
  intro a p s x h
  subst h
  simp only [ev]
  generalize ev a x = w
  cases w <;> settle

theorem proof_divide_terms : rule_divide_terms := by
  unfold rule_divide_terms
  intro r k m n x hn
  have hn' : (n : ℝ) ≠ 0 := by exact_mod_cast hn
  simp only [ev]
  generalize ev r x = w
  cases w with
  | none => simp [padd, pmul, pdiv]
  | some y =>
    simp only [padd, pmul, pdiv, if_neg hn', Option.some.injEq]
    push_cast
    ring

theorem proof_factor_leading : rule_factor_leading := by
  unfold rule_factor_leading
  intro v a b c p q x hp hq h
  have hp' : p ≠ 0 := ne_of_gt hp
  have ha : a = p * (a / p) := by field_simp
  have hc : c = q * (c / q) := by field_simp
  generalize a / p = r at h ha ⊢
  generalize c / q = s at h hc ⊢
  subst ha hc h
  simp only [ev]
  generalize ev v x = w
  cases w <;> settle

theorem proof_factor_number : rule_factor_number := by
  unfold rule_factor_number
  intro a c m n x hn
  have hn' : n ≠ 0 := ne_of_gt (lt_trans zero_lt_one hn)
  have hc : c = n * (c / n) := by field_simp
  have hm : m = n * (m / n) := by field_simp
  generalize c / n = r at hc ⊢
  generalize m / n = s at hm ⊢
  subst hc hm
  simp only [ev]
  generalize ev a x = w
  cases w <;> settle

theorem proof_factor_number_three : rule_factor_number_three := by
  unfold rule_factor_number_three
  intro a b c d m n x hn
  have hn' : n ≠ 0 := ne_of_gt (lt_trans zero_lt_one hn)
  have hc : c = n * (c / n) := by field_simp
  have hd : d = n * (d / n) := by field_simp
  have hm : m = n * (m / n) := by field_simp
  generalize c / n = r at hc ⊢
  generalize d / n = s at hd ⊢
  generalize m / n = t at hm ⊢
  subst hc hd hm
  simp only [ev]
  generalize ev a x = u
  generalize ev b x = w
  cases u <;> cases w <;> settle

theorem proof_simplify_root : rule_simplify_root := by
  unfold rule_simplify_root
  intro k m p x hm hk h
  subst h
  have hk0 : (0 : ℚ) ≤ k := le_of_lt (lt_trans zero_lt_one hk)
  have hp0 : (0 : ℚ) ≤ m * m * k := mul_nonneg (mul_self_nonneg m) hk0
  have hm' : (0 : ℝ) ≤ m := by exact_mod_cast hm.le
  have h1 := ev_sqrt_lit x hp0
  have h2 := ev_sqrt_lit x hk0
  simp only [ev] at h1 h2 ⊢
  rw [h1, h2]
  simp only [pmul, Option.some.injEq]
  push_cast
  rw [Real.sqrt_mul (mul_self_nonneg (m : ℝ)), Real.sqrt_mul_self hm']

theorem proof_root_of_square : rule_root_of_square := by
  unfold rule_root_of_square
  intro m p x hm h
  subst h
  have hm' : (0 : ℝ) ≤ m := by exact_mod_cast hm.le
  have h1 := ev_sqrt_lit x (mul_self_nonneg m)
  simp only [ev] at h1 ⊢
  rw [h1]
  push_cast
  rw [Real.sqrt_mul_self hm']

/-! Equations. -/

theorem proof_zero_product : rule_zero_product := by
  unfold rule_zero_product
  intro a b ha hb
  ext x
  obtain ⟨u, hu⟩ := ha x
  obtain ⟨w, hw⟩ := hb x
  have h0 : ev (.lit 0) x = some 0 := by simp [ev]
  rw [Set.mem_union, mem_Sol_some (u := u * w) (by simp only [ev, hu, hw, pmul]) h0,
    mem_Sol_some hu h0, mem_Sol_some hw h0]
  exact mul_eq_zero

theorem proof_square_root : rule_square_root := by
  unfold rule_square_root
  intro a m p h
  subst h
  ext x
  rw [Set.mem_union]
  cases hy : ev a x with
  | none =>
    have h1 : x ∉ Sol (.pow a 2) (.lit (m * m)) := not_mem_Sol (by simp only [ev, hy, ppow])
    exact iff_of_false h1 (by
      rintro (h | h)
      · exact not_mem_Sol hy h
      · exact not_mem_Sol hy h)
  | some y =>
    rw [mem_Sol_some (u := y ^ 2) (w := ((m * m : ℚ) : ℝ)) (by simp only [ev, hy, ppow])
        (by simp only [ev]),
      mem_Sol_some hy (w := (m : ℝ)) (by simp only [ev]),
      mem_Sol_some hy (w := -(m : ℝ)) (by simp only [ev, pneg])]
    push_cast
    exact square_iff

theorem proof_take_root : rule_take_root := by
  unfold rule_take_root
  intro a p hp
  have hp' : (0 : ℝ) ≤ p := by exact_mod_cast hp.le
  ext x
  rw [Set.mem_union]
  cases hy : ev a x with
  | none =>
    have h1 : x ∉ Sol (.pow a 2) (.lit p) := not_mem_Sol (by simp only [ev, hy, ppow])
    exact iff_of_false h1 (by
      rintro (h | h)
      · exact not_mem_Sol hy h
      · exact not_mem_Sol hy h)
  | some y =>
    have hs := ev_sqrt_lit x hp.le
    rw [mem_Sol_some (u := y ^ 2) (w := (p : ℝ)) (by simp only [ev, hy, ppow]) (by simp only [ev]),
      mem_Sol_some hy hs,
      mem_Sol_some hy (w := -√(p : ℝ)) (by simp only [ev] at hs ⊢; rw [hs]; simp only [pneg])]
    have h := square_iff (y := y) (s := √(p : ℝ))
    rw [Real.mul_self_sqrt hp'] at h
    exact h

theorem proof_complete_square : rule_complete_square := by
  unfold rule_complete_square
  intro a c s
  exact proof_add_both _ _ _ (fun x => ⟨_, by simp only [ev]⟩)

theorem proof_quadratic_formula : rule_quadratic_formula := by
  unfold rule_quadratic_formula
  intro v a b c ha hD
  have ha' : (a : ℝ) ≠ 0 := by exact_mod_cast ha
  have hq : ((b * b - 4 * a * c : ℚ) : ℝ) = (b : ℝ) * b - 4 * a * c := by push_cast; ring
  have hD' : (0 : ℝ) ≤ (b : ℝ) * b - 4 * a * c := by rw [← hq]; exact_mod_cast hD
  have h2a : ((2 * a : ℚ) : ℝ) ≠ 0 := by
    push_cast
    exact mul_ne_zero two_ne_zero ha'
  ext x
  rw [Set.mem_union]
  cases hy : ev v x with
  | none =>
    have h1 : x ∉ Sol (.add (.add (.mul (.lit a) (.pow v 2)) (.mul (.lit b) v)) (.lit c)) (.lit 0) :=
      not_mem_Sol (by simp only [ev, hy, ppow, pmul, padd])
    exact iff_of_false h1 (by
      rintro (h | h)
      · exact not_mem_Sol hy h
      · exact not_mem_Sol hy h)
  | some y =>
    have hs := ev_sqrt_lit x hD
    simp only [ev] at hs
    rw [mem_Sol_some (u := (a : ℝ) * y ^ 2 + b * y + c) (w := 0)
        (by simp only [ev, hy, ppow, pmul, padd]) (by simp [ev]),
      mem_Sol_some hy (w := (-(b : ℝ) + √((b : ℝ) * b - 4 * a * c)) / (2 * a))
        (by
          simp only [ev]
          rw [hs]
          simp only [padd, pdiv, if_neg h2a, hq]
          push_cast
          rfl),
      mem_Sol_some hy (w := (-(b : ℝ) - √((b : ℝ) * b - 4 * a * c)) / (2 * a))
        (by
          simp only [ev]
          rw [hs]
          simp only [psub, pdiv, if_neg h2a, hq]
          push_cast
          rfl)]
    exact quad_iff ha' hD'

theorem proof_quadratic_substitute : rule_quadratic_substitute := by
  unfold rule_quadratic_substitute
  intro v a b c ha hD
  have ha' : (a : ℝ) ≠ 0 := by exact_mod_cast ha
  have hq : ((b * b - 4 * a * c : ℚ) : ℝ) = (b : ℝ) * b - 4 * a * c := by push_cast; ring
  have hD' : (0 : ℝ) ≤ (b : ℝ) * b - 4 * a * c := by rw [← hq]; exact_mod_cast hD
  have h2a : (((2 : ℚ) : ℝ) * a) ≠ 0 := by
    push_cast
    exact mul_ne_zero two_ne_zero ha'
  have hin : (b : ℝ) ^ 2 - ((4 : ℚ) : ℝ) * a * c = (b : ℝ) * b - 4 * a * c := by push_cast; ring
  ext x
  rw [Set.mem_union]
  cases hy : ev v x with
  | none =>
    have h1 : x ∉ Sol (.add (.add (.mul (.lit a) (.pow v 2)) (.mul (.lit b) v)) (.lit c)) (.lit 0) :=
      not_mem_Sol (by simp only [ev, hy, ppow, pmul, padd])
    exact iff_of_false h1 (by
      rintro (h | h)
      · exact not_mem_Sol hy h
      · exact not_mem_Sol hy h)
  | some y =>
    rw [mem_Sol_some (u := (a : ℝ) * y ^ 2 + b * y + c) (w := 0)
        (by simp only [ev, hy, ppow, pmul, padd]) (by simp [ev]),
      mem_Sol_some hy (w := (-(b : ℝ) + √((b : ℝ) * b - 4 * a * c)) / (2 * a))
        (by
          simp only [ev, padd, psub, pneg, ppow, pmul, psqrt, pdiv, hin, if_pos hD', if_neg h2a]
          push_cast
          rfl),
      mem_Sol_some hy (w := (-(b : ℝ) - √((b : ℝ) * b - 4 * a * c)) / (2 * a))
        (by
          simp only [ev, psub, pneg, ppow, pmul, psqrt, pdiv, hin, if_pos hD', if_neg h2a]
          push_cast
          rfl)]
    exact quad_iff ha' hD'

end SymAlgebra
