# Role 8: Test and Reliability (M0 CI)

**Position:** one image digest defines "same version". Public repo. Jobs on `ubuntu-24.04`; actions pinned by SHA.

**"Same version":** native Windows SBCL/swipl share upstream release only, not binaries. Identity exists only by container digest. `make ci` runs that digest under local Docker; goldens are generated only there. Lean: same toolchain and manifest; never deployed.

**Jobs (`timeout-minutes`)**
1. `pins` (3): lockfile matches everything, executable bits, LF endings.
2. `image` (8): `swipl:10.0.2@sha256:652375…` plus SBCL 2.6.9 tarball, our committed SHA-256 (SourceForge lists none; PGP once). Pushed to GHCR; deployment pulls this digest.
3. `core` (5): Lisp tests, plunit, Lisp-to-swipl round trip.
4. `oracle` (5): `python:3.11.3-slim` digest; reference checker, hash-locked SymPy 1.14.0, `PYTHONHASHSEED=0`.
5. `lean` (30 cold): v4.35.0, manifest-pinned Mathlib, narrow imports; axiom-audit, leanchecker; one domain-hypothesis theorem.
6. `sabotage` (6): see below.
7. `gate` (2): `needs` all, `if: always()`, requires each `success`. Only required check, because conditionally skipped jobs report Success. No path filters.

Weekly uncached run catches link rot.

**Anti-vacuity:** Runners emit ran/passed/skipped; `gate` compares with a committed manifest, so zero or fewer tests fails. `sabotage` must see each bad fixture fail with its expected message, not merely nonzero: failing Lisp and Prolog tests, `sorry`, custom axiom, `native_decide`, missing `x≠0`, bad certificate. `pipefail`; no `continue-on-error`.

**Tier D:** Python stdlib only, no SymPy, separate `ref/`, evaluator-based, reads only input text. CI fails on any import from engine or generated rules, and when one PR touches `engine/` and `ref/` without a `spec-change` label. Written from the semantics document without engine access, committed first.

**Mutation:** about 300 lines in-house, sb-posix and sb-cover only. Fork per mutant, recompile one defun, run the fast suite under timeout. Operators: arithmetic and comparison swaps, `and`/`or`, branch swap, guard to `t`, constant ±1. Uncovered mutants count as survivors. Inlining banned in core. Rule-table mutants (delete, corrupt, drop guard) must score 100%; code score reported raw and after triaged equivalents. M0 proves only one known kill. Prolog deferred.

**Risks:** (1) Mathlib cache plus toolchain versus 14 GB runner disk; (2) Mathlib cache host or SourceForge disappearing; (3) single author makes Tier D's errors common-mode.

**Cut:** Windows CI, `actions/cache` for own Lean build, nanoda, Maxima/Z3 in M0, arm64.

**Will not work:** "identical" natively on Windows. "Independently written" with one author: say separately derived. Staying free if private: 2 vCPU, 8 GB, $12 included, 500 MB shared with GHCR.

**Verified:** public standard runners free; 4 vCPU/16 GB/14 GB; 10 GB cache, LRU, 7-day expiry; 6-hour limit; skipped-job behaviour; swipl 10.0.2 tag, digest (re-pushed 28 Oct, so tags mutate), bookworm base; SBCL 2.6.9 files (2.6.10 exists); Lean v4.35.0; lean-action inputs.

**Assumed, unrun:** SBCL tarball on bookworm, Lean disk and timings, matching Mathlib tag, mutator design, all job limits.
