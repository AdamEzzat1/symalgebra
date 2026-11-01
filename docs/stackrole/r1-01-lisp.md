# R1-01 Common Lisp Engine Architect

**(a) Strongest: R3's Option semantics.** `ev` returns none on a zero divisor, so `Dom` and `Sol` give Lisp's tree-derived domain a formal definition, and `{x | 1/x=0}` cannot wrongly be {0}.

**(b) Most dangerous: R4's "accept a line if either comparison is EQUIVALENT".** `x/(x-1)=1/(x-1) → x=1 → 1=x`: line 3 is EQUIVALENT to line 2, so it is accepted, yet the start has no solution (`vs_start` GAINS {1}). The student finishes wrong and is told fine. Fix: either comparison may accept a step, but "solved" requires `vs_start` EQUIVALENT, decided by Lisp.

**(c) Conflict with R2.** I said Lisp enumerates and Prolog labels; R2 has Prolog generate candidates and Lisp confirm them. Settle for R2 on the live path: the brief gives Prolog attribution, and Lisp still folds, compares and evaluates guards. Lisp's enumerator serves rperft only, with R2's byte comparison of depth-1 sound edges on the corpus.

**(d) Retractions.**
- `1/0` as an empty solution set: `1/0→2/0` passes vacuously. Adopt R4's OOF `empty_domain`.
- Degree 8, exponents 6, 64-bit literals: adopt R4's exponents 1..4 and degree 6, R9's 8 digits, except its exponent 0.
