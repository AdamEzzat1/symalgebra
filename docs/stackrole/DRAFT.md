# Integrated draft after round 1 (lead's decisions, under attack in round 2)

## Semantics
D1. Authoritative representations stay two: ordered tree and canonical + domain. `flat`, a
    derived AC-sorted unevaluated view, is a third derived form for matching and rperft states.
D2. Domain comes from the as-typed tree. Solution payload is Finite(F) | AllExcept(F), plus
    one rational witness. Sets only, no multiplicity.
D3. Fragment: one variable; + - * / parens; literal exponents 1..6, degree 8 for a line's
    combined numerator; 8-digit literals; 64 tokens; depth 16; multi-variable polynomial
    expressions only. `x^0`, radicals, abs, inequalities, chains, `or`, parameters, multi-var
    equations, identically zero denominators (`empty_domain`), irrational-only differences
    (`irrational_root`), ambiguous `1/2x`: OUT_OF_FRAGMENT or a parse query with reason code.
    All limits are judgement until measured.
D4. A step is accepted if EQUIVALENT against the previous line or vs_start. "Solved" requires
    vs_start EQUIVALENT, decided by Lisp.
D5. Tie rule ("valid, method unnamed") applies only under EQUIVALENT. A rule matching a
    GAINS/LOSES step does not make it valid. Mal-rules never touch an EQUIVALENT step, so
    `2x=4 -> x=4-2` passes silently, as a documented limit.
D6. Rule classes: equivalence and implication. Rule params come from a closed list of sources.

## Lisp / Prolog
D7. ONE matcher, in Lisp. Lisp enumerates sound, mal and failed-guard edges to depth 2, and
    owns guards and folding. One call to Prolog: verdict, edges, rule facts. Prolog owns
    selecting derivations, live hypotheses, replay, and rendering. No generated Prolog
    matchers. Cost accepted: no matcher cross-check, so rule examples must cover it. This keeps
    "Prolog owns attribution" only in the sense of interpreting candidates. Honest note:
    Prolog's job gets small and must earn its place at M5.
D8. One swipl child, FIFO owner thread, line framing, integer ids, mismatch kills. Inference
    limit calibrated on the host below the wall budget. Prolog death: verdict survives,
    `explanation` = ok | none | unavailable. `unavailable` and exhaustion are never "method
    unnamed" and never a coverage gap. Runtime logs hold a plain integer gap count only;
    coverage cases come from corpus in CI, never runtime hashes.
    All of this is M3/M5. M0 has only a swipl `hello` smoke test.

## Lean
D9. `ev : E -> R -> Option R` over as-typed trees, strict on zero divisors; Dom, Sol, toSet,
    implication theorems. Generated statements, hand-written proofs per id. Certificates carry
    as-typed trees. M0 has one hand theorem, `cancel_factor`, in Option form, because
    Option case-splitting is the riskiest assumption. Lean v4.35.0, Mathlib v4.35.0.

## CI (M0)
D10. Public repo (owner rules). Four jobs on ubuntu-24.04, actions pinned by SHA:
    build-test (digest-pinned Dockerfile: swipl:10.0.2 digest + SBCL 2.6.9 tarball with
    committed SHA-256; pins, exec bits, LF; Lisp test; swipl smoke), lean (30 min cold until
    measured; sorry, custom axiom and missing-hypothesis fixtures live inside this job),
    sabotage (expected failures with expected messages), gate (compares ran/passed with a
    committed manifest). `make ci` runs the same Dockerfile locally. "Same version" means same
    digest only inside containers; native Windows shares the upstream release only. No GHCR
    until a host exists. No mutator, oracle job, weekly run or label in M0.
D11. M0 needs Lean green once. After M0 exit, Lean moves out of the required gate until M4,
    so a Mathlib cache outage cannot stall M1 parser fixes. Lean time box: two working days.
    If exceeded, tell the owner and continue M1 (owner must rule: the brief puts Lean in M0).

## M1
D12. Plain text input, one per step, key row, no framework, no MathLive, no KaTeX, plain-text
    echo from Lisp. POST /api/check, 512-byte cap, stale token guard, separate `unparsed` reply.
    Strict CSP, everything self-hosted, system fonts.
D13. Checker: small SBCL scaffold, `scaffold/m1`, discarded at M3. Exact reducer to a*x+b with
    per-node checks before reduction: `/` by anything but a nonzero constant is OOF, product
    of two non-constant factors is OOF. Compare solution sets. Rejection substitutes the
    student's own root into the previous line. If the line has no root of its own: "this
    line has no solution; the original does". Witness otherwise behind "Show why" (counted
    as bottom-out). SymPy script at M1 checks 25 problems' lines plus perturbed steps;
    python Fractions re-substitutes every counterexample. This is not Tier D or E evidence.
D14. Bank of 24 linear problems, 10 per person, no brackets or fractions; hints nudge,
    operation, next line; first problem is a worked example.
D15. Sessions: stage A, 3 observed on the owner's machine plus a test phone over LAN: can
    stop, cannot certify. Stage B, 5 people in booked slots on a hosted URL, owner wakes the
    host first, wake time excluded and reported apart; silence after a booked slot is reported
    apart from "will not". Host account and recruiting are the owner's. Rusty non-contacts.
D16. Data: no server storage or results endpoint. In-tab counters; failed input exported only
    as token shape with unknown-character class; adult presses Copy and sends it; owner
    transcribes per-code results then deletes. Owner must rule that this is not "stored
    student data".
D17. Gate: a person passes with step completion on >=70% of multi-operation problems. Overall
    pass: >=5 of 8 and fewer than 3 people above 20% input failure after their first two
    problems. All-cannot failures get one input fix and retest; a will-not majority stops.
    A valid step marked wrong voids that session. Thresholds are judgement; detects
    catastrophe only.
