# R0-03 Lean. Nothing compiled; Lean absent.

**Pins.** Lean v4.35.0 (latest stable, GitHub releases; 4.36 is rc2). Mathlib tag v4.35.0, commit 56a00585; its lean-toolchain matches (GitHub API). `leanprover/lean-action` by SHA, not v1. `ubuntu-latest` only. Windows looks workable locally (release assets, Mathlib cache-tool job) but untested. Set `*.lean eol=lf`.

**M0.** toolchain, lakefile, manifest; `Semantics.lean`; one hand theorem; axiom gate allowing exactly propext, Classical.choice, Quot.sound; `df -h` and timing logged. Selective `lake exe cache get` of Ring, FieldSimp, LinearCombination, NormNum, Real closures, with `use-mathlib-cache: false`. `lake build --no-build` on those modules fails fast on a hash miss. 20-minute limit. Estimate, unmeasured: 6-10 min cold, 3 cached. Public repo free; private $12 is 2,000 Linux minutes.

**Semantics: use Option, not shallow division.** Shallow `{x | 1/x = 0}` is {0}, a false school claim.
- `ev : E → ℝ → Option ℝ`; `pdiv` returns none on zero divisor.
- `Dom e = {x | (ev e x).isSome}`
- `Sol l r = {x | ∃ v, ev l x = some v ∧ ev r x = some v}`
- EQUIVALENT: `Sol A = Sol B`. GAINS S: `Sol B = Sol A ∪ S`, disjoint. LOSES S: `Sol A = Sol B ∪ S`, disjoint. Sets ignore multiplicity.

**Generated theorem.**
```lean
theorem cancel_factor (a b c : Option ℝ) (hc : NZ c) :
    pdiv (pmul a c) (pmul b c) = pdiv a b := cancel_factor_proof
```
Statements are generated; proofs are hand-written per id.

**Missing hypothesis test.** Strip each guard, regenerate; Lean must fail on that theorem, not by parse error. Here `c = none` makes the statement false. Also generate `¬∀…` guard-necessity witnesses from negative examples. Lint: `/` and `⁻¹` appear only in `Semantics.lean`.

**Certificate.** One JSON line per step: canonical A, B, verdict, witness. No rule id: it certifies the verdict. Linear witness: nonzero k with `A.l−A.r = k(B.l−B.r)`. Becomes `lin_step k (by norm_num) (by intro x; simp [ev]; ring)`. CI mutates k, target and root; each must fail.

**Risks.**
1. Silent full Mathlib rebuild, or disk: full cache about 7 GB (April 2026 PR), "~14 GB free" there and in GitHub docs; community says 25-29.
2. Option case-splitting makes proofs slow or hand-heavy.
3. Statement fidelity: the printer stays unproved.

**Cut.** Stretch (4) until B and C pass; comparator, lean-egg, sqrt lemmas, GitHub caching of `.lake`.

**Brief problems.**
- `GAINS {roots}` cannot list `x=1 → 0=0`, which gains ℝ\{1}. Needs a cofinite form.
- "Pin in deployment": Lean is not deployed.
- Schema theorems do not cover AC matching or instantiation; corpus certificates must.

**Verified:** tags, commit, 8,624 modules, runner specs, Actions pricing, 10 GB cache, `--no-build`, selective get. **Assumed:** all timings, current cache size, closure size, every Lean snippet.
