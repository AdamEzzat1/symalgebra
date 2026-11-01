# R1-02 Prolog critique

**(a) Strongest.** Role 4: ties resolve to valid only under EQUIVALENT. `x/(x-1)=1/(x-1) → x=1` matches a rule yet GAINS, so the brief's tie rule would bless a wrong step.

**(b) Most dangerous.** Role 6's 2M inference limit beside a 150 ms wall budget. 1M took about 11 ms, so 2M is about 22 ms locally. If 0.1 CPU scales linearly (unmeasured) that is 220 ms, and the wall kill fires first. A long equation then means SIGKILL, slow respawn, and `unavailable` for queued students, losing the limit's determinism. Calibrate the limit on the host, below the wall budget.

**(c) Conflict.** Role 1 wins. Lisp already needs `flat`, folding, guards and a matcher for rperft, so my Prolog matchers duplicate it. Lisp enumerates sound, mal and failed-guard edges (depth at most 2), including parameter sources and ordered matching. Prolog receives edges and rule facts, then chooses derivations, keeps hypotheses, replays, renders. One call. Cost: no second matcher as cross-check; rule examples must cover it.

**(d) Retract.** Two-call protocol; generated Prolog matchers; my risk 2; `read_term` (Role 6's line framing); "mal-rules never touch a valid step": Role 4's `2x=4 → x=4-2` needs non-rejecting annotation once sound search fails.
