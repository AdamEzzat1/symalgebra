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
| `:skills` | Tags from a closed list: arithmetic, identities, ordering, distribution, like-terms, fractions, balance, domains |
| `:mal` | `nil` for every rule here. A mal-rule needs published evidence or real observation (M5) |
| `:positive` | `(before after)` line pairs where one use of the rule gives exactly `after` |
| `:negative` | Line pairs the rule must not produce. Adding `guard` means only the guard stops it, and the step really is bad |

In patterns, `?a` is a metavariable and a repeated name must match the same tree. `(neg ?a)` is unary
minus. `(eval (+ ?m ?n))` computes exact arithmetic on literals. Numbers match literally.

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

`literal` is a type guard. `nonzero-literal` and `total` are semantic, and the checker requires each
to be necessary: with it removed, it must find a real counterexample. Parameter sources are `term`,
`coefficient` and `lcd`. Adding to any closed list is a design change, not a data change.

## Rules left out

The brief caps the set at 40. Left out, all valid: `a - 0 → a`, `a / 1 → a`, `-(-a) → a`, and factoring
`ab + ac → a(b + c)`. A student using one is accepted as "valid, method unnamed", never marked wrong.
