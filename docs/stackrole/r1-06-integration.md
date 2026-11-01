# R1-06 Integration critique

**(a) Strongest.** Role 4: `Finite|AllExcept` payload plus `vs_start`. It stops a correct solution of `x/(x-1)=1/(x-1)` being judged wrong.

**(b) Most dangerous.** Role 5's silence-counts-as-abandonment, combined with role 7's single container on role 9's Render. A rusty adult opens the link after spin-down, sees a blank page for a minute, and leaves. Four such visits trip the stop rule over hosting alone. Fix: owner wakes the host before agreed session windows; report unreachable sessions separately.

**(c) Conflict with role 2.** Keep my one HTTP request. Accept role 2's two calls as two stateless bridge round trips, each a separate FIFO entry, sharing one 150 ms deadline from first enqueue. Call 2 resends survivors; no child-side session. Child dies between calls: `unavailable`. Role 2's "on exhaustion the verdict stands, unnamed" must change: exhaustion is `unavailable`, never "method unnamed", and never a coverage gap. Replay also breaks role 7's 512-byte and role 9's 1 KB caps; those need raising.

**(d) Retract.**
- 64 KB wire cap: role 2 measured 47 KB at eight rules. Use a candidate-count cap; overflow is `unavailable`.
- Runtime hashes: short expressions can be brute-forced. CI only, as role 9 says.
