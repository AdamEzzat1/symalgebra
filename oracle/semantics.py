"""The meaning of a line, as defined in docs/SEMANTICS.md.

Strict evaluation uses Fraction and treats a zero divisor as having no value. Solution sets use
SymPy, but domains always come from the typed tree, because SymPy turns x/x into 1 on sight. Numbers
with a square root in them are SymPy numbers, expanded after each step so equal values compare equal.
Sets hold complex roots as well as real ones, because which steps are refused depends on them.
"""

from fractions import Fraction
import itertools

import mpmath
import sympy

from lang import Unreadable

X = sympy.Symbol("x", real=True)
MAX_DEGREE = 8
MAX_ABS = 3
MAX_RADICALS = 3
RELATIONS = ("lt", "le", "gt", "ge")


def tidy(number):
    """A number in one written form: a Fraction, or an expanded SymPy number."""
    if isinstance(number, sympy.Basic):
        expanded = sympy.expand(sympy.radsimp(number))
        if expanded.is_Rational:
            return Fraction(int(expanded.p), int(expanded.q))
        return expanded
    return number


def radical(inner, x):
    """The square root of a value, or None where it has none. Refusal is for the set functions."""
    number = value(inner, x)
    if number is None or (isinstance(number, sympy.Basic) and not contains_variable(inner)):
        return None
    if isinstance(number, sympy.Basic):
        return None if sign_of(number) < 0 else sympy.sqrtdenest(sympy.sqrt(number))
    if number < 0:
        return None
    return tidy(sympy.sqrt(sympy.Rational(number.numerator, number.denominator)))


def sign_of(number):
    """The sign of a number, read to 100 digits. Test code only: nothing this small arises here."""
    if not isinstance(number, sympy.Basic):
        return (number > 0) - (number < 0)
    near = sympy.N(number, 100)
    return 0 if abs(near) < sympy.Float("1e-90") else (1 if near > 0 else -1)


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
        return None if inner is None else tidy(inner ** tree[2])
    if head == "sqrt":
        return radical(tree[1], x)
    if head == "abs":
        inner = value(tree[1], x)
        return None if inner is None else tidy(abs(inner))
    left = value(tree[1], x)
    right = value(tree[2], x)
    if left is None or right is None:
        return None
    if head == "add":
        return tidy(left + right)
    if head == "sub":
        return tidy(left - right)
    if head == "mul":
        return tidy(left * right)
    if head == "div":
        return None if right == 0 else tidy(left / right)
    raise ValueError(head)


def below(left, right):
    return bool(tidy(left - right) < 0)


def holds(equation, x):
    head = equation[0]
    if head == "or":
        return any(holds(item, x) for item in equation[1:])
    if head == "and":
        return all(holds(item, x) for item in equation[1:])
    left = value(equation[1], x)
    right = value(equation[2], x)
    if left is None or right is None:
        return False
    if holds_variable_radical(equation):
        sign = sign_of(left - right)
        return {"lt": sign < 0, "le": sign <= 0, "gt": sign > 0, "ge": sign >= 0, "eq": sign == 0}[head]
    if head == "lt":
        return below(left, right)
    if head == "le":
        return not below(right, left)
    if head == "gt":
        return below(right, left)
    if head == "ge":
        return not below(left, right)
    return left == right


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
    if head == "sqrt":
        return sympy.sqrt(to_sympy(tree[1], bindings)) if bindings is not None else exact_radical(tree[1])
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


def contains_variable(tree):
    if tree[0] == "var":
        return True
    return tree[0] != "num" and any(contains_variable(c) for c in tree[1:] if isinstance(c, tuple))


def holds_variable_radical(tree):
    if tree[0] == "sqrt" and contains_variable(tree[1]):
        return True
    return tree[0] != "num" and any(holds_variable_radical(c) for c in tree[1:] if isinstance(c, tuple))


def exact_radical(inner):
    """The SymPy number under a sqrt node, or the reason it cannot be one."""
    if contains_variable(inner):
        raise Unreadable("radical_variable")
    number = value(inner, Fraction(0))
    if number is None:
        raise Unreadable("empty_domain")
    if isinstance(number, sympy.Basic):
        raise Unreadable("nested_radical")
    if number < 0:
        raise Unreadable("negative_radicand")
    return sympy.sqrt(sympy.Rational(number.numerator, number.denominator))


def typed_radicands(tree):
    """The squarefree d of each sqrt(d) written in a tree."""
    if tree[0] in ("num", "var"):
        return set()
    if tree[0] == "sqrt" and contains_variable(tree[1]):
        return set()
    if tree[0] == "sqrt":
        root = exact_radical(tree[1])
        return set() if root.is_Rational else {root.as_coeff_Mul()[1]}
    found = set()
    for child in tree[1:]:
        if isinstance(child, tuple):
            found |= typed_radicands(child)
    return found


def check_radicals(*lines):
    found = set()
    for line in lines:
        found |= typed_radicands(line)
    if len(found) > 1:
        raise Unreadable("many_radicals")


def denominators(tree):
    head = tree[0]
    if head in ("num", "var"):
        return []
    if head in ("neg", "pow", "sqrt", "abs"):
        return denominators(tree[1])
    found = denominators(tree[1]) + denominators(tree[2])
    if head == "div":
        found.append(tree[2])
    return found


def canonical(root):
    return sympy.expand(sympy.radsimp(sympy.sqrtdenest(root)))


def all_roots(expression):
    """Every complex root, each once and in one written form."""
    if not expression.has(X):
        return set()
    if not expression.has(sympy.Pow):
        return set(sympy.Poly(expression, X).all_roots())
    poly = sympy.Poly(expression, X, extension=True)
    if poly.domain.is_QQ or poly.domain.is_ZZ:
        return set(poly.all_roots())
    found = sympy.roots(poly)
    if sum(found.values()) != poly.degree():
        raise ValueError(f"no exact roots for {expression}")
    return {canonical(root) for root in found}


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
        zeros |= all_roots(top)
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
    return ("finite", frozenset(all_roots(top) - zeros))


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


def real_members(values):
    return [root for root in values if root.is_real]


def empty(shape_set):
    return shape_set[0] == "finite" and not real_members(shape_set[1])


def surd_parts(root):
    """(a, b, d) for a real root a + b*sqrt(d) in rationals and a squarefree d, or None."""
    a, rest = root.as_coeff_Add()
    b, term = rest.as_coeff_Mul()
    if term.is_Pow and term.exp == sympy.Rational(1, 2) and term.base.is_Integer:
        return a, b, int(term.base)
    return None


def exact_or_refuse(shape_set):
    """With rational roots out, at most two roots may be left, and each a surd, if any is real."""
    left = [root for root in shape_set[1] if not root.is_rational]
    if not real_members(left):
        return
    if len(left) > 2 or any(surd_parts(root) is None for root in real_members(left)):
        raise Unreadable("irrational_root")


def as_number(root):
    return Fraction(int(root.p), int(root.q)) if root.is_Rational else root


def member_outside(difference):
    """The smallest member of a difference set, or the first whole number not removed from it."""
    shape, values = difference
    if shape == "finite":
        return as_number(ordered(values)[0])
    candidate = Fraction(0)
    taken = {as_number(root) for root in real_members(values) if root.is_rational}
    while candidate in taken:
        candidate += 1
    return candidate


def ordered(values):
    return sorted(real_members(values), key=lambda root: sympy.N(root, 60))


def surd_core(u, v, d):
    size = "" if abs(v) == 1 else str(abs(v))
    root = f"{size}sqrt({d})"
    if u == 0:
        return f"-{root}" if v < 0 else root
    return f"{u} {'-' if v < 0 else '+'} {root}"


def text_of(root):
    """Exact text, byte for byte the Lisp core's: 3/2, -2sqrt(3), (1 + 3sqrt(5))/2."""
    if not isinstance(root, sympy.Basic):
        return str(root)
    if root.is_Rational:
        return str(as_number(root))
    a, b, d = surd_parts(root)
    bottom = sympy.ilcm(a.q, b.q)
    core = surd_core(a * bottom, b * bottom, d)
    if bottom == 1:
        return core
    return f"{core}/{bottom}" if a == 0 else f"({core})/{bottom}"


# Sign charts: the breakpoints of a line, and whether it holds at each and in each gap.


def chart_line(tree):
    """Does the tree hold an inequality, an absolute value, or a root over the variable?"""
    if tree[0] in RELATIONS or tree[0] == "abs" or (tree[0] == "sqrt" and contains_variable(tree[1])):
        return True
    return tree[0] != "num" and any(chart_line(c) for c in tree[1:] if isinstance(c, tuple))


def abs_count(tree):
    if tree[0] in ("num", "var"):
        return 0
    inside = sum(abs_count(c) for c in tree[1:] if isinstance(c, tuple))
    return inside + (tree[0] == "abs")


def opened(tree):
    """Each way to read a tree with its absolute values opened."""
    if tree[0] in ("num", "var"):
        return [tree]
    if tree[0] == "abs":
        inner = opened(tree[1])
        return inner + [("neg", item) for item in inner]
    choices = [(tree[0],)]
    for child in tree[1:]:
        options = opened(child) if isinstance(child, tuple) else [child]
        choices = [choice + (option,) for choice in choices for option in options]
    return choices


def relations(line):
    if line[0] in ("or", "and"):
        return [found for item in line[1:] for found in relations(item)]
    return [line]


def exact_values(roots):
    """The real roots of one polynomial as numbers in one written form, refusing as sets do."""
    exact_or_refuse(("finite", roots))
    return {as_number(canonical(root)) for root in real_members(roots)}


def difference_bounds(left, right):
    if holds_variable_radical(left) or holds_variable_radical(right):
        return radical_bounds(left, right)
    equation = ("eq", left, right)
    shape, roots = equation_set(equation)
    found = exact_values(domain_zeros(equation))
    if shape == "finite":
        difference = to_sympy(left) - to_sympy(right)
        top = sympy.expand(sympy.fraction(sympy.together(difference))[0])
        found |= exact_values(all_roots(top))
    return found


def with_unknowns(tree, radicals):
    """A tree as SymPy, each root over the variable a symbol, its radicand listed in radicals."""
    head = tree[0]
    if not holds_variable_radical(tree):
        return to_sympy(tree)
    if head == "sqrt":
        if holds_variable_radical(tree[1]):
            raise Unreadable("nested_radical")
        if tree[1] not in radicals:
            if len(radicals) == MAX_RADICALS:
                raise Unreadable("radical_limit")
            radicals.append(tree[1])
        return sympy.Symbol(f"root{radicals.index(tree[1])}", real=True)
    if head == "div":
        if holds_variable_radical(tree[2]):
            raise Unreadable("radical_denominator")
        return with_unknowns(tree[1], radicals) / to_sympy(tree[2])
    if head == "neg":
        return -with_unknowns(tree[1], radicals)
    if head == "pow":
        return with_unknowns(tree[1], radicals) ** tree[2]
    left = with_unknowns(tree[1], radicals)
    right = with_unknowns(tree[2], radicals)
    return {"add": left + right, "sub": left - right, "mul": left * right}[head]


def radical_top(difference, radicals):
    """The polynomial left by multiplying a difference through every choice of signs on its roots."""
    unknowns = [sympy.Symbol(f"root{i}", real=True) for i in range(len(radicals))]
    squares = [to_sympy(inner) for inner in radicals]
    product = sympy.Integer(1)
    for signs in itertools.product((1, -1), repeat=len(unknowns)):
        product *= difference.subs({u: s * u for u, s in zip(unknowns, signs)}, simultaneous=True)
    top = sympy.together(sympy.expand(product))
    for unknown, square in zip(unknowns, squares):
        top = sympy.Poly(sympy.fraction(top)[0], unknown)
        top = sympy.together(sum(c * square ** (m[0] // 2) * unknown ** (m[0] % 2) for m, c in top.terms()))
    return sympy.expand(sympy.fraction(sympy.cancel(top))[0])


def radical_bounds(left, right):
    """Everywhere the two sides might meet, and everywhere a root or a denominator starts or stops."""
    radicals = []
    difference = sympy.together(with_unknowns(left, radicals) - with_unknowns(right, radicals))
    found = set()
    zeros = set(domain_zeros(("eq", left, right)))
    for inner in radicals:
        top = sympy.expand(sympy.fraction(sympy.together(to_sympy(inner)))[0])
        found |= exact_values(all_roots(top))
    top = radical_top(difference, radicals) if difference != 0 else sympy.Integer(0)
    if top != 0 and top.has(X):
        if sympy.degree(top, X) > MAX_DEGREE:
            raise Unreadable("degree_limit")
        found |= exact_values(all_roots(top))
    return found | exact_values(zeros)


def line_bounds(line):
    if abs_count(line) > MAX_ABS:
        raise Unreadable("abs_limit")
    found = set()
    for relation in relations(line):
        for left in opened(relation[1]):
            for right in opened(relation[2]):
                found |= difference_bounds(left, right)
    return found


def sort_key(number):
    if isinstance(number, sympy.Basic):
        return sympy.N(number, 60)
    return sympy.N(sympy.Rational(number.numerator, number.denominator), 60)


def chart_bounds(*lines):
    found = set()
    for line in lines:
        found |= line_bounds(line)
    radicands = {surd_parts(n)[2] for n in found if isinstance(n, sympy.Basic)}
    if len(radicands) > 1:
        raise Unreadable("many_radicals")
    return sorted(found, key=sort_key)


def midpoint(a, b):
    return tidy((a + b) / 2)


def chart_slots(bounds):
    """A point for each gap and each breakpoint, in order, starting and ending with an outer gap."""
    if not bounds:
        return [Fraction(0)]
    slots = [tidy(bounds[0] - 1)]
    for at, bound in enumerate(bounds):
        slots.append(bound)
        slots.append(midpoint(bound, bounds[at + 1]) if at + 1 < len(bounds) else tidy(bound + 1))
    return slots


def chart_pieces(bounds, marks):
    """The true slots as pieces, [low, low closed, high, high closed], None for an open end."""
    pieces = []
    open_piece = None
    for slot, mark in enumerate(marks):
        point = slot % 2 == 1
        k = slot // 2
        low = bounds[k] if point else (bounds[k - 1] if k > 0 else None)
        high = bounds[k] if point else (bounds[k] if k < len(bounds) else None)
        if not mark:
            if open_piece:
                pieces.append(open_piece)
            open_piece = None
        elif open_piece:
            open_piece[2:] = [high, point]
        else:
            open_piece = [low, point, high, point]
    if open_piece:
        pieces.append(open_piece)
    return pieces


def is_point(piece):
    return piece[1] and piece[0] is not None and piece[0] == piece[2]


def piece_witness(piece):
    low, _, high, _ = piece
    if is_point(piece):
        return low
    if low is not None and high is not None:
        return midpoint(low, high)
    if low is not None:
        return tidy(low + 1)
    if high is not None:
        return tidy(high - 1)
    return Fraction(0)


def piece_text(piece):
    low, low_closed, high, high_closed = piece
    if is_point(piece):
        return "{" + text_of(low) + "}"
    left = "-inf" if low is None else text_of(low)
    right = "inf" if high is None else text_of(high)
    return f"{'[' if low_closed else '('}{left},{right}{']' if high_closed else ')'}"


def chart_payload(name, bounds, marks):
    pieces = chart_pieces(bounds, marks)
    finite = all(is_point(piece) for piece in pieces)
    members = [text_of(piece[0]) if finite else piece_text(piece) for piece in pieces]
    return {"verdict": name, "shape": "Finite" if finite else "Ranges", "set": sorted(members),
            "members": members, "witness": piece_witness(pieces[0])}


def chart_verdict(previous, line):
    bounds = chart_bounds(previous, line)
    slots = chart_slots(bounds)
    before = [holds(previous, x) for x in slots]
    after = [holds(line, x) for x in slots]
    lost = [b and not a for b, a in zip(before, after)]
    gained = [a and not b for b, a in zip(before, after)]
    if not any(lost) and not any(gained):
        return {"verdict": "EQUIVALENT"}
    if not any(lost):
        return chart_payload("GAINS", bounds, gained)
    if not any(gained):
        return chart_payload("LOSES", bounds, lost)
    return chart_payload("UNRELATED", bounds, lost)


def holds_nowhere(line):
    if chart_line(line):
        return not any(holds(line, x) for x in chart_slots(chart_bounds(line)))
    shape, values = solution_set(line)
    return shape == "finite" and not real_members(values)


def holds_almost_everywhere(line):
    """Is the line true at all but a few values?"""
    if chart_line(line):
        slots = chart_slots(chart_bounds(line))
        return all(holds(line, x) for x in slots[0::2])
    return solution_set(line)[0] == "allexcept"


def expression_parts(tree):
    """A tree as SymPy, and every value removed from its domain."""
    if chart_line(tree):
        raise Unreadable("expression_form")
    zeros = domain_zeros(("eq", tree, ("num", Fraction(0))))
    meaning = to_sympy(tree)
    if meaning.has(sympy.zoo, sympy.nan):
        raise Unreadable("empty_domain")
    top = sympy.fraction(sympy.cancel(sympy.together(meaning)))[0]
    if top.has(X) and sympy.degree(top, X) > MAX_DEGREE:
        raise Unreadable("degree_limit")
    return meaning, zeros


def first_whole_outside(top, zeros):
    """The first whole number from 0 that is neither a root of top nor a removed value."""
    candidate = 0
    while top.subs(X, candidate) == 0 or sympy.Integer(candidate) in zeros:
        candidate += 1
    return Fraction(candidate)


def finite_payload(name, values):
    exact_or_refuse(("finite", values))
    return {"verdict": name, "shape": "Finite", "set": sorted(text_of(root) for root in real_members(values)),
            "members": [text_of(root) for root in ordered(values)],
            "witness": member_outside(("finite", values))}


def expression_verdict(before, after):
    """The verdict on a step between two expressions: do they agree, and where do they have values?"""
    try:
        check_radicals(before, after)
        a, a_zeros = expression_parts(before)
        b, b_zeros = expression_parts(after)
        top = sympy.fraction(sympy.cancel(sympy.together(a - b)))[0]
        if top != 0:
            return {"verdict": "UNRELATED", "shape": "Differ", "set": [], "members": [],
                    "witness": first_whole_outside(top, a_zeros | b_zeros)}
        gained = frozenset(a_zeros - b_zeros)
        lost = frozenset(b_zeros - a_zeros)
        if not real_members(gained) and not real_members(lost):
            return {"verdict": "EQUIVALENT"}
        if not real_members(lost):
            return finite_payload("GAINS", gained)
        if not real_members(gained):
            return finite_payload("LOSES", lost)
        return finite_payload("UNRELATED", lost)
    except Unreadable as refused:
        return {"verdict": "OUT_OF_FRAGMENT", "reason": refused.reason}


def verdict(previous, line):
    """The verdict on a step, with its payload and one exact witness."""
    try:
        check_radicals(previous, line)
        if chart_line(previous) or chart_line(line):
            return chart_verdict(previous, line)
        before = solution_set(previous)
        after = solution_set(line)
        lost = subtract(before, after)
        gained = subtract(after, before)
        if not empty(lost):
            exact_or_refuse(lost)
        if not empty(gained):
            exact_or_refuse(gained)
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
        "set": sorted(text_of(root) for root in real_members(difference[1])),
        "members": [text_of(root) for root in ordered(difference[1])],
        "witness": member_outside(difference),
    }


# Systems of linear equations: see SEMANTICS.md. The Lisp core compares row spaces; here a system's
# points are compared, using that an affine set is fixed by its points with free variables 0 or 1.

SYSTEM_SYMBOLS = {"var": sympy.Symbol("x"), "y": sympy.Symbol("y"), "z": sympy.Symbol("z")}
NO_POINT = (0, 0, 0, 1)


def linear_part(tree):
    kind = tree[0]
    if kind == "num":
        return sympy.Rational(tree[1].numerator, tree[1].denominator)
    if kind in SYSTEM_SYMBOLS:
        return SYSTEM_SYMBOLS[kind]
    if kind == "add":
        return sympy.expand(linear_part(tree[1]) + linear_part(tree[2]))
    if kind == "sub":
        return sympy.expand(linear_part(tree[1]) - linear_part(tree[2]))
    if kind == "neg":
        return sympy.expand(-linear_part(tree[1]))
    if kind == "mul":
        left, right = linear_part(tree[1]), linear_part(tree[2])
        if left.is_number or right.is_number:
            return sympy.expand(left * right)
        raise Unreadable("nonlinear_system")
    if kind == "div":
        bottom = linear_part(tree[2])
        if not bottom.is_number:
            raise Unreadable("nonlinear_system")
        if bottom == 0:
            raise Unreadable("empty_domain")
        return sympy.expand(linear_part(tree[1]) / bottom)
    if kind == "pow":
        base = linear_part(tree[1])
        if base.is_number:
            return base ** tree[2]
        if tree[2] == 1:
            return base
    raise Unreadable("nonlinear_system")


def system_rows(equations):
    """The reduced rows of a system, each (a, b, c, k) for ax + by + cz + k = 0."""
    x, y, z = SYSTEM_SYMBOLS.values()
    rows = []
    for left, right in equations:
        difference = sympy.expand(linear_part(left) - linear_part(right))
        rows.append([difference.coeff(x), difference.coeff(y), difference.coeff(z),
                     difference.subs({x: 0, y: 0, z: 0})])
    reduced = sympy.Matrix(rows).rref()[0].tolist()
    found = [tuple(row) for row in reduced if any(item != 0 for item in row)]
    return [NO_POINT] if NO_POINT in found else found


def system_points(rows, count):
    if NO_POINT in rows:
        return []
    pivots = {next(i for i, item in enumerate(row) if item != 0): row for row in rows}
    free = [column for column in range(count) if column not in pivots]
    found = []
    for choice in itertools.product((0, 1), repeat=len(free)):
        point = [sympy.Integer(0)] * count
        for column, item in zip(free, choice):
            point[column] = sympy.Integer(item)
        for column, row in pivots.items():
            point[column] = -(row[3] + sum(row[c] * point[c] for c in free))
        found.append(point)
    return found


def fits(rows, point):
    return all(row[3] + sum(item * value for item, value in zip(row, point)) == 0 for row in rows)


def system_text(before, after, count):
    """The verdict on going from one system to another, as exact text."""
    a, b = system_rows(before), system_rows(after)
    only_a = [p for p in system_points(a, count) if not fits(b, p)]
    only_b = [p for p in system_points(b, count) if not fits(a, p)]
    if not only_a and not only_b:
        return "EQUIVALENT"
    name = "UNRELATED" if only_a and only_b else "LOSES" if only_a else "GAINS"
    witness = (only_a or only_b)[0]
    return f"{name} System witness=({','.join(str(value) for value in witness)})"


# Complex numbers: see SEMANTICS.md. SymPy's own complex numbers do the arithmetic and find the roots.

def complex_of(tree, x):
    kind = tree[0]
    if kind == "num":
        return sympy.Rational(tree[1].numerator, tree[1].denominator)
    if kind == "var":
        return x
    if kind == "i":
        return sympy.I
    if kind == "add":
        return sympy.expand(complex_of(tree[1], x) + complex_of(tree[2], x))
    if kind == "sub":
        return sympy.expand(complex_of(tree[1], x) - complex_of(tree[2], x))
    if kind == "neg":
        return sympy.expand(-complex_of(tree[1], x))
    if kind == "mul":
        return sympy.expand(complex_of(tree[1], x) * complex_of(tree[2], x))
    if kind == "pow":
        return sympy.expand(complex_of(tree[1], x) ** tree[2])
    if kind == "div":
        bottom = complex_of(tree[2], x)
        if bottom.has(x):
            raise Unreadable("complex_degree")
        if bottom == 0:
            raise Unreadable("empty_domain")
        return sympy.expand(sympy.radsimp(complex_of(tree[1], x) / bottom))
    inner = complex_of(tree[1], x)
    if inner.has(x):
        raise Unreadable("complex_root")
    if kind == "sqrt":
        if sympy.im(inner) != 0:
            raise Unreadable("complex_root")
        if not inner.is_Rational:
            raise Unreadable("nested_radical")
        return sympy.sqrt(inner)
    size = sympy.sqrtdenest(sympy.sqrt(sympy.expand(sympy.re(inner) ** 2 + sympy.im(inner) ** 2)))
    if any(not power.base.is_Rational for power in size.atoms(sympy.Pow)):
        raise Unreadable("complex_root")
    return size


def complex_roots(polynomial, x):
    """The roots of a polynomial that is not zero, within the same limits as the Lisp core."""
    poly = sympy.Poly(polynomial, x, extension=True)
    if poly.degree() > MAX_DEGREE:
        raise Unreadable("degree_limit")
    if poly.degree() == 0:
        return []
    if poly.degree() <= 2:
        if poly.degree() == 2:
            a, b, c = poly.all_coeffs()
            discriminant = sympy.expand(b ** 2 - 4 * a * c)
            if sympy.im(discriminant) != 0 or not sympy.sqrt(sympy.Abs(discriminant)).is_real:
                raise Unreadable("complex_degree")
            root = sympy.sqrt(sympy.Abs(discriminant))
            if root.is_Pow and not root.base.is_Rational:
                raise Unreadable("complex_degree")
        return list(sympy.roots(poly).keys())
    if not all(item.is_Rational for item in poly.all_coeffs()):
        raise Unreadable("complex_degree")
    rational = sorted(root for root in sympy.Poly(poly.as_expr(), x).ground_roots())
    if not rational:
        raise Unreadable("complex_degree")
    quotient = sympy.Poly(poly.as_expr(), x).quo(sympy.Poly(x - rational[0], x))
    return [rational[0], *complex_roots(quotient.as_expr(), x)]


def complex_key(number):
    return (sympy.re(number).evalf(60), sympy.im(number).evalf(60))


def complex_distinct(numbers):
    found = []
    for number in numbers:
        tidy_number = sympy.expand(sympy.radsimp(number))
        if tidy_number not in found:
            found.append(tidy_number)
    return sorted(found, key=complex_key)


def complex_relation(relation, x):
    if relation[0] != "eq":
        raise Unreadable("complex_relation")
    difference = sympy.expand(complex_of(relation[1], x) - complex_of(relation[2], x))
    return "all" if difference == 0 else complex_roots(difference, x)


def complex_line_set(line):
    x = sympy.Symbol("x")
    relations = line[1:] if line[0] == "or" else (line,)
    sets = [complex_relation(relation, x) for relation in relations]
    return "all" if "all" in sets else complex_distinct(sum(sets, []))


def imaginary_text(im):
    if im == 1:
        return "i"
    if im == -1:
        return "-i"
    if im.is_Add:
        return f"({text_of(im)})i"
    return f"{text_of(im)}i"


def complex_text(number):
    """Exact text, byte for byte the Lisp core's: 3, 2i, -i, 1 + 2i, 1/2 - sqrt(3)i."""
    re, im = sympy.re(number), sympy.im(number)
    if im == 0:
        return text_of(re)
    if re == 0:
        return imaginary_text(im)
    if not im.is_Add and im.could_extract_minus_sign():
        return f"{text_of(re)} - {imaginary_text(-im)}"
    return f"{text_of(re)} + {imaginary_text(im)}"


def whole_beyond(numbers):
    return next(sympy.Integer(n) for n in itertools.count() if sympy.Integer(n) not in numbers)


def complex_outcome(name, members, witness):
    shown = ",".join(complex_text(member) for member in members)
    return f"{name} Complex{{{shown}}} witness={complex_text(witness)}"


def complex_lines_text(before, after):
    a, b = complex_line_set(before), complex_line_set(after)
    if a == "all" and b == "all":
        return "EQUIVALENT"
    if a == "all":
        return complex_outcome("LOSES", [], whole_beyond(b))
    if b == "all":
        return complex_outcome("GAINS", [], whole_beyond(a))
    lost = [number for number in a if number not in b]
    gained = [number for number in b if number not in a]
    if not lost and not gained:
        return "EQUIVALENT"
    if not lost:
        return complex_outcome("GAINS", gained, gained[0])
    if not gained:
        return complex_outcome("LOSES", lost, lost[0])
    return complex_outcome("UNRELATED", lost, lost[0])


def complex_numbers_text(before, after):
    x = sympy.Symbol("x")
    a, b = (sympy.expand(sympy.radsimp(complex_of(tree, x))) for tree in (before, after))
    if a.has(x) or b.has(x):
        raise Unreadable("complex_degree")
    return "EQUIVALENT" if a == b else complex_outcome("UNRELATED", [], b)


# Exponents and logarithms: see SEMANTICS.md. The Lisp core reduces a line to ordinary algebra. This
# oracle shares none of that: it evaluates the typed tree in 80-digit arithmetic, at the points of a
# grid and at each place a side changes sign, and compares where each line holds.

mpmath.mp.dps = 80
CLOSE = mpmath.mpf(10) ** -50
WIDE = [mpmath.mpf(n) for n in range(-260, -12, 8)] + [mpmath.mpf(n) for n in range(16, 260, 8)]
GRID = sorted([mpmath.mpf(n) / 2 for n in range(-24, 25)] + WIDE)
NUDGE = mpmath.mpf(10) ** -9


def real_of(tree, x):
    """The value of a tree at x in 80 digits, or None where it has none."""
    kind = tree[0]
    if kind == "num":
        return mpmath.mpf(tree[1].numerator) / tree[1].denominator
    if kind == "var":
        return x
    if kind == "e":
        return mpmath.e
    if kind == "log":
        inner = real_of(tree[2], x)
        if inner is None or inner <= 0:
            return None
        base = mpmath.e if tree[1] == "e" else mpmath.mpf(tree[1].numerator) / tree[1].denominator
        return mpmath.log(inner) / mpmath.log(base)
    a = real_of(tree[1], x)
    if a is None:
        return None
    if kind == "neg":
        return -a
    if kind == "abs":
        return abs(a)
    if kind == "sqrt":
        return None if a < 0 else mpmath.sqrt(a)
    if kind == "pow":
        return a ** tree[2]
    b = real_of(tree[2], x)
    if b is None:
        return None
    if kind == "add":
        return a + b
    if kind == "sub":
        return a - b
    if kind == "mul":
        return a * b
    if kind == "div":
        return None if abs(b) < CLOSE else a / b
    if abs(a) < CLOSE:
        return a if b > 0 else None
    if a < 0:
        return a ** int(b) if abs(b - round(b)) < CLOSE else None
    return a ** b


def line_holds(line, x):
    if line[0] == "or":
        return any(line_holds(item, x) for item in line[1:])
    if line[0] == "and":
        return all(line_holds(item, x) for item in line[1:])
    left, right = real_of(line[1], x), real_of(line[2], x)
    if left is None or right is None:
        return False
    gap = left - right
    return {"eq": abs(gap) < CLOSE, "lt": gap < -CLOSE, "le": gap < CLOSE, "gt": gap > CLOSE, "ge": gap > -CLOSE}[line[0]]


def line_relations(line):
    if line[0] in ("or", "and"):
        return [relation for item in line[1:] for relation in line_relations(item)]
    return [line]


def relation_gap(relation, x):
    left, right = real_of(relation[1], x), real_of(relation[2], x)
    return None if left is None or right is None else left - right


def bisected(relation, low, high, low_gap):
    for _ in range(280):
        middle = (low + high) / 2
        gap = relation_gap(relation, middle)
        if gap is None:
            return None
        if gap == 0:
            return middle
        if (gap > 0) == (low_gap > 0):
            low = middle
        else:
            high = middle
    return (low + high) / 2


def line_points(line):
    """Grid points, each place a relation's sides cross, and just either side of those."""
    points = list(GRID)
    for relation in line_relations(line):
        gaps = [relation_gap(relation, x) for x in GRID]
        for low, high, low_gap, high_gap in zip(GRID, GRID[1:], gaps, gaps[1:]):
            if low_gap is not None and high_gap is not None and (low_gap > 0) != (high_gap > 0) and low_gap != 0:
                root = bisected(relation, low, high, low_gap)
                if root is not None:
                    points += [root - NUDGE, root, root + NUDGE]
    return points


def compared_name(before, after, points):
    only_before = any(before(x) and not after(x) for x in points)
    only_after = any(after(x) and not before(x) for x in points)
    if only_before and only_after:
        return "UNRELATED"
    return "LOSES" if only_before else "GAINS" if only_after else "EQUIVALENT"


def log_lines_text(previous, line):
    points = line_points(previous) + line_points(line)
    return compared_name(lambda x: line_holds(previous, x), lambda x: line_holds(line, x), points)


def log_values_text(previous, line):
    """Two values are the same where both have one. A value that only one has is a gain or a loss."""
    points = [x + mpmath.mpf(1) / 7 for x in GRID] + GRID
    lost = gained = False
    for x in points:
        a, b = real_of(previous, x), real_of(line, x)
        if a is None and b is None:
            continue
        if a is None:
            gained = True
        elif b is None:
            lost = True
        elif abs(a - b) > CLOSE * (1 + abs(a)):
            return "UNRELATED"
    if lost and gained:
        return "UNRELATED"
    return "LOSES" if lost else "GAINS" if gained else "EQUIVALENT"
