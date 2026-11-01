# R2-08 Test

1. **D10.** `build-test` fails, so `gate` is skipped; a skipped job reports Success and the required check passes. Fix: `if: always()`, requiring every `needs` result to be `success`.

2. **D11.** Lean leaves `needs`, but its counts stay in the manifest, so `gate` reds every M1 fix; or a Lean failure goes unseen. Fix: remove Lean from manifest too; run it manually; M4 re-entry needs a cold green.

3. **D13.** A reducer that wrongly returns OOF "agrees" with SymPy on every line, and `2x=6 -> 6=6` has no defined reply: it has every root. Fix: zero OOF on authored lines; perturbed steps have committed expected classes, including `6=6`.
