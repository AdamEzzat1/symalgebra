"""The meaning of a line, as defined in docs/SEMANTICS.md.

Strict evaluation uses Fraction and treats a zero divisor as having no value. Solution sets use
SymPy, but domains always come from the typed tree, because SymPy turns x/x into 1 on sight.
"""

from fractions import Fraction

import sympy

from lang import Unreadable

X = sympy.Symbol("x", real=True)
MAX_DEGREE = 8


def value(tree, x):
    """The value of an expression at x, or None where it has none."""
    head = tree[0]
    if head == "num":
        return tree[1]
    if head == "var":
        return x
    if head == "neg":
        inner = value(tree[1], x)
        return None if inner is None else -inner
    if head == "pow":
        inner = value(tree[1], x)
        return None if inner is None else inner ** tree[2]
    left = value(tree[1], x)
    right = value(tree[2], x)
    if left is None or right is None:
        return None
    if head == "add":
        return left + right
    if head == "sub":
        return left - right
    if head == "mul":
        return left * right
    if head == "div":
        return None if right == 0 else left / right
    raise ValueError(head)


def holds(equation, x):
    if equation[0] == "or":
        return any(holds(item, x) for item in equation[1:])
    left = value(equation[1], x)
    right = value(equation[2], x)
    return left is not None and right is not None and left == right


def to_sympy(tree, bindings=None):
    head = tree[0]
    if head == "num":
        return sympy.Rational(tree[1].numerator, tree[1].denominator)
    if head == "var":
        return X
    if head == "meta":
        return bindings[tree[1]]
    if head in ("neg", "eval"):
        inner = to_sympy(tree[1], bindings)
        return -inner if head == "neg" else inner
    if head == "pow":
        return to_sympy(tree[1], bindings) ** tree[2]
    left = to_sympy(tree[1], bindings)
    right = to_sympy(tree[2], bindings)
    if head == "add":
        return left + right
    if head == "sub":
        return left - right
    if head == "mul":
        return left * right
    if head == "div":
        return left / right
    raise ValueError(head)


def denominators(tree):
    head = tree[0]
    if head in ("num", "var"):
        return []
    if head in ("neg", "pow"):
        return denominators(tree[1])
    found = denominators(tree[1]) + denominators(tree[2])
    if head == "div":
        found.append(tree[2])
    return found


def real_roots(expression):
    return set(sympy.Poly(expression, X).real_roots()) if expression.has(X) else set()


def domain_zeros(equation):
    """Every value removed from the domain, read from the typed tree."""
    zeros = set()
    for denominator in denominators(equation):
        expression = to_sympy(denominator)
        if expression.has(sympy.zoo, sympy.nan):
            raise Unreadable("empty_domain")
        top = sympy.expand(sympy.fraction(sympy.together(expression))[0])
        if top == 0:
            raise Unreadable("empty_domain")
        zeros |= real_roots(top)
    return zeros


def join(a, b):
    """a or b, for sets of either shape."""
    a_shape, a_set = a
    b_shape, b_set = b
    if a_shape == "finite" and b_shape == "finite":
        return ("finite", a_set | b_set)
    if a_shape == "finite":
        return ("allexcept", b_set - a_set)
    if b_shape == "finite":
        return ("allexcept", a_set - b_set)
    return ("allexcept", a_set & b_set)


def solution_set(line):
    """The set of an equation, or of alternatives taken together."""
    if line[0] == "or":
        out = equation_set(line[1])
        for item in line[2:]:
            out = join(out, equation_set(item))
        return out
    return equation_set(line)


def equation_set(equation):
    """("finite", F) or ("allexcept", F). Sets only: multiplicity is not counted."""
    zeros = domain_zeros(equation)
    difference = to_sympy(equation[1]) - to_sympy(equation[2])
    if difference.has(sympy.zoo, sympy.nan):
        raise Unreadable("empty_domain")
    top = sympy.expand(sympy.fraction(sympy.together(difference))[0])
    if top == 0:
        return ("allexcept", frozenset(zeros))
    if top.has(X) and sympy.degree(top, X) > MAX_DEGREE:
        raise Unreadable("degree_limit")
    return ("finite", frozenset(real_roots(top) - zeros))


def subtract(a, b):
    """a \\ b, for sets of either shape."""
    a_shape, a_set = a
    b_shape, b_set = b
    if a_shape == "finite" and b_shape == "finite":
        return ("finite", a_set - b_set)
    if a_shape == "finite":
        return ("finite", a_set & b_set)
    if b_shape == "finite":
        return ("allexcept", a_set | b_set)
    return ("finite", b_set - a_set)


def empty(shape_set):
    return shape_set == ("finite", frozenset())


def rational_or_refuse(shape_set):
    for root in shape_set[1]:
        if not root.is_rational:
            raise Unreadable("irrational_root")


def member_outside(difference):
    """One rational value in a difference set."""
    shape, values = difference
    if shape == "finite":
        ordered = sorted(values, key=lambda v: Fraction(int(v.p), int(v.q)))
        root = ordered[0]
        return Fraction(int(root.p), int(root.q))
    candidate = Fraction(0)
    taken = {Fraction(int(v.p), int(v.q)) for v in values}
    while candidate in taken:
        candidate += 1
    return candidate


def text_of(root):
    return str(root)


def verdict(previous, line):
    """The verdict on a step, with its payload and one exact witness."""
    try:
        before = solution_set(previous)
        after = solution_set(line)
        lost = subtract(before, after)
        gained = subtract(after, before)
        if not empty(lost):
            rational_or_refuse(lost)
        if not empty(gained):
            rational_or_refuse(gained)
    except Unreadable as refused:
        return {"verdict": "OUT_OF_FRAGMENT", "reason": refused.reason}
    if empty(lost) and empty(gained):
        return {"verdict": "EQUIVALENT"}
    if empty(lost):
        name, difference = "GAINS", gained
    elif empty(gained):
        name, difference = "LOSES", lost
    else:
        name, difference = "UNRELATED", lost
    return {
        "verdict": name,
        "shape": "Finite" if difference[0] == "finite" else "AllExcept",
        "set": sorted(text_of(root) for root in difference[1]),
        "witness": member_outside(difference),
    }
