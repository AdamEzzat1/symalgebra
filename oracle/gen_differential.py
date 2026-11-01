"""Tier D fixture: seeded line pairs with the oracle's verdict as exact text.

Usage: gen_differential.py <output>          writes the fixture
       gen_differential.py <output> --check  fails if the fixture is stale

The Lisp core must reproduce every `expected` string byte for byte.
"""

import json
import random
import sys
from fractions import Fraction
from pathlib import Path

from lang import Unreadable, parse_line
from semantics import verdict

SEED = 20261101
PER_FAMILY = 150
GARBLE_ALPHABET = ["x", "1", "2", "3", "0", ".5", "+", "-", "*", "/", "^", "(", ")", "=", " ", "y"]


def small(r, low=-9, high=9):
    return r.randint(low, high)


def nonzero(r):
    return r.choice([-5, -4, -3, -2, -1, 1, 2, 3, 4, 5, 6])


def signed(n):
    return f"+ {n}" if n >= 0 else f"- {-n}"


def linear(r):
    a, b, c, d = nonzero(r), small(r), nonzero(r), small(r)
    return f"{a}x {signed(b)} = {c}x {signed(d)}"


def distribution(r):
    a, b, c, d = nonzero(r), small(r), nonzero(r), small(r)
    return f"{a}(x {signed(b)}) = {c}(x {signed(d)}) {signed(small(r))}"


def fraction(r):
    a, b, c = r.randint(2, 9), r.randint(2, 9), small(r)
    return f"x/{a} + x/{b} = {c}"


def rational(r):
    a, b, c, d = small(r), small(r), nonzero(r), nonzero(r)
    return f"{c}/(x {signed(a)}) = {d}/(x {signed(b)})"


def cancelling(r):
    a, b = small(r), small(r)
    return f"(x {signed(a)})(x {signed(b)})/(x {signed(a)}) = {nonzero(r)}"


def quadratic(r):
    a, b, c = nonzero(r), small(r), small(r)
    return f"{a}x^2 {signed(b)}x = {c}"


def power(r):
    return f"x^{r.randint(1, 6)} = {small(r)}"


def garbled(r):
    return "".join(r.choice(GARBLE_ALPHABET) for _ in range(r.randint(1, 12)))


FAMILIES = (linear, distribution, fraction, rational, cancelling, quadratic, power, garbled)


def partner(r, family, line):
    """A second line: often a real step from the first, sometimes something else."""
    left, _, right = line.partition("=")
    roll = r.random()
    if roll < 0.2:
        return f"{right.strip()} = {left.strip()}"
    if roll < 0.4:
        k = nonzero(r)
        return f"({left.strip()}) * {k} = ({right.strip()}) * {k}"
    if roll < 0.5:
        k = small(r)
        return f"{left.strip()} + {k} = {right.strip()} + {k}"
    if roll < 0.6:
        return f"({left.strip()}) * x = ({right.strip()}) * x"
    if roll < 0.7:
        return f"({left.strip()})^2 = ({right.strip()})^2"
    if roll < 0.8:
        return f"{left.strip()} + {nonzero(r)} = {right.strip()}"
    if roll < 0.9:
        return f"x = {Fraction(small(r), r.randint(1, 4))}"
    return family(r)


def exact_text(got):
    name = got["verdict"]
    if name == "EQUIVALENT":
        return name
    if name == "OUT_OF_FRAGMENT":
        return f"{name} {got['reason']}"
    members = ",".join(str(v) for v in sorted(Fraction(text) for text in got["set"]))
    return f"{name} {got['shape']}{{{members}}} witness={got['witness']}"


def expected(previous, line):
    try:
        before = parse_line(previous)
        after = parse_line(line)
    except Unreadable as refused:
        return f"OUT_OF_FRAGMENT {refused.reason}"
    return exact_text(verdict(before, after))


def build():
    r = random.Random(SEED)
    cases = []
    for family in FAMILIES:
        for _ in range(PER_FAMILY):
            previous = family(r)
            line = partner(r, family, previous)
            cases.append({"previous": previous, "line": line, "expected": expected(previous, line)})
    return cases


def main():
    output = Path(sys.argv[1])
    text = json.dumps(build(), indent=0, ensure_ascii=True) + "\n"
    if len(sys.argv) > 2:
        if not output.exists() or output.read_text(encoding="utf-8") != text:
            print(f"DIFFERENTIAL FIXTURE STALE: {output}")
            sys.exit(1)
        print("COUNT differential-fixture ran=1 passed=1")
    else:
        output.write_text(text, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
