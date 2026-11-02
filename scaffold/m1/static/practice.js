"use strict";
// Practice page. It shows what the server says and holds no algebra: it never decides whether a
// line is right. Nothing is counted or kept.

const AREAS = [
  { id: "distribution", title: "Distribution and like terms" },
  { id: "fractions", title: "Fractions" },
];
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
  const symbols = [current().var, ..."+-*/=().0123456789"];
  el("keys").replaceChildren(...symbols.map((symbol) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = symbol;
    button.addEventListener("click", () => insert(symbol));
    return button;
  }));
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
  el("hint-text").hidden = true;
  el("next").hidden = true;
  el("line").value = "";
  setClosed(false);
  clearReply();
  renderLines();
  renderKeys();
  el("line").focus();
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
    if (!text.endsWith("solution") && !text.endsWith("numbers")) {
      state.lines.push(text);
      renderLines();
      el("line").value = "";
    }
    el("hint-text").hidden = true;
    state.hintLevel = 0;
    showExplanations(reply.explanations || []);
    if (reply.solved === true) finishProblem();
    else say("That step holds. What comes next?", "good");
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
el("claim-all").addEventListener("click", () => submit("all real numbers"));
el("hint").addEventListener("click", hint);
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
