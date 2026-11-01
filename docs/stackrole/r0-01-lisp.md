# R0-01 Common Lisp Engine Architect

**Data structures**
- `node` struct: op, kids, source span, flags. Ops: num (text plus exact value), var, neg, add, sub, mul (implicit flag), div, pow, paren, eq. Binary as typed; constructors never evaluate.
- `poly`: list of (monomial . coeff), graded-lex sorted; monomial is sorted (var-string . exp). Plain lists, so `equal` is canonical equality. Never `intern` student text.
- `rat`: cancelled num/den. Denominators univariate, else OUT_OF_FRAGMENT. No multivariate gcd.
- `domain`: one squarefree primitive polynomial D, the lcm of every divisor's numerator, collected walking the tree before cancellation. Empty for zero divisors, so `1/0` never signals.
- `solset`: `(:finite roots)` or `(:cofinite excluded)`.
- `flat`: derived AC-sorted, unevaluated view for matching and rperft.

**Verdicts.** Equations: S⊂S' GAINS, S⊃S' LOSES, neither UNRELATED with witnesses. Expressions: different canon is UNRELATED with a rational witness; same canon, different domain is GAINS/LOSES points. Sets over ℝ; multiplicity ignored.

**Fragment.** One-variable equations; multivariate polynomial expressions; literal exponents 1 to 6. Over limits (nodes 200, degree 8, 64-bit literals) or irrational witness: OUT_OF_FRAGMENT.

**Modules** (`engine/src`): `exact` (shadows `/`, `expt`, `sqrt`, `float`), `tree`, `parse` (hand Pratt, never `read`), `poly` (gcd, squarefree, Sturm, rational roots), `canon`, `solset`, `verdict`, `serial` (n/d bytes, FNV-1a).

**Risks**
1. Resource exhaustion. Deterministic fuel checked before each multiply; `with-timeout` only as backstop, since wall-clock limits make verdicts machine-dependent.
2. Domain taken from canon, not tree. Test `x²/x=0`, `1/(1/x)`.
3. `2/3x` parses either way and changes the domain. Return a parse query, never a verdict.

**Cut:** hash-consing, radicals, abs, Tarski/Z3, sb-gmp, e-graphs, inequalities, disjunctions, `x^0`, multiplicity flag.

**Brief problems**
- `GAINS {roots}` assumes finite rational lists. `x=1 → 0=0` gains a cofinite set; `1/x=x/2` meets `±√2`. Hence `solset`, and irrational witnesses go OUT_OF_FRAGMENT.
- Two representations are too few: `3x+x=4` and `4x=4` share per-side canon, making combine-like-terms a self-loop. Keep `flat`, derived, for rperft states.
- Verdicts are defined only for equations. `x/x → 1` is GAINS {0}; someone must decide whether that is shown.
- M3 puts rule search in Lisp; ownership puts attribution in Prolog. Two matchers will drift (Rubi). Lisp enumerates applications; Prolog only labels them.

**Verified** (SBCL 2.6.9, this machine): `3^20000000` took 70 s, so caps are mandatory; `with-timeout` interrupted a bignum `expt` once; dynamic space 1 GB; `equal` on rationals and bignums; exact negative `expt`; Sturm counts for four samples; degree-8, 64-bit squarefree+Sturm+gcd averaged 9 ms, max 34 ms, peak 6,202 coefficient bits.

**Assumed:** hosted-server timing, about 1,500 lines, whether limits fit real student input, `x²=2` being rare in scope.
