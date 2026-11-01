"""Check the rule file: its format, every rule's soundness, and that each guard is needed.

Usage: check_rules.py <rules.sexp>

Exhaustive strict evaluation over a small pool catches domain errors. SymPy adds a schema check
with the metavariables left symbolic, plus exact solution sets on sampled equation instances.
This is oracle evidence for tiers A and E only. It proves nothing, and the rule file's Lean
statements are M4's job.
"""

import itertools
import random
import re
import sys
from fractions import Fraction

import sympy

from lang import Unreadable, metas, parse_line, pattern_tree, read_forms
from semantics import X, holds, solution_set, to_sympy, value, verdict

FIELDS = (":level", ":class", ":pattern", ":replacement", ":guards", ":params", ":explanation",
          ":skills", ":mal", ":positive", ":negative")
LEVELS = ("expr", "equation")
CLASSES = ("equivalence", "implication")
GUARDS = ("literal", "nonzero-literal", "total")
PARAM_SOURCES = ("term", "coefficient", "lcd")
SKILLS = ("arithmetic", "identities", "ordering", "distribution", "like-terms", "fractions",
          "balance", "domains")
MAX_RULES = 40
MIN_RULES = 30
SAMPLE_SEED = 20261101
EQUATION_SAMPLES = 40

LITERALS = [Fraction(n) for n in ("-2", "-1", "0", "1/2", "1", "3")]
LITERAL_POOL = [("num", n) for n in LITERALS]


def line_side(text):
    return parse_line(f"{text} = 0")[1]


EXPRESSION_POOL = LITERAL_POOL + [line_side(text) for text in (
    "x", "x + 1", "x - 1", "2x", "x/2", "1/x", "1/(x - 1)", "x/(x + 1)", "(x + 1)/(x - 1)", "3 - x",
)]
SMALL_POOL = LITERAL_POOL[1:4] + [line_side(text) for text in ("x", "x + 1", "1/x", "1/(x - 1)")]
POINTS = [Fraction(n) for n in ("-2", "-1", "-1/2", "0", "1/2", "1", "2", "3")]


class Counter:
    def __init__(self):
        self.ran = 0
        self.passed = 0

    def check(self, kind, name, ok, detail=""):
        self.ran += 1
        if ok:
            self.passed += 1
        else:
            print(f"{kind}: {name} {detail}".rstrip())


def plist(items):
    return dict(zip(items[0::2], items[1::2]))


def load(path):
    with open(path, encoding="utf-8") as f:
        forms = read_forms(f.read())
    rules = []
    for form in forms:
        if form[0] != "rule":
            raise ValueError(f"not a rule: {form[0]}")
        rule = plist(form[2:])
        rule["id"] = form[1]
        rules.append(rule)
    return rules


def format_problems(rule):
    problems = [f"missing {field}" for field in FIELDS if field not in rule]
    if problems:
        return problems
    if rule[":level"] not in LEVELS:
        problems.append(f"bad level {rule[':level']}")
    if rule[":class"] not in CLASSES:
        problems.append(f"bad class {rule[':class']}")
    if rule[":mal"] != "nil":
        problems.append("a mal-rule needs published evidence, so none belong here yet")
    for guard in rule[":guards"]:
        if guard[0] not in GUARDS:
            problems.append(f"guard {guard[0]} is not on the closed list")
    pattern = pattern_tree(rule[":pattern"])
    replacement = pattern_tree(rule[":replacement"])
    params = {param[0] for param in rule[":params"]}
    for param in rule[":params"]:
        if param[1] not in PARAM_SOURCES:
            problems.append(f"parameter source {param[1]} is not on the closed list")
    if not metas(replacement) <= metas(pattern) | params:
        problems.append("replacement uses an unbound metavariable")
    for guard in rule[":guards"]:
        if guard[1] not in metas(pattern) | params:
            problems.append(f"guard on unbound {guard[1]}")
    for name in re.findall(r"\{(\?\w+)\}", rule[":explanation"]):
        if name not in metas(pattern) | params:
            problems.append(f"explanation uses unbound {name}")
    for skill in rule[":skills"]:
        if skill not in SKILLS:
            problems.append(f"unknown skill {skill}")
    if not rule[":positive"] or not rule[":negative"]:
        problems.append("needs positive and negative examples")
    return problems


def compute(tree, env):
    """Substitute bindings and work out eval nodes. None means the arithmetic has no value."""
    head = tree[0]
    if head == "meta":
        return env[tree[1]]
    if head == "eval":
        inner = compute(tree[1], env)
        result = None if inner is None else value(inner, Fraction(0))
        return None if result is None else ("num", result)
    if head in ("num", "var"):
        return tree
    children = [compute(child, env) if isinstance(child, tuple) else child for child in tree[1:]]
    if any(child is None for child in children):
        return None
    return (head, *children)


def passes(guard, tree):
    if guard == "literal":
        return tree[0] == "num"
    if guard == "nonzero-literal":
        return tree[0] == "num" and tree[1] != 0
    return is_total(tree)


def has_variable(tree):
    if tree[0] == "var":
        return True
    return tree[0] != "num" and any(has_variable(c) for c in tree[1:] if isinstance(c, tuple))


def is_total(tree):
    if tree[0] in ("num", "var"):
        return True
    if tree[0] == "div" and (has_variable(tree[2]) or value(tree[2], Fraction(0)) in (None, 0)):
        return False
    return all(is_total(child) for child in tree[1:] if isinstance(child, tuple))


def guards_hold(guards, env):
    return all(passes(name, env[target]) for name, target in guards)


def match(pattern, tree, env):
    head = pattern[0]
    if head == "meta":
        bound = env.get(pattern[1])
        if bound is None:
            env[pattern[1]] = tree
            return True
        return bound == tree
    if head == "eval":
        return compute(pattern, env) == tree
    if head != tree[0]:
        return False
    if head == "num":
        return pattern[1] == tree[1]
    return all(match(p, t, env) for p, t in zip(pattern[1:], tree[1:]))


def applies_here(rule, guards, before, after):
    env = {}
    return (match(pattern_tree(rule[":pattern"]), before, env)
            and match(pattern_tree(rule[":replacement"]), after, env)
            and guards_hold(guards, env))


def applies(rule, guards, before, after):
    """Does one use of the rule, at one place, turn before into after? No reordering."""
    if applies_here(rule, guards, before, after):
        return True
    if before[0] != after[0] or len(before) != len(after) or before[0] in ("num", "var"):
        return False
    changed = [(b, a) for b, a in zip(before[1:], after[1:]) if b != a]
    return len(changed) == 1 and isinstance(changed[0][0], tuple) and applies(rule, guards, *changed[0])


def lawful_at(rule, before, after, x):
    if rule[":level"] == "expr":
        old = value(before, x)
        new = value(after, x)
        return old == new if rule[":class"] == "equivalence" else old is None or old == new
    old = holds(before, x)
    new = holds(after, x)
    return old == new if rule[":class"] == "equivalence" else not old or new


def instances(rule, guards):
    """Every binding of the rule's metavariables from the pool that passes the guards."""
    pattern = pattern_tree(rule[":pattern"])
    replacement = pattern_tree(rule[":replacement"])
    names = sorted(metas(pattern) | metas(replacement))
    literal_only = {target for name, target in rule[":guards"] if name in ("literal", "nonzero-literal")}
    pool = EXPRESSION_POOL if len(names) <= 3 else SMALL_POOL
    choices = [LITERAL_POOL if name in literal_only else pool for name in names]
    for combination in itertools.product(*choices):
        env = dict(zip(names, combination))
        if guards_hold(guards, env):
            yield env, compute(pattern, env), compute(replacement, env)


def counterexample(rule, guards):
    for env, before, after in instances(rule, guards):
        if after is None:
            return f"{env}: replacement has no value"
        for x in POINTS:
            if not lawful_at(rule, before, after, x):
                return f"at x = {x} with {env}"
    return None


def schema_holds(rule):
    """The rule with its metavariables left symbolic. Blind to domains, which is why it is second."""
    pattern = pattern_tree(rule[":pattern"])
    replacement = pattern_tree(rule[":replacement"])
    names = sorted(metas(pattern) | metas(replacement))
    bindings = {name: sympy.Symbol(name[1:], real=True) for name in names}
    if rule[":level"] == "expr":
        return sympy.simplify(to_sympy(pattern, bindings) - to_sympy(replacement, bindings)) == 0
    old = to_sympy(pattern[1], bindings) - to_sympy(pattern[2], bindings)
    new = to_sympy(replacement[1], bindings) - to_sympy(replacement[2], bindings)
    unknown = sorted(old.free_symbols, key=str)[0]
    return all(sympy.simplify(new.subs(unknown, root)) == 0 for root in sympy.solve(old, unknown))


def equation_instances_hold(rule, generator):
    """Exact solution sets on sampled instances, for equation rules."""
    pool = list(instances(rule, [tuple(g) for g in rule[":guards"]]))
    for _, before, after in generator.sample(pool, min(EQUATION_SAMPLES, len(pool))):
        result = verdict(before, after)
        name = result["verdict"]
        if name == "OUT_OF_FRAGMENT":
            continue
        allowed = ("EQUIVALENT",) if rule[":class"] == "equivalence" else ("EQUIVALENT", "GAINS")
        if name not in allowed:
            return False
    return True


def weakened(guards, dropped):
    """The guards without one, where a nonzero literal may now be any literal."""
    out = []
    for guard in guards:
        if guard != dropped:
            out.append(guard)
        elif guard[0] == "nonzero-literal":
            out.append(("literal", guard[1]))
    return out


def step_is_lawful(rule, before_text, after_text):
    result = verdict(parse_line(before_text), parse_line(after_text))
    allowed = ("EQUIVALENT",) if rule[":class"] == "equivalence" else ("EQUIVALENT", "GAINS")
    return result["verdict"] in allowed


def check_examples(rule, guards, counter):
    name = rule["id"]
    for before_text, after_text, *_ in rule[":positive"]:
        before = parse_line(before_text)
        after = parse_line(after_text)
        counter.check("RULE EXAMPLE", f"{name}: {before_text} -> {after_text}",
                      applies(rule, guards, before, after), "does not apply")
        counter.check("RULE UNSOUND", f"{name}: {before_text} -> {after_text}",
                      step_is_lawful(rule, before_text, after_text))
    for before_text, after_text, *tag in rule[":negative"]:
        before = parse_line(before_text)
        try:
            after = parse_line(after_text)
        except Unreadable:
            after = None
        counter.check("RULE EXAMPLE", f"{name}: {before_text} -/> {after_text}",
                      after is None or not applies(rule, guards, before, after), "applies")
        if tag:
            # This negative exists because of a guard: without it the rule fires, and the step is bad.
            counter.check("RULE EXAMPLE", f"{name}: guard example {before_text}",
                          applies(rule, [g for g in guards if g[0] == "literal"], before, after),
                          "fails for a reason other than its guard")
            counter.check("GUARD NOT NEEDED", f"{name}: {before_text}",
                          not step_is_lawful(rule, before_text, after_text))


def main():
    rules = load(sys.argv[1])
    counter = Counter()
    generator = random.Random(SAMPLE_SEED)
    counter.check("RULE FORMAT", "rule count", MIN_RULES <= len(rules) <= MAX_RULES, f"{len(rules)}")
    ids = [rule.get("id") for rule in rules]
    counter.check("RULE FORMAT", "unique ids", len(ids) == len(set(ids)))
    for rule in rules:
        problems = format_problems(rule)
        counter.check("RULE FORMAT", rule["id"], not problems, "; ".join(problems))
        if problems:
            continue
        guards = [tuple(g) for g in rule[":guards"]]
        found = counterexample(rule, guards)
        counter.check("RULE UNSOUND", rule["id"], found is None, found or "")
        counter.check("RULE UNSOUND", f"{rule['id']} schema", schema_holds(rule))
        if rule[":level"] == "equation":
            counter.check("RULE UNSOUND", f"{rule['id']} solution sets",
                          equation_instances_hold(rule, generator))
        for guard in guards:
            if guard[0] != "literal":
                found = counterexample(rule, weakened(guards, guard))
                counter.check("GUARD NOT NEEDED", f"{rule['id']} {guard[0]} {guard[1]}", found is not None)
        check_examples(rule, guards, counter)
    print(f"rules {len(rules)}; sympy {sympy.__version__}")
    print(f"COUNT rules ran={counter.ran} passed={counter.passed}")
    sys.exit(0 if counter.ran == counter.passed else 1)


main()
