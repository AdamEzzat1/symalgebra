"use strict";
// Practice page. It shows what the server says and holds no algebra: it never decides whether a
// line is right. Nothing is counted or kept.

const AREAS = [
  { id: "linear", title: "Linear equations" },
  { id: "distribution", title: "Distribution and like terms" },
  { id: "fractions", title: "Fractions" },
  { id: "quadratics", title: "Quadratics" },
  { id: "inequalities", title: "Inequalities" },
  { id: "absolute", title: "Absolute value" },
  { id: "radicals", title: "Radical equations" },
  { id: "polynomials", title: "Higher polynomials" },
  { id: "rational", title: "Rational expressions" },
  { id: "systems", title: "Systems of equations" },
  { id: "complex", title: "Complex numbers" },
  { id: "exponents", title: "Exponents" },
  { id: "logarithms", title: "Logarithms" },
  { id: "functions", title: "Functions and graphs" },
];
const QUADRATIC_KEYS = [
  { label: "^", text: "^" },
  { label: "√", text: "sqrt(" },
  { label: "±", text: "±" },
  { label: "or", text: " or " },
];
const INEQUALITY_KEYS = [
  { label: "<", text: " < " },
  { label: ">", text: " > " },
  { label: "≤", text: " <= " },
  { label: "≥", text: " >= " },
  { label: "^", text: "^" },
  { label: "or", text: " or " },
];
const LOG_KEYS = [
  { label: "^", text: "^" },
  { label: "log", text: "log" },
  { label: "ln", text: "ln(" },
  { label: "e", text: "e" },
  { label: "<", text: " < " },
  { label: ">", text: " > " },
  { label: "or", text: " or " },
];
const EXTRA_KEYS = {
  functions: [{ label: ",", text: ", " }, { label: "√", text: "sqrt(" }, ...INEQUALITY_KEYS],
  exponents: LOG_KEYS,
  logarithms: LOG_KEYS,
  complex: [
    { label: "i", text: "i" },
    { label: "^", text: "^" },
    { label: "√", text: "sqrt(" },
    { label: "±", text: "±" },
    { label: "or", text: " or " },
    { label: "|", text: "|" },
  ],
  systems: [{ label: ",", text: ", " }],
  polynomials: INEQUALITY_KEYS,
  rational: INEQUALITY_KEYS,
  quadratics: QUADRATIC_KEYS,
  inequalities: INEQUALITY_KEYS,
  absolute: [{ label: "|", text: "|" }, ...INEQUALITY_KEYS],
  radicals: [{ label: "√", text: "sqrt(" }, ...INEQUALITY_KEYS],
};
const NOTES = {
  functions: "Put brackets around a fraction beside x, such as (3/2)x. Separate equations with a comma. A domain is written like x >= 2.",
  exponents: "Type a power with ^, and put a bracket around a whole exponent, such as x^(-2) or 8^(1/3).",
  logarithms: "Type log2(8) for base 2, log(100) for base 10, and ln(x) for base e. Keep a whole exponent in brackets, such as 2^(x + 1).",
  complex: "Type i for the square root of -1, such as 3 + 2i. Write a root beside it with a space, as in i sqrt(3).",
  systems: "Separate equations with a comma, such as x = 3, y = 2. You can write one equation at a time.",
  polynomials: "Write several answers with or, such as x = 1 or x = 2 or x = 3.",
  rational: "Put brackets around a whole top or bottom, such as (x + 1)/(x - 1).",
  quadratics: "Write two answers with or, such as x = 2 or x = -3. Type a square root as sqrt(5).",
  inequalities: "Write a range such as -1 < x < 3, and two pieces with or, such as x < -3 or x > 3. Type <= for at most and >= for at least.",
  absolute: "Type an absolute value with bars, such as |x - 3|. Write two answers with or.",
  radicals: "Type a root as sqrt(x + 3). Squaring can bring in a false answer, so test each answer in the first line.",
};
const CLAIMS = ["no solution", "all real numbers", "infinitely many"];
const GRAPH_SIZE = 10;
const el = (id) => document.getElementById(id);

const state = { problems: [], queue: [], at: 0, lines: [], solved: false, token: 0, hintLevel: 0 };

const current = () => state.queue[state.at];
const previousLine = () => state.lines[state.lines.length - 1];

async function post(path, body) {
  const response = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ v: 1, ...body }),
  });
  return response.json();
}

function clearReply() {
  el("message").textContent = "";
  el("message").className = "";
  el("explanations").replaceChildren();
  el("show-why").hidden = true;
  el("why").hidden = true;
}

function say(text, kind) {
  el("message").textContent = text;
  el("message").className = kind || "";
}

function showExplanations(items) {
  el("explanations").replaceChildren(...items.map((text) => {
    const item = document.createElement("li");
    item.textContent = text;
    return item;
  }));
}

function renderLines() {
  el("lines").replaceChildren(...state.lines.map((line) => {
    const item = document.createElement("li");
    item.textContent = line;
    return item;
  }));
}

function renderKeys() {
  const symbols = [...(current().vars || current().var), ..."+-*/=().0123456789"].map((text) => ({ label: text, text }));
  const extra = EXTRA_KEYS[current().area] || [];
  el("keys").replaceChildren(...[...symbols, ...extra].map((key) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = key.label;
    button.addEventListener("click", () => insert(key.text));
    return button;
  }));
  el("two-answers").textContent = NOTES[current().area] || "";
  el("two-answers").hidden = !NOTES[current().area];
}

function insert(symbol) {
  const input = el("line");
  const start = input.selectionStart ?? input.value.length;
  const end = input.selectionEnd ?? start;
  input.setRangeText(symbol, start, end, "end");
  input.focus();
}

function setClosed(closed) {
  for (const id of ["line", "check", "claim-none", "claim-all", "hint"]) el(id).disabled = closed;
}

function showProblem() {
  state.token += 1;
  state.lines = [current().start];
  state.solved = false;
  state.hintLevel = 0;
  el("progress").textContent = `Problem ${state.at + 1} of ${state.queue.length}`;
  el("prompt").textContent = current().ask || (current().prompt ? `${current().prompt} this expression, one line at a time.` : "");
  el("prompt").hidden = !el("prompt").textContent;
  el("claim-all").textContent = current().vars ? "Infinitely many solutions" : "All real numbers";
  const noClaims = Boolean(current().prompt) || ["complex", "exponents", "functions"].includes(current().area) || current().form === "value";
  el("claim-none").hidden = noClaims;
  el("claim-all").hidden = noClaims;
  el("hint-text").hidden = true;
  el("solution-box").hidden = true;
  el("solution").hidden = false;
  el("next").hidden = true;
  el("line").value = "";
  showGraph(current());
  setClosed(false);
  clearReply();
  renderLines();
  renderKeys();
  el("line").focus();
}

function parseNumber(text) {
  const [top, bottom] = text.split("/");
  return Number(top) / Number(bottom || 1);
}

// Each run of points the server gave, cut where a point is missing or far off the page.
function curves(points) {
  const runs = [];
  let run = [];
  for (const point of points) {
    const y = point.y === "" ? NaN : parseNumber(point.y);
    if (Number.isNaN(y) || Math.abs(y) > GRAPH_SIZE) {
      if (run.length > 1) runs.push(run);
      run = [];
    } else {
      run.push(`${parseNumber(point.x)},${-y}`);
    }
  }
  if (run.length > 1) runs.push(run);
  return runs;
}

function drawGraph(points) {
  const ns = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(ns, "svg");
  svg.setAttribute("viewBox", `${-GRAPH_SIZE} ${-GRAPH_SIZE} ${2 * GRAPH_SIZE} ${2 * GRAPH_SIZE}`);
  svg.setAttribute("role", "img");
  svg.setAttribute("aria-label", "Graph of the function");
  for (const [x1, y1, x2, y2] of [[-GRAPH_SIZE, 0, GRAPH_SIZE, 0], [0, -GRAPH_SIZE, 0, GRAPH_SIZE]]) {
    const axis = document.createElementNS(ns, "line");
    Object.entries({ x1, y1, x2, y2 }).forEach(([key, value]) => axis.setAttribute(key, value));
    axis.setAttribute("class", "axis");
    svg.append(axis);
  }
  for (const run of curves(points)) {
    const line = document.createElementNS(ns, "polyline");
    line.setAttribute("points", run.join(" "));
    line.setAttribute("class", "curve");
    svg.append(line);
  }
  el("graph").replaceChildren(svg);
  el("graph").hidden = false;
}

async function showGraph(problem) {
  el("graph").hidden = true;
  if (!problem.graph) return;
  let reply = null;
  try {
    reply = await post("/api/practice/graph", { problem: problem.id });
  } catch {
    reply = null;
  }
  if (problem === current() && reply && Array.isArray(reply.points)) drawGraph(reply.points);
}

function finishProblem() {
  state.solved = true;
  setClosed(true);
  say("Solved.", "good");
  el("next").hidden = state.at + 1 >= state.queue.length;
  if (el("next").hidden) el("back").focus();
  else el("next").focus();
}

function applyReply(reply, text) {
  if (reply.status === "accepted") {
    if (!CLAIMS.includes(text)) {
      state.lines.push(text);
      renderLines();
      el("line").value = "";
    }
    el("hint-text").hidden = true;
    state.hintLevel = 0;
    showExplanations(reply.explanations || []);
    if (reply.solved === true) finishProblem();
    else say("That step holds. What comes next?", "good");
    if (reply.note) el("message").textContent += ` ${reply.note}`;
    return;
  }
  if (reply.status === "caution") {
    state.lines.push(text);
    renderLines();
    el("line").value = "";
    showExplanations(reply.explanations || []);
    say(reply.message);
    return;
  }
  if (reply.status === "rejected") {
    say(reply.message, "bad");
    if (reply.why) {
      el("why").textContent = reply.why;
      el("show-why").hidden = false;
    }
    return;
  }
  say(reply.message || "Not checked. Please try again.");
}

async function submit(text) {
  if (state.solved) return;
  clearReply();
  state.token += 1;
  const token = state.token;
  const problem = current();
  try {
    const reply = await post("/api/practice/check", {
      problem: problem.id,
      previous: previousLine(),
      text,
    });
    if (token === state.token && problem === current()) applyReply(reply, text);
  } catch {
    if (token === state.token) say("Not checked. Please try again.");
  }
}

async function hint() {
  if (state.solved) return;
  const level = Math.min(state.hintLevel + 1, 2);
  const box = el("hint-text");
  const problem = current();
  const from = previousLine();
  let reply = null;
  try {
    reply = await post("/api/practice/hint", { problem: problem.id, previous: from, level });
  } catch {
    reply = null;
  }
  if (problem !== current() || from !== previousLine()) return;
  box.textContent = reply && typeof reply.text === "string" ? reply.text : "No hint is available right now.";
  state.hintLevel = level;
  box.hidden = false;
}

async function solution() {
  const problem = current();
  let reply = null;
  try {
    reply = await post("/api/practice/solution", { problem: problem.id });
  } catch {
    reply = null;
  }
  if (problem !== current()) return;
  if (!reply || !Array.isArray(reply.steps)) {
    el("solution-steps").replaceChildren();
    el("solution-ending").textContent = "The steps could not be loaded. Please try again.";
  } else {
    el("solution-steps").replaceChildren(...reply.steps.map((step) => {
      const item = document.createElement("li");
      const line = document.createElement("strong");
      line.textContent = step.line;
      const why = document.createElement("span");
      why.textContent = step.why;
      item.append(line, why);
      return item;
    }));
    el("solution-ending").textContent = reply.ending;
  }
  el("solution-box").hidden = false;
  el("solution").hidden = true;
}

function begin(area) {
  state.queue = state.problems.filter((problem) => problem.area === area);
  state.at = 0;
  el("choose").hidden = true;
  el("work").hidden = false;
  showProblem();
}

async function load() {
  let list = null;
  try {
    list = (await (await fetch("/api/practice/problems")).json()).problems;
  } catch {
    list = null;
  }
  if (!Array.isArray(list)) {
    el("areas").textContent = "The problems could not be loaded. Please reload the page.";
    return;
  }
  state.problems = list;
  el("areas").className = "row wrap";
  el("areas").replaceChildren(...AREAS.map((area) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = area.title;
    button.addEventListener("click", () => begin(area.id));
    return button;
  }));
}

el("entry").addEventListener("submit", (event) => {
  event.preventDefault();
  const text = el("line").value.trim();
  if (text !== "") submit(text);
});
el("line").addEventListener("input", clearReply);
el("claim-none").addEventListener("click", () => submit("no solution"));
el("claim-all").addEventListener("click", () => submit(current().vars ? "infinitely many" : "all real numbers"));
el("hint").addEventListener("click", hint);
el("solution").addEventListener("click", solution);
el("show-why").addEventListener("click", () => {
  el("why").hidden = false;
  el("show-why").hidden = true;
});
el("next").addEventListener("click", () => {
  state.at += 1;
  showProblem();
});
el("back").addEventListener("click", () => {
  state.token += 1;
  el("work").hidden = true;
  el("choose").hidden = false;
});
load();
