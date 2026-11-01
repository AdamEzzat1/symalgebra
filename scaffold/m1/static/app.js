"use strict";
// M1 page. It shows what the server says and holds no algebra: it never decides whether a
// line is right. Counters live in this tab only and leave it only if the tester copies them.

const SESSION_SIZE = { single: 3, multi: 6 };
const el = (id) => document.getElementById(id);

const state = {
  code: "",
  queue: [],
  at: 0,
  records: [],
  lines: [],
  solved: false,
  token: 0,
  abort: null,
  lastAccepted: false,
  hintLevel: 0,
};

const current = () => state.queue[state.at];
const record = () => state.records[state.at];
const previousLine = () => state.lines[state.lines.length - 1];

function shuffled(items) {
  const copy = items.slice();
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

// Failed lines leave the page only as token shapes, never as typed.
function shape(text, variable) {
  let out = "";
  for (const token of text.match(/\d+|[\s\S]/g) || []) {
    if (/^\d+$/.test(token)) out += "9";
    else if (token === variable) out += "x";
    else if (token === " ") continue;
    else if ("+-*/=().".includes(token)) out += token;
    else out += "?";
  }
  return out.slice(0, 256);
}

function allowed(text, variable) {
  for (const c of text) {
    if (!(/[0-9+\-*/=(). ]/.test(c) || c === variable)) return false;
  }
  return true;
}

function noteInputFailure(text) {
  record().input_failures += 1;
  record().failed_shapes.push(shape(text, current().var));
}

async function post(path, body, signal) {
  const response = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ v: 1, ...body }),
    signal,
  });
  return response.json();
}

function clearReply() {
  el("echo-row").hidden = true;
  el("show-why").hidden = true;
  el("why").hidden = true;
  el("message").textContent = "";
  el("message").className = "";
  state.lastAccepted = false;
}

function say(text, kind) {
  el("message").textContent = text;
  el("message").className = kind || "";
}

function cancelPending() {
  state.token += 1;
  if (state.abort) state.abort.abort();
  state.abort = null;
}

function renderLines() {
  const list = el("lines");
  list.replaceChildren();
  for (const line of state.lines) {
    const item = document.createElement("li");
    item.textContent = line;
    list.append(item);
  }
}

function renderKeys() {
  const keys = el("keys");
  keys.replaceChildren();
  const symbols = [current().var, ..."+-*/=().0123456789"];
  for (const symbol of symbols) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = symbol;
    button.addEventListener("click", () => insert(symbol));
    keys.append(button);
  }
}

function insert(symbol) {
  const input = el("line");
  const start = input.selectionStart ?? input.value.length;
  const end = input.selectionEnd ?? start;
  input.setRangeText(symbol, start, end, "end");
  input.focus();
  input.dispatchEvent(new Event("input"));
}

function finishProblem() {
  state.solved = true;
  record().solved = true;
  setClosed(true);
  el("next").hidden = false;
  el("next").textContent = state.at + 1 < state.queue.length ? "Next problem" : "Finish";
  el("next").focus();
}

function setClosed(closed) {
  for (const id of ["line", "check", "claim-none", "claim-all", "hint"]) el(id).disabled = closed;
}

function reopenProblem() {
  state.solved = false;
  record().solved = false;
  setClosed(false);
  el("next").hidden = true;
}

async function showWorkedLine() {
  if (current().kind !== "worked" || state.solved) return;
  const reply = await post("/api/hint", {
    problem: current().id,
    previous: previousLine(),
    level: 3,
  }).catch(() => null);
  el("worked").textContent = reply && reply.status === "hint"
    ? `Worked example, not counted. Type this line, then press Check: ${reply.text}`
    : "Worked example, not counted.";
  el("worked").hidden = false;
}

function showProblem() {
  cancelPending();
  const problem = current();
  state.lines = [problem.start];
  state.solved = false;
  state.hintLevel = 0;
  el("progress").textContent = `Problem ${state.at + 1} of ${state.queue.length}`;
  el("worked").hidden = true;
  el("hint-text").hidden = true;
  el("next").hidden = true;
  el("line").value = "";
  setClosed(false);
  clearReply();
  renderLines();
  renderKeys();
  showWorkedLine();
  el("line").focus();
}

function applyCheck(reply, text) {
  if (reply.status === "unparsed") {
    noteInputFailure(text);
    say(`I could not read this line. Look near character ${reply.column}.`, "bad");
    const at = Math.max(reply.column - 1, 0);
    el("line").focus();
    el("line").setSelectionRange(at, at + 1);
    return;
  }
  if (reply.status === "out_of_fragment") {
    record().out_of_fragment += 1;
    say("Not checked. This test only covers lines with no letter in a bottom part and no letter multiplied by a letter.");
    return;
  }
  if (reply.status !== "checked" || typeof reply.verdict !== "string") {
    say("Not checked. Please try again.");
    return;
  }
  el("echo").textContent = reply.echo;
  el("echo-row").hidden = false;
  if (reply.verdict === "equivalent") {
    state.lines.push(reply.echo);
    state.lastAccepted = true;
    if (reply.done !== true) record().intermediate_lines += 1;
    renderLines();
    el("line").value = "";
    el("hint-text").hidden = true;
    state.hintLevel = 0;
    if (reply.done === true) {
      say("Solved.", "good");
      finishProblem();
    } else {
      say("That step holds. What comes next?", "good");
      showWorkedLine();
    }
    return;
  }
  if (reply.verdict === "different") {
    say(reply.message, "bad");
    if (reply.why) {
      el("why").textContent = reply.why;
      el("show-why").hidden = false;
    }
    return;
  }
  say("Not checked. Please try again.");
}

async function check() {
  const text = el("line").value;
  if (text.trim() === "" || state.solved) return;
  cancelPending();
  clearReply();
  const problem = current();
  record().attempts += 1;
  if (!allowed(text, problem.var)) {
    noteInputFailure(text);
    say(`This line has a character I cannot read. Use numbers, ${problem.var}, and + - * / = ( ) .`, "bad");
    return;
  }
  const token = state.token;
  const controller = new AbortController();
  state.abort = controller;
  try {
    const reply = await post(
      "/api/check",
      { problem: problem.id, previous: previousLine(), text },
      controller.signal,
    );
    // A reply counts only if nothing has moved on since it was asked for.
    if (token === state.token && problem === current() && text === el("line").value) {
      applyCheck(reply, text);
    }
  } catch (error) {
    if (error.name !== "AbortError" && token === state.token) {
      say("Not checked. Please try again.");
    }
  }
}

async function claim(name) {
  if (state.solved) return;
  cancelPending();
  clearReply();
  const problem = current();
  const token = state.token;
  // A button press is not an attempt in the M1 measures, so it has its own counter.
  record().claims += 1;
  try {
    const reply = await post("/api/check", { problem: problem.id, claim: name });
    if (token !== state.token || problem !== current()) return;
    if (reply.status === "checked" && reply.done === true) {
      say("Solved.", "good");
      finishProblem();
    } else if (reply.status === "checked" && typeof reply.message === "string") {
      say(reply.message, "bad");
    } else {
      say("Not checked. Please try again.");
    }
  } catch {
    say("Not checked. Please try again.");
  }
}

async function hint() {
  if (state.solved) return;
  const level = Math.min(state.hintLevel + 1, 3);
  const box = el("hint-text");
  // The last hint gives the line, so it waits for one attempt and has to be retyped.
  if (level === 3 && record().attempts + record().claims === 0) {
    box.textContent = "Try a line first, then ask again.";
    box.className = "panel";
    box.hidden = false;
    return;
  }
  const problem = current();
  const from = previousLine();
  let reply = null;
  try {
    reply = await post("/api/hint", { problem: problem.id, previous: from, level });
  } catch {
    reply = null;
  }
  if (problem !== current() || from !== previousLine()) return;
  if (!reply || reply.status !== "hint") {
    box.textContent = "No hint is available right now.";
    box.className = "panel";
    box.hidden = false;
    return;
  }
  state.hintLevel = level;
  record().hints = Math.max(record().hints, level);
  if (level === 3) record().bottom_out = true;
  box.textContent = reply.text;
  box.className = level === 3 ? "panel no-select" : "panel";
  box.hidden = false;
}

function notMeant() {
  const text = el("echo").textContent;
  noteInputFailure(text);
  record().not_meant += 1;
  if (state.lastAccepted && state.lines.length > 1) {
    state.lines.pop();
    if (state.solved) reopenProblem();
    else if (record().intermediate_lines > 0) record().intermediate_lines -= 1;
    renderLines();
  }
  clearReply();
  el("line").focus();
}

function finishSession() {
  cancelPending();
  el("work").hidden = true;
  el("end").hidden = false;
  el("summary").value = JSON.stringify(
    { v: 1, code: state.code, problems: state.records.filter((r) => r.opened) },
    null,
    1,
  );
}

async function begin() {
  const code = el("code").value.trim();
  if (!/^[A-Za-z0-9]{1,12}$/.test(code)) {
    el("intro-note").textContent = "Please enter the code: letters and numbers only.";
    el("intro-note").hidden = false;
    return;
  }
  let list = null;
  try {
    const response = await fetch("/api/problems");
    list = (await response.json()).problems;
  } catch {
    list = null;
  }
  if (!Array.isArray(list)) {
    el("intro-note").textContent = "The test could not start. Please try again.";
    el("intro-note").hidden = false;
    return;
  }
  const of = (kind) => shuffled(list.filter((p) => p.kind === kind));
  state.code = code;
  state.queue = [
    ...of("worked").slice(0, 1),
    ...shuffled([...of("single").slice(0, SESSION_SIZE.single), ...of("multi").slice(0, SESSION_SIZE.multi)]),
  ];
  state.records = state.queue.map((p, i) => ({
    position: i,
    id: p.id,
    kind: p.kind,
    opened: i === 0,
    attempts: 0,
    claims: 0,
    input_failures: 0,
    failed_shapes: [],
    not_meant: 0,
    out_of_fragment: 0,
    intermediate_lines: 0,
    hints: 0,
    bottom_out: false,
    solved: false,
  }));
  state.at = 0;
  el("intro").hidden = true;
  el("work").hidden = false;
  showProblem();
}

async function copySummary() {
  const box = el("summary");
  const note = el("copy-note");
  try {
    await navigator.clipboard.writeText(box.value);
    note.textContent = "Copied.";
  } catch {
    // Clipboard access needs HTTPS, so on a LAN the tester selects the text instead.
    box.focus();
    box.select();
    note.textContent = "Copying is blocked here. The text is selected, so copy it by hand.";
  }
  note.hidden = false;
}

el("begin").addEventListener("click", begin);
el("code").addEventListener("keydown", (event) => {
  if (event.key === "Enter") begin();
});
el("entry").addEventListener("submit", (event) => {
  event.preventDefault();
  check();
});
el("line").addEventListener("input", () => {
  cancelPending();
  clearReply();
});
el("claim-none").addEventListener("click", () => claim("none"));
el("claim-all").addEventListener("click", () => claim("all"));
el("hint").addEventListener("click", hint);
el("not-meant").addEventListener("click", notMeant);
el("show-why").addEventListener("click", () => {
  el("why").hidden = false;
  el("show-why").hidden = true;
});
el("next").addEventListener("click", () => {
  if (state.at + 1 >= state.queue.length) {
    finishSession();
    return;
  }
  state.at += 1;
  record().opened = true;
  showProblem();
});
el("stop").addEventListener("click", finishSession);
el("copy").addEventListener("click", copySummary);
