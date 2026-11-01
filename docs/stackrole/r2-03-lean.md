# R2-03 Lean. Nothing compiled.

1. D10 fixtures. Stripping `hc` from a hand proof fails with unknown identifier `hc`: right red, wrong reason. `sorry` only warns, so `lake build` passes. Fix: prove `¬∀…` guard-necessity by witness; run sorry and axiom fixtures through `#print axioms`.

2. D9. `cancel_factor` mentions `pdiv`, never `ev`. If `ev` uses raw `/`, M0 stays green and `Sol` of `1/x=0` is {0}. Fix: define `ev` via `pdiv`; add `ev (1/x) 0 = none`.

3. D11. Time box exceeded means M0 never exits, so Lean stays in `gate` and red blocks M1. Fix: committed `lean_required` flag read by `gate` and manifest, flipped by the owner's ruling.
