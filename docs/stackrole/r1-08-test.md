# R1-08 Test critique

**(a) Strongest:** role 3's guard-strip test: remove each guard, regenerate, Lean must fail on that theorem, not by parse error. It is sabotage done properly.

**(b) Most dangerous:** role 6's 150 ms wall budget with SIGKILL, measured only on Windows. At 0.1 CPU, a 44 ms respawn may exceed the budget. Every request kills the child, users see "explanation unavailable", and the graceful fallback hides it. Gate on a `docker run --cpus=0.1` test before hosting.

**(c) Conflict:** role 10 is right for M0. Settle at four jobs: `build-test` (digest-pinned Dockerfile, pins, Lisp, swipl smoke), `lean` (20 minutes), `sabotage`, `gate`. Before Lean's stop rule fires, `gate` requires it; if fired, the owner rules. No GHCR until a host exists: CI rebuilds give same pins, not same bytes, so say so.

M1 checker: yes, one oracle, added at M1. Role 5 voids sessions on false rejection. A SymPy script checks the 25 equations' lines plus perturbed steps; Fractions re-substitutes every counterexample. This is not Tier D or E evidence.

**(d) Retract:** seven M0 jobs, GHCR at M0, M0 `oracle`, the M0 mutation canary (defer to M3), 30-minute Lean limit.
