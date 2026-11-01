"""Readers for typed lines and the rule file. Independent of the Lisp engine by design.

Trees are tuples: ("num", Fraction), ("var",), ("add", a, b), ("sub", a, b), ("mul", a, b),
("div", a, b), ("neg", a), ("pow", a, n), ("eq", left, right). Patterns add ("meta", name)
and ("eval", tree).
"""

from fractions import Fraction

MAX_TOKENS = 64
MAX_DIGITS = 8
MAX_DEPTH = 16
MAX_EXPONENT = 6


class Unreadable(Exception):
    """A line outside the fragment, with a reason code from SEMANTICS.md."""

    def __init__(self, reason):
        super().__init__(reason)
        self.reason = reason


def tokenize(line, var):
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
        elif c == var:
            tokens.append(("var",))
            i += 1
        elif c in "+-*/=()^":
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
    def __init__(self, tokens):
        self.tokens = tokens
        self.at = 0

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
        while self.kind() in ("+", "-"):
            op = "add" if self.take()[0] == "+" else "sub"
            left = (op, left, self.term(depth))
        return left

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
                if self.kind() in ("var", "("):
                    raise Unreadable("ambiguous_division")
                left = ("div", left, right)
            elif kind in ("var", "("):
                left = ("mul", left, self.power(depth))
            else:
                return left

    def unary(self, depth):
        if self.kind() == "-":
            self.take()
            inner = self.unary(depth)
            if inner[0] == "num":
                return ("num", -inner[1])
            return ("neg", inner)
        return self.power(depth)

    def power(self, depth):
        base = self.atom(depth)
        if self.kind() != "^":
            return base
        self.take()
        if self.kind() != "num":
            raise Unreadable("unparsed")
        exponent = self.take()[1]
        if exponent.denominator != 1 or not 1 <= exponent <= MAX_EXPONENT:
            raise Unreadable("exponent_range")
        return ("pow", base, int(exponent))

    def atom(self, depth):
        kind = self.kind()
        if kind == "num":
            return self.take()
        if kind == "var":
            return self.take()
        if kind == "(":
            self.take()
            inner = self.expression(depth + 1)
            if self.kind() != ")":
                raise Unreadable("unparsed")
            self.take()
            return inner
        raise Unreadable("unparsed")


def parse_line(line, var="x"):
    """An ("eq", left, right) tree exactly as typed. Nothing is simplified."""
    parser = Parser(tokenize(line, var))
    left = parser.expression(0)
    if parser.kind() != "=":
        raise Unreadable("unparsed")
    parser.take()
    right = parser.expression(0)
    if parser.kind() is not None:
        raise Unreadable("chain" if parser.kind() == "=" else "unparsed")
    return ("eq", left, right)


# The rule file is S-expressions, so the Lisp reader can load it unchanged at M3.

OPERATORS = {"+": "add", "-": "sub", "*": "mul", "/": "div", "neg": "neg", "=": "eq"}


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
