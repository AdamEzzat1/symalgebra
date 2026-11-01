# R0-07 Frontend and Protocol

**Input: plain text only for M1.** One labelled `<input type="text">` per step, autocorrect and capitalisation off, plus a native-button key row (`x = + − ( ) /`), since phone keyboards hide `=`. A native field is the safest screen-reader path. MathLive has open NVDA input and repeated-reading issues, changed its ARIA role only on 30 September, costs 217 kB gzipped, and adds a LaTeX parser to Lisp. STACK defaults to plain text with echo-back. Revisit MathLive at fractions.

**Display.** The browser never parses maths. Lisp returns its reading as MathML plus a spoken string. Drop KaTeX. `1/2x` gets "add brackets", never a guess.

**Framework: none.** One HTML, one CSS, one `// @ts-check` module with a pure reducer tested by `node --test`. No build.

**Checker: SBCL, a small M1 function in the one container.** It parses the M1 grammar, reduces each side to exact rational a·x+b, and compares solution sets with the problem's. Variable denominators, x², other letters: OUT_OF_FRAGMENT. Rejection substitutes the student's own root into the original equation, hiding the answer. The browser only sends text and renders the returned enum, so Lisp alone decides. JavaScript numeric checks would be a second truth using floats; authored-path matching would mark valid steps wrong. Evidence is thin (golden tests, SymPy comparison), so the page says "prototype". Hints are authored display text.

**Transport.** `POST /api/check {"v":1,"problem":"lin-07","text":"2x=6"}`, 512-byte cap. POST keeps steps out of URLs and access logs. HTTP, not WebSocket: stateless needs no `seq`. Parse failure is a separate `unparsed` reply with column, because it is M1's metric.

**Stale guard.** Check on Enter or button only. Each send increments `token` and aborts the previous request. A reply applies only if token, problem and field text still match; editing cancels. Lines commit only on verdict. Timeouts and unknown replies say "not checked", never wrong.

**Self-host.** Everything; system fonts. CSP `default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'`.

**Risks.**
1. Phone typing fakes "won't type steps". Report devices separately; phone-only failure redesigns input, not the project.
2. The M1 checker grows into an unreviewed M3 core. Discard it at M3.
3. Free-host cold starts and edge IP logs. Measure before recruiting.

**Cut.** Both libraries, React, Vite, live preview, localStorage.

**Brief problems.** Measuring input failure conflicts with "no stored data": tallies stay in browser memory until an adult presses Export; the owner must accept that. The endpoint needs explicit approval. `0=1` has no root of its own, so "show a root" reveals the answer.

**Verified today.** MathLive 0.111.4, MIT, active, three releases today, one author about 80% of commits. KaTeX 0.19.1, MIT, 75 kB gzipped. MathML Baseline since January 2023.
**Assumed.** Phone keyboards, screen-reader MathML, Android fonts, hosting. No device tested.
