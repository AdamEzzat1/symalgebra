# Rule format

Every rule lives once, in [rules/rules.sexp](../rules/rules.sexp). Lisp tables, Prolog facts and
Lean statements are generated from that file at M3, M4 and M5, and no rule is ever copied by hand.
The file is S-expressions because the Lisp reader can load it unchanged.

## Fields

| Field | Meaning |
|---|---|
| `id` | Unique name, used by the corpus and explanations |
| `:level` | `expr` rewrites one subexpression. `equation` rewrites a whole line |
| `:class` | `equivalence` or `implication`, defined below |
| `:pattern` | The tree the rule matches |
| `:replacement` | The tree it produces |
| `:guards` | Conditions from the closed list below |
| `:params` | Metavariables that appear only in the replacement, each with a closed source |
| `:explanation` | Template. `{?a}` shows that metavariable's matched text |
| `:skills` | Tags from a closed list: arithmetic, identities, ordering, distribution, like-terms, fractions, balance, domains, quadratics, radicals, polynomials |
| `:mal` | `nil` for every rule here. A mal-rule needs published evidence or real observation (M5) |
| `:positive` | `(before after)` line pairs where one use of the rule gives exactly `after` |
| `:negative` | Line pairs the rule must not produce. Adding `guard` means only the guard stops it, and the step really is bad |

In patterns, `?a` is a metavariable and a repeated name must match the same tree. `(neg ?a)` is unary
minus. `(eval (+ ?m ?n))` computes exact arithmetic on literals. Numbers match literally. `(rel ?a ?b)`
stands for `<` or `<=`, and for the same one everywhere in the rule.

## Classes

Here `ev` is strict evaluation: a zero divisor has no value, and that absence spreads upward.

| Class | `expr` law, for all x | `equation` law |
|---|---|---|
| `equivalence` | `ev(pattern) = ev(replacement)`, including both having no value | `Sol(before) = Sol(after)` |
| `implication` | If `ev(pattern)` has value v, so does `ev(replacement)` | `Sol(before) ⊆ Sol(after)` |

An implication rule may gain a root, so it never makes a step valid on its own. The verdict comes
from meaning, and a gained root is handled as [SEMANTICS.md](SEMANTICS.md) describes.

## Closed guard list

| Guard | Holds when |
|---|---|
| `(literal ?m)` | `?m` is a number |
| `(nonzero-literal ?n)` | `?n` is a number other than 0 |
| `(total ?a)` | `?a` has a value everywhere: every denominator in it is a nonzero number |
| `(factors ?m ?n ?s ?p)` | The literals `?m` and `?n` add to `?s` and multiply to `?p` |
| `(square-of ?m ?p)` | The literal `?m` squared is `?p` |
| `(cube-of ?m ?p)` | The literal `?m` cubed is `?p` |
| `(positive-literal ?p)` | `?p` is a number above 0 |
| `(positive-number ?p)`, `(negative-number ?p)` | `?p` is a number with that sign. These are semantic, so each must be shown to be needed |
| `(real-discriminant ?a ?b ?c)` | `?b^2 - 4 * ?a * ?c` is not negative |
| `(half-square ?s ?p)` | Half of `?s`, squared, is `?p` |
| `(split-root ?m ?k ?p)` | `?p` is `?m` squared times `?k`, for whole `?m` above 0 and whole `?k` above 1 |
| `(splits ?p ?q ?a ?b ?c)` | `(?p x + ?q)(?a/?p x + ?c/?q)` has coefficients `?a`, `?b`, `?c`, in whole numbers, for `?p` above 0 |
| `(common-factor ?n ?c ...)` | Whole `?n` above 1 divides each of the others |

`literal`, `positive-literal` and `real-discriminant` are type guards: without them the line would have
no value to compare, not a wrong one. The others are semantic, and the checker requires each to be
necessary: with it removed, it must find a real counterexample. Parameter sources are `term`, `coefficient`,
`lcd` and `pair`, the divisors of a line's integers with both signs. Adding to any closed list is a
design change, not a data change.

## How the matcher reads a line

Rules match the `flat` view: sums and products are n-ary and sorted, a difference is a sum with a
negated term, and `-3x` and `-1x` are written one way. Division stays, so no denominator is lost. On
top of that, a matched line may read `x` as `1 * x`, `-x` as `-1 * x`, `a^2` as `a * a`, `-a` in a
product as `-1 * a`, and, for the two
cancelling rules only, `(x/3) * 6` as `(x * 6)/3` and `6/4` as `(3 * 2)/(2 * 2)`. A result drops a `0`
from a sum or a `1` from a product, and writes `1x` as `x` and `a/1` as `a`. These are readings of the
same rule, so they add no rules. Every edge they produce is checked by meaning. Alternatives are a
sorted set, a repeated one counts once, and rules apply inside each alternative.

## Rules left out

The brief capped the set at 40, and the owner's rulings of 2026-11-01 raised that to 50, then 65, then
150 for the rest of algebra. Left out, all valid: `a - 0 → a`, `a / 1 → a`, `-(-a) → a`, and multiplying roots
as in `sqrt(2) * sqrt(3) → sqrt(6)`. A student using one is accepted as "valid, method unnamed", never
marked wrong.
