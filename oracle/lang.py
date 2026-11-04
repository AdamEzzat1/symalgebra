"""Readers for typed lines and the rule file. Independent of the Lisp engine by design.

Trees are tuples: ("num", Fraction), ("var",), ("add", a, b), ("sub", a, b), ("mul", a, b),
("div", a, b), ("neg", a), ("pow", a, n), ("sqrt", a), ("abs", a), ("eq", left, right) with "lt", "le",
"gt" or "ge" in place of "eq", ("and", relation, relation) for a range, ("or", item, ...).
Patterns add ("meta", name) and ("eval", tree).
"""

from fractions import Fraction

MAX_TOKENS = 64
MAX_DIGITS = 8
MAX_DEPTH = 16
MAX_EXPONENT = 6
MAX_EQUATIONS = 4
ROOT_SIGN = "\u221a"
PLUS_MINUS = "\u00b1"
AT_MOST = "\u2264"
AT_LEAST = "\u2265"
RELATIONS = {"=": "eq", "lt": "lt", "le": "le", "gt": "gt", "ge": "ge"}


class Unreadable(Exception):
    """A line outside the fragment, with a reason code from SEMANTICS.md."""

    def __init__(self, reason):
        super().__init__(reason)
        self.reason = reason


def tokenize(line, var, others="", imaginary=False, logs=False):
    tokens = []
    i = 0
    while i < len(line):
        c = line[i]
        if c == " ":
            i += 1
        elif c.isdigit() or c == ".":
            j = i
            while j < len(line) and (line[j].isdigit() or line[j] == "."):
                j += 1
            word = line[i:j]
            if word.count(".") > 1 or word.endswith("."):
                raise Unreadable("unparsed")
            if sum(ch.isdigit() for ch in word) > MAX_DIGITS:
                raise Unreadable("literal_too_long")
            tokens.append(("num", Fraction(word)))
            i = j
        elif var != "o" and line[i:i + 2] == "or":
            tokens.append(("or",))
            i += 2
        elif c == ROOT_SIGN or line[i:i + 4] == "sqrt":
            tokens.append(("sqrt",))
            i += 1 if c == ROOT_SIGN else 4
        elif line[i:i + 3] == "abs":
            tokens.append(("abs",))
            i += 3
        elif c == PLUS_MINUS:
            tokens.append(("pm",))
            i += 1
        elif c == AT_MOST:
            tokens.append(("le",))
            i += 1
        elif c == AT_LEAST:
            tokens.append(("ge",))
            i += 1
        elif c in "<>":
            loose = line[i + 1 : i + 2] == "="
            tokens.append(({"<": "le", ">": "ge"}[c] if loose else {"<": "lt", ">": "gt"}[c],))
            i += 2 if loose else 1
        elif c == var:
            tokens.append(("var",))
            i += 1
        elif logs and line[i:i + 3] == "log":
            tokens.append(("log",))
            i += 3
        elif logs and line[i:i + 2] == "ln":
            tokens.append(("ln",))
            i += 2
        elif logs and c == "e":
            tokens.append(("e",))
            i += 1
        elif imaginary and c == "i":
            tokens.append(("i",))
            i += 1
        elif c in others:
            tokens.append(("y" if c == others[0] else "z",))
            i += 1
        elif c in "+-*/=()^|" or (c == "," and others):
            tokens.append((c,))
            i += 1
        elif c.isalpha():
            raise Unreadable("unknown_symbol")
        else:
            raise Unreadable("unparsed")
    if len(tokens) > MAX_TOKENS:
        raise Unreadable("too_many_tokens")
    return tokens


class Parser:
    def __init__(self, tokens, plus_minus="add", logs=False):
        self.tokens = tokens
        self.logs = logs
        self.at = 0
        self.plus_minus = plus_minus
        self.in_bars = False

    def kind(self, offset=0):
        i = self.at + offset
        return self.tokens[i][0] if i < len(self.tokens) else None

    def take(self):
        token = self.tokens[self.at]
        self.at += 1
        return token

    def expression(self, depth):
        if depth > MAX_DEPTH:
            raise Unreadable("too_deep")
        left = self.term(depth)
        while self.kind() in ("+", "-", "pm"):
            op = {"+": "add", "-": "sub", "pm": self.plus_minus}[self.take()[0]]
            left = (op, left, self.term(depth))
        return left

    def multiplies_next(self):
        kind = self.kind()
        return (kind in ("var", "y", "z", "i", "e", "log", "ln", "sqrt", "abs", "(")
                or (kind == "|" and not self.in_bars))

    def term(self, depth):
        left = self.unary(depth)
        while True:
            kind = self.kind()
            if kind == "*":
                self.take()
                left = ("mul", left, self.unary(depth))
            elif kind == "/":
                self.take()
                right = self.unary(depth)
                # 1/2x could mean (1/2)x or 1/(2x), so it is a question, not a guess.
                if self.multiplies_next():
                    raise Unreadable("ambiguous_division")
                left = ("div", left, right)
            elif self.multiplies_next():
                left = ("mul", left, self.power(depth))
            else:
                return left

    def unary(self, depth):
        if self.kind() == "-":
            self.take()
            return self.negative(self.unary(depth))
        if self.kind() == "pm":
            self.take()
            inner = self.unary(depth)
            return inner if self.plus_minus == "add" else self.negative(inner)
        return self.power(depth)

    @staticmethod
    def negative(inner):
        if inner[0] == "num":
            return ("num", -inner[1])
        return ("neg", inner)

    def power(self, depth):
        base = self.atom(depth)
        if self.kind() != "^":
            return base
        self.take()
        if self.logs:
            return self.free_power(base, depth)
        if self.kind() != "num":
            raise Unreadable("unparsed")
        exponent = self.take()[1]
        if exponent.denominator != 1 or not 1 <= exponent <= MAX_EXPONENT:
            raise Unreadable("exponent_range")
        return ("pow", base, int(exponent))

    def free_power(self, base, depth):
        """An exponent in a task with logarithms: a number or bracket, and maybe a minus sign."""
        if self.kind() == "-":
            self.take()
            exponent = self.negative(self.atom(depth))
        else:
            exponent = self.atom(depth)
        plain = exponent[0] == "num" and exponent[1].denominator == 1 and 1 <= exponent[1] <= MAX_EXPONENT
        if plain and base[0] != "e":
            return ("pow", base, int(exponent[1]))
        return ("exp", base, exponent)

    def base_in_brackets(self):
        """Is the bracket after log a base, with a second bracket after it?"""
        if self.kind() != "(":
            return False
        level = 0
        i = 0
        while self.kind(i) is not None:
            level += {"(": 1, ")": -1}.get(self.kind(i), 0)
            if level == 0:
                return self.kind(i + 1) == "("
            i += 1
        return False

    def log_base(self, depth):
        if self.kind() == "num":
            return self.take()[1]
        if not self.base_in_brackets():
            return Fraction(10)
        tree = self.atom(depth)
        if tree[0] == "num":
            return tree[1]
        if tree[0] == "div" and tree[1][0] == "num" and tree[2][0] == "num" and tree[2][1] != 0:
            return tree[1][1] / tree[2][1]
        raise Unreadable("log_base")

    def atom(self, depth):
        kind = self.kind()
        if kind == "log":
            self.take()
            base = self.log_base(depth)
            return ("log", base, self.atom(depth))
        if kind == "ln":
            self.take()
            return ("log", "e", self.atom(depth))
        if kind == "num":
            return self.take()
        if kind in ("var", "y", "z", "i", "e"):
            return self.take()
        if kind == "sqrt":
            self.take()
            return ("sqrt", self.atom(depth))
        if kind == "abs":
            self.take()
            return ("abs", self.atom(depth))
        if kind == "|" and not self.in_bars:
            self.take()
            self.in_bars = True
            inner = self.expression(depth + 1)
            self.in_bars = False
            if self.kind() != "|":
                raise Unreadable("unparsed")
            self.take()
            return ("abs", inner)
        if kind == "(":
            self.take()
            inner = self.expression(depth + 1)
            if self.kind() != ")":
                raise Unreadable("unparsed")
            self.take()
            return inner
        raise Unreadable("unparsed")


def same_way(a, b):
    return (a in ("lt", "le") and b in ("lt", "le")) or (a in ("gt", "ge") and b in ("gt", "ge"))


def parse_relation(parser):
    left = parser.expression(0)
    head = RELATIONS.get(parser.kind())
    if head is None:
        raise Unreadable("unparsed")
    parser.take()
    middle = parser.expression(0)
    following = RELATIONS.get(parser.kind())
    if following is None:
        return (head, left, middle)
    if not same_way(head, following):
        raise Unreadable("chain")
    parser.take()
    return ("and", (head, left, middle), (following, middle, parser.expression(0)))


def parse_line(line, var="x", imaginary=False, logs=False):
    """An ("eq", left, right) tree exactly as typed, or ("or", equation, ...). Nothing is simplified.

    One plus-or-minus sign on a line that has no `or` is the two alternatives it stands for.
    """
    tokens = tokenize(line, var, imaginary=imaginary, logs=logs)
    signs = sum(token[0] == "pm" for token in tokens)
    if signs == 0:
        return parse_tokens(tokens, "add", logs)
    if signs > 1 or ("or",) in tokens:
        raise Unreadable("unparsed")
    return ("or", parse_tokens(tokens, "add", logs), parse_tokens(tokens, "sub", logs))


def parse_expression_line(line, var="x", imaginary=False, logs=False):
    """The tree of an expression exactly as typed. A line with an equals sign here is unparsed."""
    tokens = tokenize(line, var, imaginary=imaginary, logs=logs)
    parser = Parser(tokens, logs=logs)
    tree = parser.expression(0)
    if parser.kind() is not None or ("pm",) in tokens:
        raise Unreadable("unparsed")
    return tree


def parse_system(line, names):
    """The (left, right) sides of each equation of a system in the letters of `names`."""
    parser = Parser(tokenize(line, names[0], names[1:]))
    equations = []
    while True:
        left = parser.expression(0)
        if parser.kind() != "=":
            raise Unreadable("unparsed")
        parser.take()
        equations.append((left, parser.expression(0)))
        if parser.kind() is None:
            break
        if parser.kind() == "=":
            raise Unreadable("chain")
        if parser.kind() != ",":
            raise Unreadable("unparsed")
        parser.take()
    if len(equations) > MAX_EQUATIONS:
        raise Unreadable("too_many_equations")
    return equations


def parse_tokens(tokens, plus_minus, logs=False):
    parser = Parser(tokens, plus_minus, logs)
    equations = [parse_relation(parser)]
    while parser.kind() == "or":
        parser.take()
        equations.append(parse_relation(parser))
    if parser.kind() is not None:
        raise Unreadable("chain" if parser.kind() in RELATIONS else "unparsed")
    return equations[0] if len(equations) == 1 else ("or", *equations)


# The rule file is S-expressions, so the Lisp reader can load it unchanged at M3.

OPERATORS = {"+": "add", "-": "sub", "*": "mul", "/": "div", "neg": "neg", "sqrt": "sqrt", "=": "eq",
             "or": "or", "and": "and", "abs": "abs", "<": "lt", "<=": "le"}


def read_forms(text):
    tokens = []
    i = 0
    while i < len(text):
        c = text[i]
        if c.isspace():
            i += 1
        elif c == ";":
            i = text.index("\n", i)
        elif c in "()":
            tokens.append(c)
            i += 1
        elif c == '"':
            j = text.index('"', i + 1)
            tokens.append(("string", text[i + 1 : j]))
            i = j + 1
        else:
            j = i
            while j < len(text) and not text[j].isspace() and text[j] not in '()";':
                j += 1
            tokens.append(("atom", text[i:j]))
            i = j
    forms = []
    stack = [forms]
    for token in tokens:
        if token == "(":
            stack.append([])
        elif token == ")":
            done = stack.pop()
            stack[-1].append(done)
        else:
            stack[-1].append(token[1] if token[0] == "string" else token[1])
    if len(stack) != 1:
        raise ValueError("unbalanced parentheses in rule file")
    return forms


def pattern_tree(form):
    if isinstance(form, list):
        if form[0] == "eval":
            return ("eval", pattern_tree(form[1]))
        if form[0] == "^":
            return ("pow", pattern_tree(form[1]), int(form[2]))
        return (OPERATORS[form[0]], *[pattern_tree(item) for item in form[1:]])
    if form.startswith("?"):
        return ("meta", form)
    return ("num", Fraction(form))


def metas(tree):
    found = set()
    if tree[0] == "meta":
        found.add(tree[1])
    elif tree[0] not in ("num", "var"):
        for child in tree[1:]:
            if isinstance(child, tuple):
                found |= metas(child)
    return found
