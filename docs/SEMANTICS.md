# Semantics

What a line means and what the verdict on a step is. M3's Lisp core must agree with this document,
and the executable reference is [oracle/semantics.py](../oracle/semantics.py).

Scope is linear equations, distribution and like terms, fractions, and quadratics with rational roots
or roots of the form `a + b*sqrt(d)`, inequalities, absolute values and square roots over the variable,
on the owner's rulings of 2026-11-01.

## Lines

A line is `left = right` in one variable, kept as an ordered tree of what was typed. Nothing is
simplified on parsing, so `x/x` stays `x/x`.

A line can also be alternatives, `x = 2 or x = 3`, each a whole equation. `or` is read as a word unless
the problem's variable is `o`.

`sqrt(a)` and `√a` are the same thing. With no variable in it, `a` must come to a nonnegative rational
number. With the variable in it, `sqrt(a)` has a value where `a` is 0 or more. `±` stands for
two alternatives, so `x = 1 ± sqrt(5)` is `x = 1 + sqrt(5) or x = 1 - sqrt(5)`. A line may hold one `±`,
and not beside an `or`. `+-` keeps its old meaning, a sum with a negative number.

Numbers are exact. Decimals are read as exact rationals, and floats appear nowhere. Products can be
written with `*` or by juxtaposition, `*` and `/` read left to right, and unary minus on a number
gives a negative literal.

A line can also be an inequality: `<`, `<=`, `>`, `>=`, `≤` or `≥`. `a < b < c` is the two inequalities
`a < b` and `b < c` together, read the same way round. `a < b > c` and `a < b = c` are `chain`.

`|a|` and `abs(a)` are the same thing. A bar inside bars always closes them, so nested absolute values
need `abs(...)`. A number beside bars multiplies, as in `2|x|`, and `1/2|x|` is `ambiguous_division`.

## Domain and solution set

`D(line)` is every real number, minus the zeros of every denominator **in the typed tree**. Domains
never come from a simplified form, so `x/x = 1` excludes 0 even though it simplifies to `1 = 1`.

`S(line) = {x ∈ D(line) : left(x) = right(x)}`, over the reals. Alternatives have the union of their
sets, each with its own domain, so `x/x = 1 or x = 0` holds at 0 through its second alternative.

**Multiplicity is not counted.** Solution sets are sets. `x = 1` and `(x - 1)^2 = 0` have the same
set and no pointwise counterexample, and rejecting a step requires one. Every `S` is finite or
cofinite, written `Finite(F)` or `AllExcept(F)`.

A line with an inequality or an absolute value in it, and any step with such a line on either side, is
read through a **sign chart**: the sorted breakpoints, and whether the line holds at each one and in each
gap between them. The breakpoints are every root and every removed value of every relation on the line,
with each absolute value read both ways. Both sides are continuous away from a removed value, so a
relation's truth can only change where its two sides meet, in whichever reading applies there. A kink
that is not such a point changes nothing, so a line's truth cannot change inside a gap, and one point
decides each gap, evaluated strictly as above.

A line with a root over the variable is read through a sign chart too. Each root is a new unknown whose
square is known, and the difference of the two sides is multiplied by itself with every choice of signs
on those unknowns. What is left has no root in it, and its roots hold every place the sides could meet.
The other breakpoints are where each radicand is 0 and each removed value. Whether a line holds at a
slot is decided there: the radicands' signs exactly, then the sign of the difference from rational
bounds on each root, tightened up to 1024 bits. Two sides that are equal never come apart in bounds, so
they then get an exact value, and if that value has no form here the line is refused.

## Verdicts

| Verdict | Condition | Payload |
|---|---|---|
| `EQUIVALENT` | `S(previous) = S(line)` | None |
| `GAINS` | `S(previous) ⊂ S(line)` | `S(line) \ S(previous)` |
| `LOSES` | `S(line) ⊂ S(previous)` | `S(previous) \ S(line)` |
| `UNRELATED` | Neither contains the other | `S(previous) \ S(line)` |
| `OUT_OF_FRAGMENT` | See below | A reason code |

Every verdict but `EQUIVALENT` and `OUT_OF_FRAGMENT` carries one exact witness on which the two lines
disagree, a rational or `a + b*sqrt(d)` with rational `a`, `b` and squarefree `d`. It is the smallest
member of the payload, or for `AllExcept` the first whole number from 0 that is not excluded. A step is
never rejected without one. The verdict is computed from meaning, and rule matching only explains a
step afterwards.

Examples: `2x = 6 → x = 4` is `UNRELATED`. `2x = 6 → 0 = 1` is `LOSES Finite{3}`. `2x = 6 → 0 = 0` is
`GAINS AllExcept{3}`. `x/(x - 1) = 1/(x - 1) → x = 1` is `GAINS Finite{1}`.

The brief wrote `GAINS {roots}`. A gained set can be infinite, so the accepted amendment uses
`Finite | AllExcept`.

A step read through a sign chart has payload `Finite{...}` if every piece is one value, and otherwise
`Ranges{...}`, its pieces in order: `(-inf,3)`, `[1,5)`, and `{4}` for one value among the ranges. Its
witness comes from the first piece: the value itself, the midpoint of two bounds, one past the only
bound, or 0 if the piece is every real number. So `-2x < 6 → x < -3` is `UNRELATED Ranges{(-3,inf)}`,
witness `-2`.

## The fragment

Outside the fragment the answer is `OUT_OF_FRAGMENT` with a reason, never a guess.

| Reason | Trigger |
|---|---|
| `unparsed` | The line cannot be read, including an open bar or bars inside bars |
| `unknown_symbol` | A letter other than the variable, or a named function other than `sqrt` |
| `chain` | More than one `=`, an equals beside an inequality, three inequalities, or two running opposite ways |
| `ambiguous_division` | `1/2x` and `x/2x`: a division followed by juxtaposition. This is a question to the student |
| `exponent_range` | An exponent outside 1 to 6, including `x^0` |
| `degree_limit` | A line's combined numerator above degree 8 |
| `literal_too_long` | A literal with more than 8 digits |
| `too_many_tokens` | More than 64 tokens |
| `too_deep` | Brackets nested more than 16 deep |
| `empty_domain` | A denominator identically zero. Otherwise `1/0 → 2/0` would pass vacuously |
| `irrational_root` | A difference set has a real member that cannot be written exactly: with its rational roots out, the difference polynomial has degree above 2, or a root that is not `a + b*sqrt(d)` |
| `abs_limit` | More than 3 absolute values on a line |
| `radical_variable` | A polynomial reading of a line that has a root over the variable. No verdict reaches this |
| `radical_limit` | More than 3 different roots over the variable in one equation of a step |
| `radical_denominator` | A root over the variable in a denominator, such as `1/sqrt(x)` |
| `negative_radicand` | A negative number under a root. It has no real value |
| `nested_radical` | A root under a root |
| `many_radicals` | A step writes two different radicals, such as `sqrt(2)` and `sqrt(3)`. Sets hold one `d` at a time |
| `limit` | A number passes 4096 bits, the fixed work budget runs out, or a radicand is too big to factor. Lisp only: the oracle has no such limit |
| `expression_form` | An expression task line with an inequality, bars or a root over the variable |
| `nonlinear_system` | A system with a product of letters, a power of a letter, a letter below, or a root |
| `too_many_equations` | A system of more than 4 equations |
| `complex_degree` | A complex line beyond degree 2 once its rational roots are divided out, a non-real discriminant, or x below |
| `complex_root` | A root of a non-real number, or a size `abs(a + bi)` with no exact form |
| `complex_relation` | An inequality in a complex task |
| `log_domain` | A log of zero or a negative number, or a negative base to a fraction |
| `log_base` | A base that is not a positive number other than 1 |
| `log_bases` | Logs or powers of two bases that are not powers of one base, in one place |
| `log_constant` | A number with no exact form here: `2^(1/2)`, a product of logs, an inequality bound in `e` |
| `log_form` | More than one log or power of x in a way the reduction does not cover, or one beside x |

An irrational root that both lines share is fine: `x^2 = 2 → x^4 = 4` is `EQUIVALENT`, and so is
`x^3 = 2 → x^6 = 4`, which no line could write. Which steps refuse depends on complex roots too, because
the degree above counts them: `x^2 = 2 → x = 1` has a witness and `x^4 = 4 → x = 1` is refused, though
both lose only `±sqrt(2)`.

Multi-variable input is out of the fragment for now. Section 2 of ARCHITECTURE.md allows EQUIVALENT
or UNRELATED for multi-variable expressions, but nothing in the current scope needs them. The limits
are judgement. The 4096-bit precheck before multiplication belongs to the Lisp core, because the
oracle has no time limit to protect. Lisp counts `degree_limit` on the numerator in lowest terms.

## Other kinds of task

A problem's `kind` says how its lines are read. Each kind has its own reader, verdict and finished
form, and its own independent oracle in `oracle/semantics.py`.

- **Expressions** (`"kind": "expression"`). A line has no `=`. Two lines are compared as functions:
  `EQUIVALENT`, `UNRELATED Differ{} witness=n` at the first whole number where they differ,
  `GAINS Finite{...}` where only the new line has a value (accepted, with a note), or `LOSES`
  (rejected). A task is solved on a line in its `finished` list, read up to order.
- **Systems** (`"kind": "system"`, `"vars"` such as `"xy"`). Equations are separated by commas, in
  up to three letters, each linear. A system means its row space in reduced form. The verdict
  compares point sets and prints `System witness=(a,b)`: the first point with each free letter 0 or 1
  that lies on one side only. A line is accepted when it is a combination of line 0's equations,
  so after a contradiction `0 = 1` stands and `x = 100` does not. A task is solved on one
  `letter = number` for each letter, on the line `goal = ...` with no `goal` on the right, or on
  the choice `no solution` or `infinitely many`.
- **Complex numbers** (`"kind": "complex"`). The letter `i` is the square root of -1. A number line
  (`"form": "number"`) must keep its value and is solved in the form `a + bi`, over a number if need
  be. An equation's set is over the complex numbers, up to degree 2 once rational roots are divided
  out. Text such as `LOSES Complex{-2i} witness=-2i` is compared byte for byte with the oracle.
- **Exponents and logarithms** (`"kind": "log"`). `log2(x)`, `log(x)` for base 10, `ln(x)`, `e`
  and any exponent are read. A line reduces to ordinary algebra with the conditions its logs carry,
  and the sign charts decide it. A number with no surd form, such as `log2(5)`, is a ratio of two
  vectors of prime powers, exact and comparable. The oracle shares none of this: it evaluates the
  typed tree in 80 digits at a grid and at each crossing it finds, so only the verdict name is
  compared with it. A value task (`"form": "value"`) is solved on its `finished` list.

## Using a verdict

These rules decide what the tutor does with a verdict. They are M3 behaviour, and the corpus records
the verdicts they rely on.

- **Accept** a line if it is `EQUIVALENT` to the previous line or to line 0.
- **Caution.** A `Finite` `GAINS` with variable denominators or a root over the variable present commits
  with a caution and stays unsolved, so `x/(x - 1) = 1/(x - 1) → x = 1 → no solution` stays reachable,
  and squaring `sqrt(x + 2) = x` keeps the false answer `x = -1` until it is tested in the first line.
- **Reject** every other `GAINS`, including every `AllExcept` gain such as `2x = 6 → 0 = 0`.
- **Solved.** The line is `EQUIVALENT` to line 0 and is `x = literal`, `literal = x`, `x` against a
  literal by an inequality in either order, a range `a < x < b` of those, alternatives that are all of
  those, or the choice `no solution` or `all real numbers`. A literal here may be a
  fraction of two numbers, or a finished root: `sqrt(n)` with nothing square left in `n`, a number
  times one, a number plus or minus one, or those over a number. So `x = sqrt(12)` holds but is not
  finished, and `x = 2sqrt(3)` is.
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
