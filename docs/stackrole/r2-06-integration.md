# R2-06 Integration attack on D7-D8

1. D7: Lisp fuel truncates edges on a long valid step. Prolog sees no sound edge, returns `none`: false "method unnamed", false gap. Fix: send `complete:false`; result is `unavailable`. Compute verdict before enumeration.

2. D8: host calibration makes explanations differ from CI, and throttled 0.1 CPU hits wall first anyway, causing kill-respawn storms. Fix: one pinned limit in ruleset; at wall budget answer `unavailable`, discard the late reply by id, kill only at 1 s.

3. D7 moves edges into the request. A wedged child stops reading, a large write blocks the owner thread, and its timer never fires. Fix: caller-side deadline plus watchdog kill. Unmeasured.
