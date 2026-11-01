# R0-06 Lisp-Prolog integration

**Recommendation: one long-lived `swipl` child, no pool.** Four children raised throughput (414 to 920 req/s) only because this laptop has spare cores. Free hosts reportedly offer 0.1 CPU. Add a second only if hosted queue-full exceeds 1%.

**Order.** Lisp computes the verdict first. Prolog receives it read-only and returns rule ids, hypotheses and template arguments, never a verdict. Lisp drops unknown ids.

**Wire.** One UTF-8 line each way, 64 KB cap. Request: a Prolog term printed from Lisp's tree, never student text. Reply: JSON. Prolog must read lines and then `term_string`: with `read_term`, an unterminated term gave no reply in 1 s; line framing returned `bad_request` immediately. Startup `hello(Proto, RulesetDigest)`; mismatch keeps Prolog off.

**Ids.** Integer per child generation, one request in flight, no pipelining. Id mismatch means kill, never resync.

**Timeouts.** `call_with_inference_limit` at 2M first (1M took about 11 ms), so outcomes do not vary with load. Then a 150 ms wall budget including queue wait, then SIGKILL and respawn. Stack limits are no substitute: exhaustion took 2.3-2.6 s at 16 MB and 64 MB.

**Concurrency.** One owner thread with a FIFO, depth 4; full means immediate `unavailable`. Not a mutex: saturated, 8 callers saw 8.6-10.8 s worst case against 49 ms FIFO. With 20 ms think time they matched. Drain and discard stderr, unlogged: undrained, 6.5 MB wedged the child.

**Prolog dies.** The response still carries verdict and Lisp's counterexample. `explanation` is `ok`, `none` or `unavailable`. `unavailable` reads "Correct. Explanation unavailable right now." It must never become "valid, method unnamed"; only `none` means that, and only `none` counts as a coverage gap.

**Cold start.** Saved state: 77 ms p50 (source 153 ms), respawn 44 ms, SBCL 50 ms. Render's documented 15-minute spin-down, and reported 30-60 s wake, dwarf this. Listen before `hello`; early requests get `unavailable`.

**Risks.**
1. Real rules cost unknown. Mock: 40 patterns, 1 KB, about 2-3 ms p50, 17 MB.
2. Linux unmeasured: SIGKILL, PID 1 reaping, 0.1 CPU.
3. Graceful fallback hides a dead child. Count `unavailable` and restarts. One child exited 143 once, unexplained.

**Cut.** Pool, cache, WebSocket, Prolog threads, automatic retries, and all Prolog before M5, except a `hello` smoke test.

**Will not work in the brief.**
- "Logged as a rule-coverage test case" conflicts with no request bodies in logs. Count hashes at runtime; collect cases from corpus only.
- The M3 100 ms gate predates Prolog. Measure verdict and explanation separately, excluding platform wake.

**Verified** (this Windows machine only, SBCL 2.6.9, swipl 10.0.2): all millisecond figures, mutex, stderr, kill, 200k atoms (17.0 to 17.7 MB).
**Assumed:** Linux behaviour, 0.1 CPU scaling, real rule cost, 2M limit suiting real rules. Render CPU and wake are third-party.
