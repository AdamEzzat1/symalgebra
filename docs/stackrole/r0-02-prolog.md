# R0-02 Prolog Knowledge Architect

**Position.** Prolog proposes explanations. Lisp does every comparison, number and guard. Verdicts never wait on Prolog; on inference-limit exhaustion the verdict stands, unnamed. OUT_OF_FRAGMENT skips Prolog.

**Protocol: two calls, one stateless swipl.**
1. Lisp sends verdict, witness, ordered trees and flattened views with source paths; no student text reaches `read_term`.
2. Prolog returns candidates: derivation, unevaluated result (`plus(3,2)`), residual guards. Lisp folds, compares with After, evaluates guards (true/false/unknown), returns survivors. Prolog ranks and renders.

**AC.** No AC-unification. Lisp flattens; subjects are ground, so matching is one-way. Generated clauses pick from `sum`/`prod` lists with a rest variable, at most three slots per node, symmetric slots in index order. Mal-rules may declare `match: ordered`, because "distributes to the first term only" means nothing in a multiset.

**Comparison view.** Flatten, fold literals within one node, drop 0 and 1. No distribution, no like-term collection.

**Hypotheses.** EQUIVALENT searches sound rules only; mal-rules never touch a valid step. Otherwise: zero mal, then one, depth at most 2. A sound rule with a failed guard is generated automatically. Keep every minimal derivation, plus `slip` and `unknown`. Ties stay ties. The client resends the current problem's steps; Prolog replays them. A page-memory tally of mal-rule ids covers other problems. Name a mistake only if sole best hypothesis on two separate steps; otherwise show counterexample and next action.

**Explanations.** The generator rejects any template slot the pattern leaves unbound. Slots quote the student's tokens by path. Rejections lead with Lisp's counterexample. Mal text describes the step, never the student's thinking.

**Risks.** (1) Mal-rules collide on small numbers: compute a pairwise collision matrix before M5 and merge the inseparable. (2) Lisp and Prolog matchers drift: depth-1 sound edges must match byte for byte on the corpus. (3) Evidence may support fewer than 15 mal-rules.

**Cut.** Probabilities, BKT, strategy grammars, tabling, meta-interpreter, Prolog canonicaliser, SWI rationals, depth 3, two-mal derivations, disambiguating questions.

**Brief problems.**
- Two representations are not enough. Canonical form erases the step: 2(x+3) and 2x+6 coincide, so every value-preserving rule matches. The view above is a third, derived form.
- "Pattern, replacement" cannot express "add c to both sides": c is free. Add a closed list of parameter sources (term, coefficient, LCD).
- M3's Lisp rule search plus Prolog attribution means two matchers. Accept it (risk 2).
- Statelessness forces the replay.

**Verified** (swipl 10.0.2, throwaway 8-rule probe, coarse timer): a+b fails to unify b+a; 1680 list picks about 0.23 ms; depth 2 gave 404 candidates, 0.5 ms to generate, 47 KB, 6 ms to write and read back; inference limit fires. SymPy confirmed the collapse.

**Assumed.** Candidate count at 65 rules, Lisp fold cost, collision rates, the two-step naming threshold.
