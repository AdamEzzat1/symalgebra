"""Tier D fixture: seeded line pairs with the oracle's verdict as exact text.

Usage: gen_differential.py <output>          writes the fixture
       gen_differential.py <output> --check  fails if the fixture is stale

The Lisp core must reproduce every `expected` string byte for byte.
"""

import json
import random
import re
import sys
from fractions import Fraction
from pathlib import Path

from lang import Unreadable, parse_expression_line, parse_line, parse_system
from semantics import (complex_lines_text, complex_numbers_text, expression_verdict, log_lines_text, log_values_text,
                       system_text, text_of, verdict)

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


def factored(r):
    a, b = small(r), small(r)
    return f"(x {signed(a)})(x {signed(b)}) = 0"


def alternatives(r):
    a, b = Fraction(small(r), r.randint(1, 4)), Fraction(small(r), r.randint(1, 4))
    return f"x = {a} or x = {b}"


def square(r):
    return f"x^2 = {r.choice([2, 3, 5, 6, 7, 8, 12, 18, 20, 1/2])}"


def radical(r):
    a, b, c = small(r), nonzero(r), r.choice([2, 3, 5, 7, 8, 12])
    return f"x = {a} + {b}sqrt({c})"


def formula(r):
    a, b, c = nonzero(r), small(r), small(r)
    root = f"sqrt(({b})^2 - 4 * ({a}) * ({c}))"
    return f"x = (-({b}) + {root})/(2 * ({a})) or x = (-({b}) - {root})/(2 * ({a}))"


def relation(r):
    return r.choice(("<", "<=", ">", ">="))


def inequality(r):
    return f"{nonzero(r)}x {signed(small(r))} {relation(r)} {small(r)}"


def bars(r):
    return f"|x {signed(small(r))}| {r.choice(('=', '<', '<=', '>', '>='))} {small(r, -2)}"


def square_range(r):
    return f"x^2 {relation(r)} {r.choice([1, 2, 3, 4, 5, 9, 12, 16])}"


def over_x(r):
    return f"1/(x {signed(small(r))}) {relation(r)} {small(r)}"


def root_line(r):
    return f"sqrt({nonzero(r)}x {signed(small(r))}) = {small(r, 0, 9)}"


def root_beside_x(r):
    return f"sqrt(x {signed(small(r))}) = x {signed(small(r))}"


def root_range(r):
    return f"sqrt(x {signed(small(r))}) {r.choice(['<', '>', '<=', '>='])} {small(r, 0, 9)}"


def garbled(r):
    return "".join(r.choice(GARBLE_ALPHABET) for _ in range(r.randint(1, 12)))


FAMILIES = (linear, distribution, fraction, rational, cancelling, quadratic, power, garbled,
            factored, alternatives, square, radical, formula, inequality, bars, square_range, over_x,
            root_line, root_beside_x, root_range)


def expression_product(r):
    a, b = small(r), small(r)
    return (f"(x {signed(a)})(x {signed(b)})",
            f"x^2 {signed(a + b)}x {signed(a * b + r.choice((0, 0, 1)))}")


def expression_cancel(r):
    a, b = small(r), small(r)
    return (f"(x^2 {signed(a + b)}x {signed(a * b)})/(x {signed(a)})", f"x {signed(b + r.choice((0, 0, 1)))}")


def expression_restore(r):
    long, short = expression_cancel(r)
    return (short, long)


def expression_sum(r):
    a, b, c = nonzero(r), nonzero(r), nonzero(r)
    return (f"{a}/x + {b}/(x {signed(c)})",
            f"({a + b}x {signed(a * c + r.choice((0, 0, 1)))})/(x(x {signed(c)}))")


def expression_fraction(r):
    a, b = nonzero(r), nonzero(r)
    return (f"x/(x {signed(a)}) - {b}/(x {signed(a)})", f"(x {signed(-b)})/(x {signed(a)})")


def expression_garbled(r):
    return (garbled(r), garbled(r))


EXPRESSION_FAMILIES = (expression_product, expression_cancel, expression_restore, expression_sum,
                       expression_fraction, expression_garbled)


def row_text(r, names):
    terms = " ".join(f"{signed(nonzero(r))}{name}" for name in names)
    return f"{terms[2:] if terms[0] == '+' else '-' + terms[2:]} = {small(r)}"


def scaled(row, by):
    left, right = row.split(" = ")
    return f"{by}({left}) = {by * int(right)}"


def system_pair(r, names):
    rows = [row_text(r, names) for _ in names]
    start = ", ".join(rows)
    move = r.randrange(5)
    if move == 0:
        return start, ", ".join(reversed(rows))
    if move == 1:
        return start, ", ".join(scaled(row, nonzero(r)) for row in rows)
    if move == 2:
        return start, rows[0]
    if move == 3:
        return rows[0], start
    return start, ", ".join([rows[0], row_text(r, names), *rows[2:]])


def system_two(r):
    return system_pair(r, "xy")


def system_three(r):
    return system_pair(r, "xyz")


def system_special(r):
    row = row_text(r, "xy")
    left, right = row.split(" = ")
    other = f"{left} = {int(right) + nonzero(r)}"
    return f"{row}, {other}", r.choice([row, other, "0 = 1", "0 = 0", "x = 1", "x = 1, y = 2", scaled(row, 2)])


def system_garbled(r):
    alphabet = GARBLE_ALPHABET + ["x", "y", ",", "=", "y"]
    return "".join(r.choice(alphabet) for _ in range(r.randint(1, 10))), row_text(r, "xy")


SYSTEM_FAMILIES = ((system_two, "xy"), (system_three, "xyz"), (system_special, "xy"), (system_garbled, "xy"))


def gaussian(r):
    a, b = small(r), nonzero(r)
    return f"{a} {signed(b)}i"


def complex_sum(r):
    a, b = gaussian(r), gaussian(r)
    return f"({a}) + ({b})", r.choice([f"({b}) + ({a})", f"({a}) - ({b})", gaussian(r)])


def complex_product(r):
    a, b = gaussian(r), gaussian(r)
    return f"({a})({b})", r.choice([f"({b})({a})", gaussian(r), f"({a}) + ({b})"])


def complex_quotient(r):
    a, b = gaussian(r), gaussian(r)
    return f"({a})/({b})", r.choice([f"({a})({b})", gaussian(r), f"({a})/({b})"])


def complex_power(r):
    n = r.randint(1, 6)
    return f"i^{n}", r.choice(["1", "-1", "i", "-i"])


def complex_square(r):
    a = r.randint(1, 9)
    return f"x^2 + {a * a} = 0", r.choice([f"x = {a}i or x = -{a}i", f"x = ±{a}i", f"x = {a}i", f"x = {a}", f"x^2 = -{a * a}"])


def complex_quadratic(r):
    b, c = small(r), small(r)
    return f"x^2 {signed(b)}x {signed(c)} = 0", f"x = {small(r)} ± {r.randint(1, 5)}i"


def complex_linear(r):
    a = gaussian(r)
    return f"2x + {r.randint(1, 5)}i = {small(r)}", r.choice([f"x = {a}", f"2x = {a}", f"({a})x = 1"])


def complex_garbled(r):
    alphabet = GARBLE_ALPHABET + ["i", "i"]
    return "".join(r.choice(alphabet) for _ in range(r.randint(1, 10))), "x = 1"


COMPLEX_NUMBER_FAMILIES = (complex_sum, complex_product, complex_quotient, complex_power)
COMPLEX_LINE_FAMILIES = (complex_square, complex_quadratic, complex_linear, complex_garbled)


def small_base(r):
    return r.choice([2, 3, 5, 10])


def exp_whole(r):
    b, n, c = small_base(r), r.randint(1, 3), r.randint(-3, 3)
    return f"{b}^(x {signed(c)}) = {b ** n}", r.choice([f"x = {n - c}", f"x = {n - c + 1}", f"x {signed(c)} = {n}"])


def exp_scaled(r):
    b, n, c = small_base(r), r.randint(1, 3), r.randint(2, 5)
    return f"{c} * {b}^x = {c * b ** n}", r.choice([f"{b}^x = {b ** n}", f"x = {n}", f"x = {n + 1}"])


def exp_common(r):
    n = r.randint(1, 3)
    return f"4^x = {2 ** n}", r.choice([f"2^(2x) = 2^{n}", f"x = {n}/2", f"x = {n}"])


def exp_log(r):
    b, q = r.choice([2, 3, 5]), r.choice([7, 11, 13])
    return f"{b}^x = {q}", r.choice([f"x = log{b}({q})", f"x = log{b}({q + 2})", f"x = ln({q})/ln({b})", f"x ln({b}) = ln({q})", "x = 1"])


def exp_range(r):
    b, n = small_base(r), r.randint(1, 3)
    return f"{b}^x > {b ** n}", r.choice([f"x > {n}", f"x < {n}", f"x > {n - 1}", f"x >= {n}", f"x > {n + 1}"])


def log_whole(r):
    b, n, c = r.choice([2, 3, 5]), r.randint(1, 3), r.randint(-3, 3)
    return f"log{b}(x {signed(c)}) = {n}", r.choice([f"x = {b ** n - c}", f"x = {b ** n}", f"x {signed(c)} = {b ** n}"])


def log_sum(r):
    b, k, m = r.choice([2, 3]), r.randint(1, 3), r.randint(1, 3)
    root, other = b ** k, b ** m
    c = other - root
    n = k + m
    if c <= 0:
        return f"log{b}(x) = {k}", f"x = {root}"
    return (f"log{b}(x) + log{b}(x + {c}) = {n}",
            r.choice([f"x(x + {c}) = {b ** n}", f"x = {root}", f"x = {root} or x = {-other}", f"x = {other}"]))


def log_range(r):
    b, n = r.choice([2, 3]), r.randint(1, 3)
    return f"log{b}(x) < {n}", r.choice([f"0 < x < {b ** n}", f"x < {b ** n}", f"0 < x < {b ** n + 1}", f"x > {b ** n}"])


def value_numbers(r):
    b, p, q = r.choice([2, 3, 5]), r.choice([3, 7, 11]), r.choice([2, 13, 17])
    return f"log{b}({p}) + log{b}({q})", r.choice([f"log{b}({p * q})", f"log{b}({p + q})", f"log{b}({p}) - log{b}({q})"])


def value_powers(r):
    a, b = r.randint(1, 2), r.randint(1, 2)
    return f"x^{a} * x^{b}", r.choice([f"x^{a + b}", f"x^{a * b + 1}", f"x^{a}", f"(x^{a})^{b}"])


def value_quotient(r):
    a, b = r.randint(4, 6), r.randint(1, 3)
    return f"x^{a}/x^{b}", r.choice([f"x^{a - b}", f"x^{a - b + 1}", f"x^(-{b}) * x^{a}"])


def value_logs(r):
    b, c = r.choice([2, 3]), r.randint(2, 9)
    return f"log{b}(x) + log{b}({c})", r.choice([f"log{b}({c}x)", f"log{b}(x + {c})", f"log{b}(x)"])


def exp_fraction_base(r):
    b, q = r.choice([2, 3, 5]), r.choice([7, 11, 13])
    return f"(1/{b})^x = {q}", r.choice([f"x = -log{b}({q})", f"x = log(1/{b})({q})", f"x = log{b}({q})",
                                         f"x = log{b}(1/{q})"])


def value_fraction_base(r):
    b, p = r.choice([2, 3, 5]), r.choice([3, 7, 11])
    return f"log(1/{b})({p})", r.choice([f"-log{b}({p})", f"log{b}(1/{p})", f"log{b}({p})", f"log(1/{b})(1/{p})"])


LOG_LINE_FAMILIES = (exp_whole, exp_scaled, exp_common, exp_log, exp_range, log_whole, log_sum, log_range,
                     exp_fraction_base)
LOG_VALUE_FAMILIES = (value_numbers, value_powers, value_quotient, value_logs, value_fraction_base)


def expected_log(previous, line, value):
    if value:
        return log_values_text(parse_expression_line(previous, logs=True), parse_expression_line(line, logs=True))
    return log_lines_text(parse_line(previous, logs=True), parse_line(line, logs=True))


def expected_complex(previous, line, number):
    try:
        if number:
            return complex_numbers_text(parse_expression_line(previous, imaginary=True),
                                        parse_expression_line(line, imaginary=True))
        return complex_lines_text(parse_line(previous, imaginary=True), parse_line(line, imaginary=True))
    except Unreadable as refused:
        return f"OUT_OF_FRAGMENT {refused.reason}"


def partner(r, family, line):
    """A second line: often a real step from the first, sometimes something else."""
    if family in (root_line, root_beside_x, root_range):
        return root_partner(r, line)
    if family in (inequality, over_x):
        left, sign, right = line.rsplit(" ", 2)
        k = nonzero(r)
        flipped = {"<": ">", "<=": ">=", ">": "<", ">=": "<="}[sign]
        return r.choice((f"{left} {flipped} {right}", f"{right} {flipped} {left}",
                         f"({left}) * {k} {sign} ({right}) * {k}", f"({left}) * {k} {flipped} ({right}) * {k}",
                         f"{left} + {k} {sign} {right} + {k}", f"x {sign} {Fraction(small(r), r.randint(1, 4))}",
                         f"x = {small(r)}", f"{left} = {right}"))
    if family is bars:
        inside, sign, right = line[1:].replace("|", "").rsplit(" ", 2)
        return r.choice((f"{inside} {sign} {right}", f"{inside} = {right} or {inside} = -{right}",
                         f"-({right}) < {inside} < {right}", f"{inside} < -({right}) or {inside} > {right}",
                         f"abs({inside}) {sign} {right}", f"x {sign} {small(r)}", f"x = {small(r)}"))
    if family is square_range:
        _, sign, n = line.split(" ")
        return r.choice((f"-sqrt({n}) < x < sqrt({n})", f"x < -sqrt({n}) or x > sqrt({n})",
                         f"x {sign} sqrt({n})", f"x^2 - {n} {sign} 0", f"|x| {sign} sqrt({n})",
                         f"x {sign} {small(r)}"))
    if " or " in line:
        first, second = line.split(" or ")
        return r.choice((f"{second} or {first}", first, second, f"{first} or x = {small(r)}"))
    left, _, right = line.partition("=")
    roll = r.random()
    if family is square:
        n = line.partition("= ")[2]
        return r.choice((f"x = sqrt({n}) or x = -sqrt({n})", f"x = sqrt({n})", f"x = -sqrt({n})",
                         f"x = {nonzero(r)}", f"x^2 = {nonzero(r)}", f"(x - sqrt({n}))(x + sqrt({n})) = 0"))
    if family is radical:
        return r.choice((f"({line.replace('x = ', 'x - ', 1)})^2 = 0", f"x^2 = {nonzero(r)}", radical(r),
                         f"x = {nonzero(r)}", f"{line} or x = 1", f"2x = 2 * ({line.partition('= ')[2]})"))
    if family is formula:
        return quadratic_of(line, r)
    if family is factored:
        if roll < 0.5:
            return alternatives(r)
        return line.replace(") = 0", ") = 0 or x = 1")
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


def root_partner(r, line):
    """The line with its root squared away, or a nearby answer."""
    choice = r.randrange(3)
    if choice == 0:
        return f"x = {small(r, -3, 12)}"
    if choice == 1:
        return f"x {r.choice(['<', '>', '<=', '>='])} {small(r, -3, 12)}"
    return line.replace("sqrt(", "(", 1)


def quadratic_of(line, r):
    """The equation a formula line came from, or that equation slightly wrong."""
    numbers = re.findall(r"-?\d+", line)
    b, a, c = int(numbers[0]), int(numbers[4]), int(numbers[5])
    return f"{a}x^2 {signed(b)}x {signed(c + r.choice((0, 0, 0, 1)))} = 0"


def exact_text(got):
    name = got["verdict"]
    if name == "EQUIVALENT":
        return name
    if name == "OUT_OF_FRAGMENT":
        return f"{name} {got['reason']}"
    members = ",".join(got["members"])
    return f"{name} {got['shape']}{{{members}}} witness={text_of(got['witness'])}"


def expected(previous, line):
    try:
        before = parse_line(previous)
        after = parse_line(line)
    except Unreadable as refused:
        return f"OUT_OF_FRAGMENT {refused.reason}"
    return exact_text(verdict(before, after))


def expected_expression(previous, line):
    try:
        before = parse_expression_line(previous)
        after = parse_expression_line(line)
    except Unreadable as refused:
        return f"OUT_OF_FRAGMENT {refused.reason}"
    return exact_text(expression_verdict(before, after))


def expected_system(previous, line, names):
    try:
        return system_text(parse_system(previous, names), parse_system(line, names), len(names))
    except Unreadable as refused:
        return f"OUT_OF_FRAGMENT {refused.reason}"


def build():
    r = random.Random(SEED)
    cases = []
    for family in FAMILIES:
        for _ in range(PER_FAMILY):
            previous = family(r)
            line = partner(r, family, previous)
            cases.append({"previous": previous, "line": line, "expected": expected(previous, line)})
    for family in EXPRESSION_FAMILIES:
        for _ in range(PER_FAMILY):
            previous, line = family(r)
            cases.append({"previous": previous, "line": line, "expression": True,
                          "expected": expected_expression(previous, line)})
    for family, names in SYSTEM_FAMILIES:
        for _ in range(PER_FAMILY):
            previous, line = family(r)
            cases.append({"previous": previous, "line": line, "system": names,
                          "expected": expected_system(previous, line, names)})
    for number, families in ((True, COMPLEX_NUMBER_FAMILIES), (False, COMPLEX_LINE_FAMILIES)):
        for family in families:
            for _ in range(PER_FAMILY):
                previous, line = family(r)
                cases.append({"previous": previous, "line": line, "complex": "number" if number else "line",
                              "expected": expected_complex(previous, line, number)})
    for value, families in ((False, LOG_LINE_FAMILIES), (True, LOG_VALUE_FAMILIES)):
        for family in families:
            for _ in range(PER_FAMILY // 3):
                previous, line = family(r)
                cases.append({"previous": previous, "line": line, "log": "value" if value else "line",
                              "expected": expected_log(previous, line, value)})
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
