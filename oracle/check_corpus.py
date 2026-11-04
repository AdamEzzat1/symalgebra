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

import sympy

from lang import Unreadable, parse_expression_line, parse_line, parse_system, read_forms
from semantics import (NO_POINT, chart_line, complex_lines_text, complex_numbers_text, log_lines_text, log_values_text, expression_verdict, fits, holds, holds_almost_everywhere, holds_nowhere, real_members,
                       solution_set, system_points, system_rows, system_text, value, verdict)


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


def simple_radical(tree):
    if tree[0] != "sqrt" or tree[1][0] != "num" or tree[1][1].denominator != 1 or tree[1][1] < 2:
        return False
    return sympy.sqrt(int(tree[1][1])).is_Pow and sympy.sqrt(int(tree[1][1])).base == int(tree[1][1])


def radical_term(tree):
    if simple_radical(tree):
        return True
    if tree[0] == "neg":
        return radical_term(tree[1])
    if tree[0] == "mul":
        return tree[1][0] == "num" and radical_term(tree[2])
    if tree[0] == "div":
        return radical_term(tree[1]) and tree[2][0] == "num"
    return False


def surd_literal(tree):
    if radical_term(tree):
        return True
    if tree[0] == "div":
        return surd_literal(tree[1]) and tree[2][0] == "num"
    if tree[0] in ("add", "sub") and is_literal(tree[1]) and radical_term(tree[2]):
        return True
    return tree[0] == "add" and radical_term(tree[1]) and is_literal(tree[2])


def is_answer(tree):
    return is_literal(tree) or surd_literal(tree)


def solved_form(line):
    if line[0] in ("or", "and"):
        return all(solved_form(item) for item in line[1:])
    left, right = line[1], line[2]
    return (left[0] == "var" and is_answer(right)) or (is_answer(left) and right[0] == "var")


def line_side(text):
    return parse_line(f"{text} = 0")[1]


def check_expression(solution, rule_ids, counter):
    name = solution["id"]
    lines = [solution["start"]] + [step["line"] for step in solution["steps"]]
    trees = [parse_expression_line(text) for text in lines]
    for step, before, after in zip(solution["steps"], trees, trees[1:]):
        got = expression_verdict(before, after)
        counter.check(f"{name}: {step['line']}", same_expression(got), f"got {got}")
        unknown = [rule for rule in step["rules"] if rule not in rule_ids]
        counter.check(f"{name}: rule labels on {step['line']}", (step["rules"] or step.get("why")) and not unknown,
                      f"{unknown}")
    counter.check(f"{name}: same as the start", same_expression(expression_verdict(trees[0], trees[-1])))
    counter.check(f"{name}: ends on a finished form", lines[-1] in solution["finished"])
    for form in solution["finished"]:
        counter.check(f"{name}: {form} is the answer",
                      same_expression(expression_verdict(trees[0], parse_expression_line(form))))


def same_expression(got):
    return got["verdict"] == "EQUIVALENT" or (got["verdict"] == "GAINS" and got["shape"] == "Finite")


def check_system(solution, counter):
    name = solution["id"]
    names = solution["vars"]
    start = parse_system(solution["start"], names)
    rows = system_rows(start)
    empty = NO_POINT in rows
    for step in solution["steps"]:
        line = parse_system(step["line"], names)
        got = system_text(start, line, len(names))
        counter.check(f"{name}: {step['line']}", got == "EQUIVALENT" or got.startswith("GAINS"), f"got {got}")
        counter.check(f"{name}: words on {step['line']}", bool(step.get("why")))
    answer = solution["answer"]
    if answer == "none":
        counter.check(f"{name}: no solution", empty)
    elif answer == "all":
        counter.check(f"{name}: many solutions", not empty and len(rows) < len(names))
    else:
        last = parse_system(solution["steps"][-1]["line"], names)
        counter.check(f"{name}: answer", system_text(start, parse_system(answer, names), len(names)) == "EQUIVALENT")
        counter.check(f"{name}: last line", system_text(start, last, len(names)) == "EQUIVALENT")


def check_complex(solution, counter):
    name = solution["id"]
    lines = [solution["start"]] + [step["line"] for step in solution["steps"]]
    number = solution.get("form") == "number"
    read = parse_expression_line if number else parse_line
    compare = complex_numbers_text if number else complex_lines_text
    start = read(lines[0], imaginary=True)
    for step, line in zip(solution["steps"], lines[1:]):
        got = compare(start, read(line, imaginary=True))
        counter.check(f"{name}: {line}", got == "EQUIVALENT", f"got {got}")
        counter.check(f"{name}: words on {line}", bool(step.get("why")))


def check_log(solution, counter):
    name = solution["id"]
    lines = [solution["start"]] + [step["line"] for step in solution["steps"]]
    value = solution.get("form") == "value"
    read = parse_expression_line if value else parse_line
    compare = log_values_text if value else log_lines_text
    start = read(lines[0], logs=True)
    for step, line in zip(solution["steps"], lines[1:]):
        got = compare(start, read(line, logs=True))
        counter.check(f"{name}: {line}", got in ("EQUIVALENT", "GAINS"), f"got {got}")
        counter.check(f"{name}: words on {line}", bool(step.get("why")))
    if value:
        counter.check(f"{name}: finished", lines[-1] in solution["finished"])
    elif solution["answer"] == "none":
        counter.check(f"{name}: no solution", log_lines_text(start, read("0 = 1", logs=True)) == "EQUIVALENT")
    else:
        got = log_lines_text(start, read(lines[-1], logs=True))
        counter.check(f"{name}: last line", got == "EQUIVALENT", f"got {got}")


def check_solution(solution, rule_ids, counter):
    if solution.get("kind") == "log":
        check_log(solution, counter)
        return
    if solution.get("kind") == "complex":
        check_complex(solution, counter)
        return
    if "finished" in solution:
        check_expression(solution, rule_ids, counter)
        return
    if "vars" in solution:
        check_system(solution, counter)
        return
    name = solution["id"]
    lines = [solution["start"]] + [step["line"] for step in solution["steps"]]
    trees = [parse_line(text) for text in lines]
    for step, before, after in zip(solution["steps"], trees, trees[1:]):
        expected = step.get("verdict", "EQUIVALENT")
        got = verdict(before, after)["verdict"]
        counter.check(f"{name}: {step['line']}", got == expected, f"got {got}, expected {expected}")
        unknown = [rule for rule in step["rules"] if rule not in rule_ids]
        counter.check(f"{name}: rule labels on {step['line']}", (step["rules"] or step.get("why")) and not unknown,
                      f"{unknown}")
    answer = solution["answer"]
    if answer == "none":
        counter.check(f"{name}: no solution", holds_nowhere(trees[0]))
    elif answer == "all":
        counter.check(f"{name}: all allowed values", holds_almost_everywhere(trees[0]))
    elif "<" in answer or ">" in answer:
        counter.check(f"{name}: answer holds", verdict(trees[0], parse_line(answer))["verdict"] == "EQUIVALENT")
        counter.check(f"{name}: ends solved",
                      solved_form(trees[-1]) and verdict(trees[-1], parse_line(answer))["verdict"] == "EQUIVALENT")
    else:
        roots = [value(line_side(text), Fraction(0)) for text in answer.split(",")]
        shape, values = ("finite", []) if chart_line(trees[0]) else solution_set(trees[0])
        counter.check(f"{name}: answer holds", all(holds(trees[0], root) for root in roots))
        counter.check(f"{name}: only answer", chart_line(trees[0])
                      or (shape == "finite" and len(real_members(values)) == len(roots)))
        counter.check(f"{name}: ends solved",
                      solved_form(trees[-1]) and all(holds(trees[-1], root) for root in roots))
        counter.check(f"{name}: last line matches", verdict(trees[0], trees[-1])["verdict"] == "EQUIVALENT")


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
