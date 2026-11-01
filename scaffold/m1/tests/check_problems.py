"""Independent check of the M1 content, with no code shared with the Lisp reducer.

SymPy solves every authored line and fixture, and Fraction re-substitutes every committed
counterexample. Its expected classes are the ones the Lisp tests read. This is not Tier D or
Tier E evidence: it covers authored content and one fixture file.

Usage: check_problems.py <problems.json> <fixtures.json>
"""

import json
import re
import sys
from fractions import Fraction

import sympy


def translate(text, number):
    """Rewrite a typed line side as Python: exact numbers and explicit products."""
    spaced = re.sub(r"\s+", "", text)
    explicit = re.sub(r"(?<=[0-9a-z)])(?=[a-z(])", "*", spaced)
    return re.sub(r"\d*\.?\d+", lambda m: f"{number}('{m.group(0)}')", explicit)


def sides(line, var, number, value):
    left, right = line.split("=")
    scope = {"__builtins__": {}, number.__name__: number, var: value}
    number_name = number.__name__
    return (
        eval(translate(left, number_name), scope),
        eval(translate(right, number_name), scope),
    )


def solutions(line, var):
    symbol = sympy.Symbol(var, real=True)
    left, right = sides(line, var, sympy.Rational, symbol)
    return sympy.solveset(sympy.Eq(left, right), symbol, sympy.S.Reals)


def holds(line, var, value):
    left, right = sides(line, var, Fraction, value)
    return left == right


class Counter:
    def __init__(self):
        self.ran = 0
        self.passed = 0

    def check(self, name, ok):
        self.ran += 1
        if ok:
            self.passed += 1
        else:
            print(f"CHECKER MISMATCH: {name}")


def check_problems(problems, counter):
    for problem in problems:
        var = problem["var"]
        lines = [problem["start"]] + [step["line"] for step in problem["steps"]]
        first = solutions(lines[0], var)
        for line in lines[1:]:
            counter.check(f"{problem['id']}: {line}", solutions(line, var) == first)
        claim = problem.get("claim")
        if claim == "none":
            counter.check(f"{problem['id']}: no solution", first == sympy.S.EmptySet)
        elif claim == "all":
            counter.check(f"{problem['id']}: all reals", first == sympy.S.Reals)
        else:
            counter.check(f"{problem['id']}: one root", len(first) == 1)


def check_fixtures(fixtures, counter):
    for fixture in fixtures:
        expect = fixture["expect"]
        if expect not in ("equivalent", "different"):
            continue
        var = "x"
        previous, text = fixture["previous"], fixture["text"]
        same = solutions(previous, var) == solutions(text, var)
        counter.check(fixture["name"], same == (expect == "equivalent"))
        if expect == "different":
            value = Fraction(fixture["witness"])
            counter.check(
                f"{fixture['name']}: witness separates the lines",
                holds(previous, var, value) != holds(text, var, value),
            )


def main():
    with open(sys.argv[1], encoding="utf-8") as f:
        problems = json.load(f)
    with open(sys.argv[2], encoding="utf-8") as f:
        fixtures = json.load(f)
    counter = Counter()
    check_problems(problems, counter)
    check_fixtures(fixtures, counter)
    print(f"sympy {sympy.__version__}")
    print(f"COUNT checker ran={counter.ran} passed={counter.passed}")
    sys.exit(0 if counter.ran == counter.passed else 1)


main()
