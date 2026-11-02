"""Check the golden corpus against the oracle's semantics.

Usage: check_corpus.py <rules.sexp> <solutions.json> <verdicts.json>

Solutions: every line has its stated verdict against the line before, ends in a solved form, and
names only rules that exist. Whether those rule labels really describe each step needs the AC
matcher, so that check waits for M3. Verdicts: every case has its stated verdict and payload,
and each witness is re-substituted with Fraction.
"""

import json
import sys
from fractions import Fraction

from lang import Unreadable, parse_line, read_forms
from semantics import holds, solution_set, verdict


class Counter:
    def __init__(self):
        self.ran = 0
        self.passed = 0

    def check(self, name, ok, detail=""):
        self.ran += 1
        if ok:
            self.passed += 1
        else:
            print(f"CORPUS MISMATCH: {name} {detail}".rstrip())


def is_literal(tree):
    if tree[0] == "div":
        return tree[1][0] == "num" and tree[2][0] == "num"
    return tree[0] == "num"


def solved_form(line):
    if line[0] == "or":
        return all(solved_form(item) for item in line[1:])
    left, right = line[1], line[2]
    return (left[0] == "var" and is_literal(right)) or (is_literal(left) and right[0] == "var")


def check_solution(solution, rule_ids, counter):
    name = solution["id"]
    lines = [solution["start"]] + [step["line"] for step in solution["steps"]]
    trees = [parse_line(text) for text in lines]
    for step, before, after in zip(solution["steps"], trees, trees[1:]):
        expected = step.get("verdict", "EQUIVALENT")
        got = verdict(before, after)["verdict"]
        counter.check(f"{name}: {step['line']}", got == expected, f"got {got}, expected {expected}")
        unknown = [rule for rule in step["rules"] if rule not in rule_ids]
        counter.check(f"{name}: rule labels on {step['line']}", step["rules"] and not unknown, f"{unknown}")
    shape, values = solution_set(trees[0])
    answer = solution["answer"]
    if answer == "none":
        counter.check(f"{name}: no solution", shape == "finite" and not values)
    elif answer == "all":
        counter.check(f"{name}: all allowed values", shape == "allexcept")
    else:
        roots = [Fraction(text) for text in answer.split(",")]
        counter.check(f"{name}: answer holds", all(holds(trees[0], root) for root in roots))
        counter.check(f"{name}: only answer", shape == "finite" and len(values) == len(roots))
        counter.check(f"{name}: ends solved",
                      solved_form(trees[-1]) and all(holds(trees[-1], root) for root in roots))


def check_case(case, counter):
    name = case["name"]
    try:
        previous = parse_line(case["previous"])
        line = parse_line(case["line"])
    except Unreadable as refused:
        got = {"verdict": "OUT_OF_FRAGMENT", "reason": refused.reason}
    else:
        got = verdict(previous, line)
    counter.check(name, got["verdict"] == case["verdict"], f"got {got}")
    for field in ("reason", "shape", "set"):
        if field in case:
            counter.check(f"{name}: {field}", got.get(field) == case[field], f"got {got.get(field)}")
    if "witness" in got:
        witness = got["witness"]
        counter.check(f"{name}: witness separates the lines",
                      holds(previous, witness) != holds(line, witness))


def main():
    with open(sys.argv[1], encoding="utf-8") as f:
        rule_ids = {form[1] for form in read_forms(f.read())}
    with open(sys.argv[2], encoding="utf-8") as f:
        solutions = json.load(f)
    with open(sys.argv[3], encoding="utf-8") as f:
        cases = json.load(f)
    counter = Counter()
    for solution in solutions:
        check_solution(solution, rule_ids, counter)
    for case in cases:
        check_case(case, counter)
    areas = sorted({solution["area"] for solution in solutions})
    print(f"solutions {len(solutions)} in {', '.join(areas)}; verdict cases {len(cases)}")
    print(f"COUNT corpus ran={counter.ran} passed={counter.passed}")
    sys.exit(0 if counter.ran == counter.passed else 1)


main()
