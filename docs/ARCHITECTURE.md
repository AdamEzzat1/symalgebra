# SymAlgebra: Architecture

Status 2026-11-01: M0 is complete. M1a is built and M1b, the adult sessions, is not yet run. M2 is
complete. The M4 five-rule trial ran early, on the owner's ruling, and passed. M3 started on
2026-11-01 before the M1 gate, also on the owner's ruling: M1 is unresolved, one stage A session has
passed on a computer, no phone session has run, and a failed gate could still force an input
redesign. The M3 core is built and Tiers A, D, E
and F pass, but M3 is not exited: its hosted latency gate has not been run. Numbers marked *measured*
come from throwaway probes on the development Windows machine.

Students type their own algebra steps. The system checks each step by its meaning, says
what rule was used where it can, and explains itself.

| Owner | Owns |
|---|---|
| Lisp (SBCL 2.6.9) | Parsing, exact arithmetic, canonical forms, domains, verdicts, rule matching |
| Prolog (SWI-Prolog 10.0.2) | Choosing derivations, live hypotheses, explanations |
| Lean 4 v4.35.0 + Mathlib | Rule soundness and certificate checking, at build time only |
| Frontend | Display and input. No algebra truth |

The full role records are in [stackrole/](stackrole/): `r0-*` are the independent
recommendations, `r1-*` and `r2-*` the critique rounds, `r3-*` the final review.

## 1. Stack role conclusions

1. **Lisp Engine Architect.** Plain lists, so `equal` is canonical equality. No third-party
   Lisp libraries. Deterministic fuel, because wall-clock limits make verdicts vary by machine.
   `3^20000000` took 70 s *measured*, so caps are mandatory.
2. **Prolog Knowledge Architect.** No AC unification; subjects are ground. After critique this
   role gave up generated Prolog matchers: Lisp already needs one matcher for rperft.
3. **Lean Engineer.** Shallow division is a trap: `{x | 1/x = 0}` is `{0}` in Mathlib. Use an
   `Option`-valued `ev` so a zero divisor has no value. Nothing was compiled.
4. **Algebra Semantics Expert.** Solution sets here are always finite or cofinite, so
   `GAINS {roots}` needs a two-shape payload. Domains come from the typed tree, never the
   canonical form. Sets only, no multiplicity. 4,401 random pairs agreed with explicit real
   roots in SymPy 1.14 *measured*, without Lisp.
5. **Learning Science Lead.** M1 tests willingness to type steps, never learning. "Will not
   type" must be separated from "need not" and "cannot".
6. **Integration Engineer.** One `swipl` child with a FIFO owner thread. Line framing, because
   an unterminated term under `read_term` gave no reply in 1 s *measured*. Prolog failure must
   read as `unavailable`, never as "method unnamed".
7. **Frontend Engineer.** Plain text with a key row. MathLive costs 217 kB gzipped, has open
   NVDA issues, and would add a LaTeX parser to Lisp. No framework and no build step.
8. **Test Engineer.** "Same version" is only true per container digest. A green CI must be
   proved non-vacuous by a manifest of ran and passed counts, plus expected failures.
9. **Privacy Reviewer.** The settled server means the host sees IPs and steps in transit. The
   site must say so; "we store nothing" alone would be false.
10. **Systems Reviewer.** Lean must not stall the test of the riskiest assumption. Cut the M1
    build to the smallest honest thing, and name every conflict for the owner.

## 2. Semantics (M2 document, summarised)

- **Representations.** Two authoritative: the ordered tree, and canonical form with a domain
  record. `flat` is a derived, AC-sorted, unevaluated view for matching and rperft states.
  It exists because canonical form erases the step: `3x+x=4` and `4x=4` coincide.
- **Domain.** `D(e)` removes the zeros of every denominator in the as-typed tree.
  `S(l=r) = {x ∈ D : l(x) = r(x)}` over ℝ. Sets, no multiplicity: `x=1` and `(x-1)²=0` have no
  pointwise counterexample, so rejecting one would break the counterexample requirement.
- **Payload.** `Finite(F) | AllExcept(F)` plus one rational witness. `x=1 → 0=0` is
  `GAINS AllExcept{1}`.
- **Fragment.** One variable; `+ - * /`, parentheses, literal exponents 1..6, degree at most 8
  for a line's combined numerator; 8-digit literals, 64 tokens, depth 16; a 4096-bit precheck
  before every multiply and `expt`, because `(((9^6)^6)^6)^6` otherwise passes the other caps.
  Multi-variable polynomial expressions are EQUIVALENT or UNRELATED only. All limits are
  judgement until measured.
- **OUT_OF_FRAGMENT with a reason code.** `x^0`, radicals, abs, inequalities, chains, `or`,
  parameters, multi-variable equations, identically zero denominators (`empty_domain`, else
  `1/0 → 2/0` passes vacuously), `limit`, unknown symbols, and `irrational_root` when any member
  of a difference or `AllExcept` set is irrational. `1/2x` and `x/2x` return a parse query.
- **Line handling.** Accept a line if it is EQUIVALENT to the previous line or to line 0. A
  `Finite` GAINS with variable denominators present commits as "caution" and stays unsolved, so
  `x/(x-1)=1/(x-1) → x=1 → no solution` stays reachable. Every other GAINS rejects, including
  every `AllExcept` gain such as `2x=6 → 0=0`, and every GAINS in the M1 scaffold.
- **Solved.** An equation task is solved when the line is EQUIVALENT to line 0 **and** is
  `x=literal`, `literal=x`, or the choice `no solution` or `all real numbers`. An expression
  task is solved when the line's tree is the canonical printed form and it equals line 0, with
  any stated exceptions shown. So `(x²-1)/(x-1) → x+1` ends with "x≠1" stated.
- **Ties.** "Valid, method unnamed" applies only under EQUIVALENT. A rule matching a GAINS
  step does not make it valid. Mal-rules never touch an EQUIVALENT step, so `2x=4 → x=4-2` passes
  silently. That is a documented limit.
- **Rule classes.** Equivalence and implication. Rule parameters come from a closed list of
  sources (term, coefficient, LCD).

**M2 delivered, 2026-11-01.** The full definitions are in [SEMANTICS.md](SEMANTICS.md) and
[RULE-FORMAT.md](RULE-FORMAT.md). [rules/rules.sexp](../rules/rules.sexp) holds 40 sound rules and no
mal-rules. [corpus/](../corpus) holds 39 solutions across the three scope areas and 43 verdict
cases. [oracle/](../oracle) checks both with exhaustive strict evaluation, SymPy on schemas, and
exact solution sets, and five planted faults must each fail first. The owner chose to run M2 before
the M1 gate because it mostly survives an input redesign. The M3 hold was later lifted by the owner.

Open at M2 exit: the corpus's rule labels only name rules that exist. Whether each label describes
its step needs the AC matcher, so M3 checks that. No generator exists yet. Nothing here is proved.
M2 found that `transpose-add` and `transpose-sub` need no `total` guard, because the term stays on
both sides, so the guard-necessity check removed it.

## 3. Lisp and Prolog (M3, M5)

- **One matcher, in Lisp.** The verdict is computed first. Lisp then enumerates sound, mal and
  failed-guard edges to depth 2, and sends Prolog only edges whose `flat` result equals the
  student's line, with an `accepted` flag and a `complete` flag.
- **Prolog** selects derivations, keeps hypotheses, replays, and renders. Evidence is keyed on
  (Before, mal id), so retyping a rejected line is not a second observation.
- **Bridge.** One child, FIFO depth 4, line framing, integer ids, a mismatch kills. One
  inference limit pinned in the ruleset. Caller-side deadline: at 150 ms answer `unavailable`
  and discard the late reply by id; a watchdog kills at 1 s.
- **Explanation state.** `ok | none | unavailable`. Only `none` with `complete:true` means
  "method unnamed" and only that counts as a coverage gap. Truncated enumeration, exhaustion
  and a dead child are all `unavailable`, and the verdict still stands.
- **Coverage data.** A plain integer count at runtime. Cases come from the corpus in CI. Hashes
  of short algebra strings can be brute-forced, so they are not logged.

**M3 core, 2026-11-01.** [engine/src/](../engine/src) holds the ordered tree, the canonical form with
its domain record, verdicts, bounded rule search, rperft and the step rules, in about 1,100 lines with
no third-party libraries. Rational roots are found by exact bisection and irrational ones are compared
by Sturm sequences, so no float enters. The rule table is read from `rules/rules.sexp` at load.

| Tier | Evidence, in the pinned image |
|---|---|
| A | 346 of 346 checks: every corpus verdict and solution, the caution path, witnesses re-substituted |
| D | 1,200 of 1,200 seeded cases match the oracle byte for byte, with CI checking the fixture is current |
| E | SymPy re-checks 3,467 edges and all pass. They are a sample of the 16,695 walked, each of which also passes the Lisp verdict invariant. Every rule that moves a line appears |
| F | 4,315 property and metamorphic checks. Mutation score 48 of 49, and the survivor flips one sign convention and is equivalent |

A wrong distribution rule injected into rperft is caught by the invariant. All 171 corpus label checks
pass, which closes the question M2 left open. Getting there needed the matcher readings in
[RULE-FORMAT.md](RULE-FORMAT.md), and no label changed. rperft counts in
[corpus/rperft.txt](../corpus/rperft.txt) are regression values, not truth.

Latency over the 171 corpus steps, *measured* in the pinned image on the development machine, not on a
server: verdict p50 58 µs, p95 127 µs, max 5 ms. Explanation at depth 2: p95 0.9 ms, max 37 ms, naming a
rule for 169 of 171. The slowest refusal tried took 77 ms. That is one hand-picked line, not a proven worst case.

**M3 is not exited.** The p95 gate is defined on the hosted server and no host exists, so that gate has
not been run. The step rules are a library: nothing serves them yet, and the M1 scaffold still runs
stage A unchanged. Expression tasks such as `(x²-1)/(x-1) → x+1` are not built, because a line here is
an equation. Mal-rules and failed-guard edges reach Prolog at M5, so only the Lisp side exists. Lisp and
SymPy can disagree on `degree_limit` when a line's numerator cancels near degree 8; no fixture case
does. Tier D's reference shares a brief with this code, so agreement is strong evidence, not proof.

## 4. Lean (M4; one theorem in M0)

- `ev : E → ℝ → Option ℝ` over as-typed trees, defined through `pdiv`, so `ev (1/x) 0 = none`,
  with that fact as a test. `Dom`, `Sol`, `toSet`, plus implication theorems (`Sol A ⊆ Sol B`).
- Statements generated, proofs hand-written per rule id. Certificates carry as-typed trees.
- A missing hypothesis is caught by a guard-necessity theorem proved by witness (`¬∀ …`).
  Merely stripping a hypothesis from a hand proof fails with "unknown identifier": the right
  red for the wrong reason.
- `sorry` only warns, so `lake build` passes. `sorry` and custom-axiom fixtures go through
  `#print axioms`.

**What Lean does not prove.** The Lisp implementation, parser, printer, generator, hints, or
any learning benefit. AC matching and instantiation are not covered by schema theorems, only by
per-solution certificates. "The engine is proven correct" must never be claimed.

**Five-rule trial, 2026-11-01.** The owner chose to run it during stage A because it needs no engine
and mostly survives an input redesign. [oracle/gen_lean.py](../oracle/gen_lean.py) generates the
statements of `distribute`, `mul-zero`, `div-by-fraction`, `add-both` and `cross-multiply` from the
rule file, and CI fails if they are stale. [Trial.lean](../lean/SymAlgebra/Trial.lean) proves all
five, plus a witness refuting each of the three rules with its semantic guard dropped. Every proof
uses only `propext`, `Classical.choice` and `Quot.sound`. A false distribution rule fails the same
tactic script with `unsolved goals`.

The Lean job took 1 min 49 s *measured* with the cached Mathlib subset: 82 s to fetch it, 10 s to
build, 12 s to audit, and about 4 GB of disk. The first two of the three runs to reach green failed
on one line each, because `ring` and a cast lemma were not in scope. No statement changed.

What the trial does not show:
- 23 of the 40 rules can be stated today. The other 17 need `sub` (10), `eval` (5), `neg` (1) and an
  expression-level implication form (1), so the model and generator must grow before scaling.
- `Total` means "has a value at every x". The `total` guard's syntactic check is not modelled, so
  nothing proves that the check implies this meaning.
- The trial's five were chosen to vary in shape, so their cost is no estimate for the rest.
- Lean stays off the required path. `lean_required` is false and the job runs on demand.

## 5. M0 plan: toolchain

Files: `Dockerfile`, `scripts/`, `tools.lock`, `engine/` (one Lisp test), `knowledge/` (`hello`
smoke test), `lean/` (toolchain, manifest, one theorem), `.github/workflows/`, `.gitattributes`.

| Job | Limit | Proves |
|---|---|---|
| `config` | 2 min | Reads `lean_required`; computes the image cache key from the Dockerfile hash |
| `build-test` | 20 min (a cold SBCL build took 771 s locally; cached runs are far shorter) | Digest-pinned image builds or loads from the Actions cache; pins, exec bits, LF; Lisp test; swipl smoke; versions printed |
| `lean` | 30 min; measured about 2 min, with no `.lake` cache | Pinned Mathlib fetch; trivial theorem; `#print axioms`; `sorry` and axiom fixtures fail |
| `sabotage` | 6 min | Each bad fixture fails with its expected message |
| `gate` | 2 min | `if: always()`; every `needs` result is `success`, with `skipped` accepted for `lean` only when `lean_required` is false; ran and passed counts match a committed manifest |

M1 adds one job, `checker`, on the `python:3.11.3-slim` digest with hash-locked SymPy 1.14.0, in
`needs` and the manifest, so parser fixes during M1 cannot bypass the checker evidence.

- Base: `swipl:10.0.2` by digest (the tag was re-pushed on 28 October, so tags mutate) plus
  SBCL 2.6.9 built from its source tarball with a committed SHA-256. The prebuilt binary needs
  GLIBC 2.38 and the image has 2.36. A build stage bootstraps with Debian's `sbcl` 2.2.9, gcc and
  make; none of that reaches the final image (337 MB). Actions pinned by SHA. `ubuntu-24.04`.
- `sh scripts/ci.sh` runs the same Dockerfile locally. The repo goes into the container as a tar
  stream on stdin, because Docker Desktop folder sharing was declined on this machine and CI
  should not depend on it. Inside containers "same version" means same
  digest. Native Windows shares only the upstream release, and goldens are generated in the
  container. CI rebuilds give the same pins, not the same bytes. No GHCR until a host exists.
- A committed `lean_required` flag is read by `gate` and the manifest. M0 exit needs the trivial
  theorem green. `cancel_factor` in `Option` form has its own one-day box and is reported, not
  required, because a slow proof must not read as CI failure. After M0 exit Lean leaves the
  gate and manifest and runs on demand. M4 re-entry needs one cold green.

**M0 needs the approvals in section 11** before the first download, `git init` or push.

**M0 exit gate.** A fresh clone passes all jobs on a pushed commit, versions print and match
`tools.lock`, and a sabotage branch turns each job red with the expected message.

**M0 exit, met on 2026-11-01.** Run 41263001966 passed every job with Lean required. Each job
then went red on a throwaway branch with the expected message: `config` on a missing flag file
(41263874029), `build-test` and `checker` on one wrong authored line (41263787090), `sabotage` on
a fixture that stopped failing (41263815325), `lean` on `sorry` in `cancel_factor` (41263820476),
and `gate` on a manifest wanting one more test (41263846349). `cancel_factor` and both guard
witnesses are proved, using only `propext`, `Classical.choice` and `Quot.sound`. `lean_required` is
now false, so Lean runs only through `workflow_dispatch` until M4.

**M0 stop.** Three working days without a pinned SBCL. Two working days on Lean, or a cached
Lean run above 15 minutes: pause Lean, tell the owner, continue M1 only if the owner so rules.

## 6. M1 plan: step-entry test

**Build (M1a).**
- `scaffold/m1/`: a small SBCL server, discarded at M3 and clearly not the engine. Exact
  reduction to `a*x+b` with checks per node before reduction: `/` by anything but a nonzero
  constant is OUT_OF_FRAGMENT, and so is a product of two non-constant factors, even
  `x*x-x*x`. Otherwise `(2x+2)/(x+1)=2` would reduce with a wrong domain.
- `POST /api/check {"v":1,"problem":"lin-07","previous":"…","text":"…"}`, 1 KB cap, 256 characters
  per line. A separate `unparsed` reply carries a column. The server stays stateless.
- One plain text field per step, key row, plain-text echo from Lisp, "not what I meant" button.
  Stale guard: a reply applies only if token, problem and field text all still match; an
  edit cancels; unknown replies say "not checked", never wrong.
- Input alphabet: digits, `+ - * / = ( ) .`, space, and the problem's variable. `no solution`
  and `all real numbers` are buttons, not typed text. The page refuses to send anything else
  and counts it locally, so letters other than the variable never reach the server. Digits
  still can. This is input handling, not algebra truth.
- Strict CSP, all files self-hosted, system fonts. Export is both Copy and a selectable
  read-only textarea, since `navigator.clipboard` fails on plain HTTP over a LAN.

**Choices made while building.** 24 problems: one worked, eight single-operation, fifteen
multi-operation, one with no solution and one true for all reals. A session is the worked example
plus three single and six multi, so nine count. `no solution` and `all real numbers` have their own
counter and are not attempts. Off the authored path, hints use general wording and the last level
is the final line, which is a bottom-out like any other. The echo becomes the next `previous`, so
a test requires every echo to parse back to the same meaning.

**Rejection feedback.** Branch on the shape of both solution sets (∅, {r}, ℝ). The witness comes
from `S_prev \ S_line`, otherwise `S_line \ S_prev`.

| Previous → line | Message shape |
|---|---|
| `2x=6 → x=4` | Substitute the student's own root into the previous line |
| `2x=6 → 0=1` | "This line has no solution; the one before it does" |
| `2x=6 → 0=0` or `6=6` | "Every x works here; the one before it has one solution", with a non-root on "Show why" |
| `x=x → x=1` | Show a point where the lines disagree |

**Content.** 24 linear problems, ten per person with at least six multi-operation, no brackets
or fractions. First problem is a worked example teaching input, excluded from the metrics. Hints: nudge, operation, next line.
Bottom-out needs one attempt and retyping. No rule names and no mal-rule naming.

**Checker evidence.** Zero OUT_OF_FRAGMENT on authored lines. A SymPy script checks every authored
line plus perturbed steps with committed expected classes, including `6=6`. Python `Fraction`
re-substitutes every counterexample. A reducer failure test runs first. This is not Tier D or
Tier E evidence.

**Sessions (M1b, run by the owner).**
- Stage A: 3 people observed on the owner's machine. A test phone over LAN is optional on the
  owner's ruling of 2026-11-01, which puts the website first. Zero passes of 3 stops before stage
  B. Stage A cannot certify on its own.
- Stage B: 5 rusty non-contacts in booked slots on a hosted URL. The owner wakes the host first;
  wake time is excluded and reported apart. A no-show who never starts is replaced; one who starts
  and stops is a non-pass.

**Data.** No results endpoint and no server storage. Tab counters only. Failed input is exported as
token shape with an unknown-character class, never raw. The tester picks a random code, the adult
presses Copy and sends it. The owner keeps no name-to-code map, transcribes per-code results,
deletes the messages and the bookings. Stage B conditions: no card, an 18+ statement, a notice
that the host sees IPs and steps, section 2's limits in the scaffold, a log canary test on the
hosted image, and the service suspended outside slots.

**Look.** The page was restyled with CSS only after the first counted session, on the owner's
ruling. Input, checking and counters did not change.

**Measures.** Attempt: one Check on a non-empty line, or a line refused locally. Input failure:
parser rejection, a line refused locally, or an accepted line flagged "not what I meant".
"Cannot": above 20% input failure after the first two problems. Step completion: a multi-operation problem solved with
at least one self-typed intermediate line and no bottom-out hint.

**M1 exit gate.** A person passes with step completion on at least 70% of their multi-operation
problems. Overall pass needs at least 5 of 8, at least 3 of 5 in stage B, and fewer than 3 people
above 20% input failure after their first two problems. A valid step marked wrong voids that
session. Voided sessions and retests use new people, since returning testers pass on familiarity.

**M1 stop.** If the gate fails and every failure is "cannot", make one input fix and retest. Any
other failed gate stops the project for redesign. True pass rates of 30, 50 and 80% clear the full
gate 5.0, 32.4 and 91.8% of the time *computed*. The thresholds are judgement, they detect
catastrophe only, and adult results do not transfer to younger learners.

## 7. Disagreements on record

| Question | Positions | Outcome |
|---|---|---|
| Who enumerates rule applications | Roles 1 and 2 each conceded to the other in round 1 | Lisp. One matcher beats a cross-check, and it matches M3 in the brief. Cost: no matcher cross-check, and Prolog's job is thin. M5 must show it earns its place |
| Hosted or local M1 | Role 5: hosted, or it never tests strangers. Roles 7, 9: observed only. Role 10: both | Both, staged. Role 9 accepts stage B on conditions. Role 7's objection stands on record |
| Lean in the gate | Role 8: required. Role 10: out until M4 | Required once for M0 exit, then out. Owner rules |
| First Lean theorem | Role 3: `cancel_factor`. Role 10: `linear_combination` or trivial | Trivial theorem for exit; `cancel_factor` boxed apart |
| Failed-input export | Role 5: raw strings. Role 9: token shape | Token shape. Role 5 retracted |
| Multiplicity | None | Sets only |

## 8. Rejected

- The report's Rust/WASM path and static site: overruled by settled decisions. Cost on record: the
  report ranked this stack 4th, and a server exposes IPs and steps to the host.
- Numeric checking in the browser: a second source of truth, using floats.
- Authored-path matching as the check: marks valid steps wrong.
- MathLive, KaTeX, React, Vite, MathML output, WebSocket, GHCR at M0, Windows CI, M0 mutation
  testing, Prolog worker pool, two-call Prolog protocol, runtime expression hashes, localStorage.

## 9. Proposed amendments to the brief

The brief wins until the owner agrees.

1. `GAINS/LOSES {roots}` becomes `Finite(F) | AllExcept(F)`.
2. The tie rule narrows to EQUIVALENT, otherwise `x/(x-1)=1/(x-1) → x=1` would be called valid.
3. "Logged as a test case" becomes corpus-only in CI, since runtime logging conflicts with no
   request bodies in logs.
4. "Independently written" Tier D becomes "separately derived": one author shares misreadings.
5. "Sound edge preserves the solution set" applies to equivalence rules; implication rules
   preserve the subset relation.
6. M3's p95 under 100 ms measures the verdict alone, reporting explanation, warm and cold apart.

## 10. Unverified figures

- Lean is measured only on GitHub's runner, never on this machine. On the first green run the
  selective cache was 824 files and about 4 GB, leaving 8.8 GB of the runner's disk free. The
  April figure of 7 GB for a full cache does not apply to a selective fetch.
- The swipl bridge figures are Windows only. Linux, `--cpus=0.1` and real rule costs are unmeasured.
- Render: IP retention, DPA terms and no-card signup rest on secondary or partial sources.
- The report's own flagged figures (RAND, WWC, Pane, ASSISTments test, gaming link) are not used.

## 11. Owner approvals, granted

Granted by the owner on 2026-10-31 as recommended, except item 2, where the owner chose private.

| # | Decision | Recommendation |
|---|---|---|
| 1 | `git init`, creating GitHub repo `AdamEzzat1/symalgebra`, and the pushes M0 and M1 need | Approve, as a standing grant for this repo only |
| 2 | Visibility | **Private, by owner decision.** 2,000 Actions minutes a month on 2 vCPU and 8 GB, each job rounded up to a whole minute, so Lean's on-demand rule matters |
| 3 | Downloads, below | Approve. Lean runs on GitHub's runner, not on this machine |
| 4 | Lean overrunning its time box | M1 continues, as a `lean_required` flip recorded in the repo |
| 5 | Section 9 amendments | Accept all six |
| 6 | Exports are not "stored student data" (D16) | Accept: token shapes, adults, pressed by hand, deleted after transcription |
| 7 | Stage B on a public host, with an account the owner creates; thresholds as written | Accept. Decide after M1a is built |
| 8 | `scaffold/m1` as an approved M1 endpoint | Accept |

| Download | Source | Size | Where |
|---|---|---|---|
| `swipl:10.0.2` by digest | Docker Hub | 94 MB compressed | This machine, CI |
| `python:3.11.3-slim` by digest | Docker Hub | 45 MB compressed | This machine, CI (M1) |
| SBCL 2.6.9 source tarball | SourceForge | 8.8 MB | Build stage, both |
| Debian `sbcl` 2.2.9, gcc, make, headers | Debian bookworm | About 62 MB | Build stage only, both |
| elan v4.2.4 | GitHub | 5 MB | CI only |
| Lean v4.35.0 toolchain | GitHub | 566 MB compressed | CI only |
| Mathlib v4.35.0 source and selected cache | GitHub, Mathlib cache host | Unmeasured; full cache about 7 GB | CI only |
| SymPy 1.14.0 | PyPI | Already installed locally | CI (M1) |

Licences are recorded in `tools.lock`.

## Appendix: critique rounds

| Round | Who | Asked | File |
|---|---|---|---|
| 0 | All ten, isolated | Independent recommendation | `r0-*` |
| 1 | All ten | Strongest, weakest, conflict, retractions | `r1-*` |
| 2 | All ten | Failure modes of the integrated draft (`DRAFT.md`) | `r2-*` |
| 3 | Roles 4, 5, 8, 9, 10 | Final review of this document | `r3-*` |

Roles 1, 2, 3, 6 and 7 did not take part in round 3. Their round 2 fixes are applied here but
they have not re-read the result. All five reviewers accepted with small changes, now applied.
The Systems Reviewer's stop recommendation was not triggered; the free-host question stays
open on secondary sources.
