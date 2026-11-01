# R2-04 Semantics

1. D13. `2x=4 -> 0=0` says "this line has no solution", false: every x solves it. `x+x=2x -> x=1` substitutes 1, gets 2=2, no counterexample. Fix: branch on ∅, {r}, ℝ for both lines; witness from S_prev minus S_line, else S_line minus S_prev.

2. D4. `x/(x-1)=1/(x-1) -> x=1`, standard denominator clearing, and `(x²-1)/(x-1) -> x+1` are GAINS, so never commit. The student cannot reach `no solution`. Fix: GAINS commits as "caution", stays unsolved.

3. D3/D4. `no solution` and `all real numbers` are not in the grammar, and "solved" has no form test: `2x=4` satisfies it. Fix: add both tokens; solved requires `x=r` or token.
