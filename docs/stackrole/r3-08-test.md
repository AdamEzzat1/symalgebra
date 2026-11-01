# R3-08 Test

Two objections; otherwise ACCEPT.

1. **Section 5.** `needs` is static. Once Lean runs on demand, it is skipped, so "every `needs` result is `success`" reds every commit. Change: `gate` accepts `skipped` for `lean` only when `lean_required` is false.

2. **Section 6.** Checker evidence has no CI home, so parser fixes during M1 can bypass it. Change: at M1 add one job on the `python:3.11.3-slim` digest with hash-locked SymPy 1.14.0, in `needs` and the manifest, with the failure test included.
