# Semantics

What a line means and what the verdict on a step is. M3's Lisp core must agree with this document,
and the executable reference is [oracle/semantics.py](../oracle/semantics.py).

Scope is linear equations, distribution and like terms, and fractions. Powers exist in the
fragment only so that steps like `x = 1 → (x - 1)^2 = 0` get an honest verdict. No rule teaches them.

## Lines

A line is `left = right` in one variable, kept as an ordered tree of what was typed. Nothing is
simplified on parsing, so `x/x` stays `x/x`.

Numbers are exact. Decimals are read as exact rationals, and floats appear nowhere. Products can be
written with `*` or by juxtaposition, `*` and `/` read left to right, and unary minus on a number
gives a negative literal.

## Domain and solution set

`D(line)` is every real number, minus the zeros of every denominator **in the typed tree**. Domains
never come from a simplified form, so `x/x = 1` excludes 0 even though it simplifies to `1 = 1`.

`S(line) = {x ∈ D(line) : left(x) = right(x)}`, over the reals.

**Multiplicity is not counted.** Solution sets are sets. `x = 1` and `(x - 1)^2 = 0` have the same
set and no pointwise counterexample, and rejecting a step requires one. Every `S` is finite or
cofinite, written `Finite(F)` or `AllExcept(F)`.

## Verdicts

| Verdict | Condition | Payload |
|---|---|---|
| `EQUIVALENT` | `S(previous) = S(line)` | None |
| `GAINS` | `S(previous) ⊂ S(line)` | `S(line) \ S(previous)` |
| `LOSES` | `S(line) ⊂ S(previous)` | `S(previous) \ S(line)` |
| `UNRELATED` | Neither contains the other | `S(previous) \ S(line)` |
| `OUT_OF_FRAGMENT` | See below | A reason code |

Every verdict but `EQUIVALENT` and `OUT_OF_FRAGMENT` carries one exact rational witness on which the
two lines disagree. A step is never rejected without one. The verdict is computed from meaning, and
rule matching only explains a step afterwards.

Examples: `2x = 6 → x = 4` is `UNRELATED`. `2x = 6 → 0 = 1` is `LOSES Finite{3}`. `2x = 6 → 0 = 0` is
`GAINS AllExcept{3}`. `x/(x - 1) = 1/(x - 1) → x = 1` is `GAINS Finite{1}`.

The brief wrote `GAINS {roots}`. A gained set can be infinite, so the accepted amendment uses
`Finite | AllExcept`.

## The fragment

Outside the fragment the answer is `OUT_OF_FRAGMENT` with a reason, never a guess.

| Reason | Trigger |
|---|---|
| `unparsed` | The line cannot be read, including inequalities and `abs` bars |
| `unknown_symbol` | A letter other than the variable, or a named function |
| `chain` | More than one `=` |
| `ambiguous_division` | `1/2x` and `x/2x`: a division followed by juxtaposition. This is a question to the student |
| `exponent_range` | An exponent outside 1 to 6, including `x^0` |
| `degree_limit` | A line's combined numerator above degree 8 |
| `literal_too_long` | A literal with more than 8 digits |
| `too_many_tokens` | More than 64 tokens |
| `too_deep` | Brackets nested more than 16 deep |
| `empty_domain` | A denominator identically zero. Otherwise `1/0 → 2/0` would pass vacuously |
| `irrational_root` | Any member of a difference set is irrational, so no rational witness exists |
| `limit` | A number passes 4096 bits, or the fixed work budget runs out. Lisp only: the oracle has no such limit |

An irrational root that both lines share is fine: `x^2 = 2 → x^4 = 4` is `EQUIVALENT`.

Multi-variable input is out of the fragment for now. Section 2 of ARCHITECTURE.md allows EQUIVALENT
or UNRELATED for multi-variable expressions, but nothing in the current scope needs them. The limits
are judgement. The 4096-bit precheck before multiplication belongs to the Lisp core, because the
oracle has no time limit to protect. Lisp counts `degree_limit` on the numerator in lowest terms.

## Using a verdict

These rules decide what the tutor does with a verdict. They are M3 behaviour, and the corpus records
the verdicts they rely on.

- **Accept** a line if it is `EQUIVALENT` to the previous line or to line 0.
- **Caution.** A `Finite` `GAINS` with variable denominators present commits with a caution and stays
  unsolved, so `x/(x - 1) = 1/(x - 1) → x = 1 → no solution` stays reachable.
- **Reject** every other `GAINS`, including every `AllExcept` gain such as `2x = 6 → 0 = 0`.
- **Solved.** The line is `EQUIVALENT` to line 0 and is `x = literal`, `literal = x`, or the choice
  `no solution` or `all real numbers`. A literal here may be a fraction of two numbers.
- **Ties.** "Valid, method unnamed" applies only under `EQUIVALENT`. A rule matching a `GAINS` step
  does not make it valid. Mal-rules never touch an `EQUIVALENT` step, so `2x = 4 → x = 4 - 2`
  passes silently: it lands on the right root by a wrong route. That is a documented limit.

## Soundness of rules

[RULE-FORMAT.md](RULE-FORMAT.md) defines the two rule classes. Strict evaluation is why this matters:
Mathlib has `x / 0 = 0` and SymPy turns `x/x` into `1` on sight, so neither alone can see that
`(1/x) * 0 → 0` invents a root. The Lean model uses `Option`-valued evaluation for the same reason.

The evidence here is oracle evidence: exhaustive strict evaluation over a small pool at 8 points,
SymPy on symbolic schemas, and exact solution sets on sampled equation instances. It can find a
counterexample, and it proves nothing. Proofs are M4's job.
