# R1-03 Lean critique. Nothing compiled.

**(a) Strongest.** Role 4's `Finite(F)|AllExcept(F)` payload. It replaces my vague cofinite note and maps to one function: `toSet`, giving `↑F` or `(↑F)ᶜ`.

**(b) Most dangerous.** Role 8's shallow "missing `x≠0`" sabotage fixture. Failure: `x*x/x = x` proves without the hypothesis (0/0 = 0 gives 0 = 0), while `x/x = 1` fails. Choose the second and CI stays green, yet the first class goes uncaught. Also, Lean fixtures need Mathlib, so a separate 6-minute job is doubtful. Run them inside `lean`, strip every guard, and use Option statements.

**(c) Conflicts.**
- M0: accept role 10's split, pending owner ruling. Lean never blocks M1. Keep `lean` outside role 8's `gate` until M0b passes. The one theorem should be `cancel_factor`, not `linear_combination`, because Option case-splitting is my riskiest assumption.
- Option survives, with one condition. Strict `ev` over the as-typed tree gives `Dom e = D(e)` by construction, so `1/(1/x)` keeps 0 excluded. Over canonical form it would not. `Sol` is unchanged; add implication theorems (`Sol A ⊆ Sol B`). `empty_domain` lines emit no certificate.

**(d) Retract.** Certificates carrying canonical A, B: they must carry as-typed trees. My 20-minute limit: use role 8's 30 cold until measured.
