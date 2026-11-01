# R0-04 Algebra Semantics

**Fragment.** Over ℝ, exact rationals (decimals parsed exact). One variable: `+ - * /`, parentheses, literal exponents 1..4, including variable denominators. Numerator degree cap 6, so wrong steps (`x=2 → x²=4`) stay decidable. Authored problems reduce to degree ≤1. Everything else is OUT_OF_FRAGMENT (OOF) with a reason code: radicals, abs, inequalities, chains, `or`, `x^0`, negative exponents.

**Meaning.** D(e) removes zeros of every denominator in the as-typed tree, never the canonical form. S(l=r) = {x∈D : l(x)=r(x)}. Answer tokens: `no solution`, `all real numbers`, `all real numbers except r`.

**Equation step.** S_A=S_B: EQUIVALENT. S_A⊂S_B: GAINS. S_B⊂S_A: LOSES. Incomparable: UNRELATED. Expression step: equal on D_A∩D_B with D equal: EQUIVALENT; wider D_B: GAINS, shown "equal except x=1"; narrower: LOSES; otherwise UNRELATED, with a point in both domains.

**Infinite sets.** Every S is finite or cofinite, closed under difference. So keep the enum and make the payload `Finite(F)|AllExcept(F)`, plus one rational witness. `x=1→0=0` is GAINS AllExcept{1}; `0=0→x=1` is LOSES AllExcept{1}.

**Second field.** Every verdict also carries `vs_start`, the same relation against line 0. `x/(x-1)=1/(x-1) → x=1 → no solution` gives GAINS{1}, LOSES{1}, yet ends correct. Accept a line if either comparison is EQUIVALENT.

**Multiplicity: sets only.** `x=1` and `(x-1)²=0` have no pointwise counterexample, so rejecting breaks the certificate requirement. Lean `↔` and the rperft invariant are also set-based. No flag.

**Other variables.** Multi-variable expressions: polynomial only, EQUIVALENT or UNRELATED with a rational point. Multi-variable equations, including parameters and literal equations: OOF. An unexpected letter is OOF `unknown_symbol`, never wrong and never quantified.

**Empty domain.** A denominator identically zero: OOF `empty_domain`, otherwise `1/0→2/0` passes vacuously.

**Top risks.**
1. Parse: `x/2x`, `1/2x`, `1 1/2` change meaning. Refuse as ambiguous; confirm a rendered preview.
2. Irrational differences (`x²=2→x²=3`): no showable rational root. Without a rational witness, OOF `irrational_root`.
3. Oracle: SymPy gives ℝ for `x/x=1` and {0} for `1/(1/x)=0`, both wrong by tree domain. Tier E must supply domains independently.

**Cut.** Multiplicity flag, algebraic-number roots, Z3/CAD, Schwartz-Zippel (use Sturm, gcd, grid), `or` lines, multi-variable denominators.

**Brief problems.**
- GAINS {roots}: see payload above.
- "Tie resolves to valid" fails for guarded rules: `x/(x-1)=1/(x-1)→x=1` matches a rule, verdict GAINS. Restrict ties to EQUIVALENT.
- `2x=4→x=4-2` is EQUIVALENT by luck; `2x=2x+1→0=7` is truly equivalent. Mal-rules may annotate, never reject.
- "Sound edge preserves solution set" needs two rule classes: equivalence and implication.
- Report's "numerator roots minus denominator roots" fails after cancellation.

**Verified:** 22 named steps plus 4,401 random pairs, gcd/Sturm relation versus explicit real roots, 0 mismatches (SymPy 1.14, no Lisp). SymPy results above run. **Assumed:** degree cap, pedagogy of `vs_start`, exponent limits, expression-step witness search.
