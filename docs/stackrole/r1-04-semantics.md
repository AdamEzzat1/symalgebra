# R1-04 Semantics critique

**(a) Strongest.** Role 3's Option-valued `ev`. It makes my tree-domain definition machine-checkable and blocks Lean's `1/x=0` having root 0.

**(b) Most dangerous.** Role 1's "empty domain" for zero divisors, unless it stops the verdict. `3/0=5/0 → 7/0=1/0` has S=∅ on both lines, so EQUIVALENT: "Correct" on division by zero. Role 3's `Sol` proves it too. Keep OOF `empty_domain`.

**(c) Conflict.** One limits table, held in Lisp. Role 9's input caps stand (8-digit literals, 64 tokens, depth 16). Exponents 1..6, degree 8 for the line's combined numerator, using Role 1's timing. Role 9's exponent 0 goes: `x^0=1` turns on a 0^0 convention. All values remain judgement.

M1's ax+b reducer is compatible if checks run per node, before reduction: any `/` whose divisor is not a nonzero constant is OOF, and so is any product of two non-constant factors, even `x*x-x*x`. Domain is then ℝ, so my rule holds vacuously. A coefficient-only reducer would give `(2x+2)/(x+1)=2` ℝ, wrongly including -1. Golden-test that.

**(d) Retract.** Exponents 1..4 and degree 6. "Mal-rules may annotate": Role 2 is right that they never touch EQUIVALENT, so `x=4-2` passes silently, as a documented limit.
