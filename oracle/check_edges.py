"""Tier E: SymPy re-checks every rule edge the Lisp core walked, with no Lisp code involved.

Usage: check_edges.py <edges.jsonl>

An equivalence edge must keep the solution set. An implication edge may only gain roots.
"""

import json
import sys
from fractions import Fraction

from lang import read_forms
from semantics import verdict

HEADS = {"+": "add", "*": "mul", "/": "div", "neg": "neg", "=": "eq"}


def tree(form):
    """A flat S-expression as a binary tree."""
    if isinstance(form, str):
        return ("var",) if form == "x" else ("num", Fraction(form))
    head = form[0]
    if head == "^":
        return ("pow", tree(form[1]), int(form[2]))
    items = [tree(item) for item in form[1:]]
    if head in ("+", "*"):
        built = items[0]
        for item in items[1:]:
            built = (HEADS[head], built, item)
        return built
    if head == "or":
        return ("or", *items)
    return (HEADS[head], *items)


def main():
    ran = 0
    passed = 0
    by_rule = {}
    with open(sys.argv[1], encoding="utf-8") as f:
        for text in f:
            edge = json.loads(text)
            before = tree(read_forms(edge["before"])[0])
            after = tree(read_forms(edge["after"])[0])
            name = verdict(before, after)["verdict"]
            allowed = ("EQUIVALENT",) if edge["class"] == "equivalence" else ("EQUIVALENT", "GAINS")
            ran += 1
            by_rule[edge["rule"]] = by_rule.get(edge["rule"], 0) + 1
            if name in allowed:
                passed += 1
            else:
                print(f"UNSOUND EDGE: {edge['rule']} {edge['before']} -> {edge['after']} is {name}")
    print(f"{len(by_rule)} rules seen; least-used: {sorted(by_rule.items(), key=lambda kv: kv[1])[:5]}")
    print(f"COUNT edges ran={ran} passed={passed}")
    sys.exit(0 if ran == passed else 1)


if __name__ == "__main__":
    main()
