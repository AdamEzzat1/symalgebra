# R1-10 Systems critique

**(a) Strongest.** Role 5: exact M1 definitions, a computed operating curve (true 30/50/80% pass 6/36/94%), and "need not" separated from "will not".

**(b) Most dangerous.** Role 8's `gate`: every job required, Lean included, no path filters. Failure: the Mathlib cache host fails or the 14 GB disk fills during M1; a tester-reported parser fix sits red, and M1 stalls on a job proving nothing it needs. Fix: Lean reports separately until M4.

**(c) Conflict.** I cut M1 deployment; Roles 5 and 9 want unmoderated testers on Render. A one-minute wake would count as abandonment and could falsely trigger stop. Settle: three observed sessions on localhost first, then five on Render in booked slots, owner waking it beforehand. Wake time is excluded, reported separately.

**(d) Retract.** "No M1 deployment"; my finish-only pass, adopting Role 5's step completion; MathLive retry, since Role 7's key row comes first.

**Cut.** From M0/M1: Role 8's `oracle`, mutator, weekly run, `spec-change` label; Role 3's guard-stripping and certificate mutation; Roles 1 and 4's Sturm, denominators, cofinite payloads (M2-M3 documents only); Role 2's protocol; Role 6's FIFO and respawn (Role 6 agrees); Role 5's raw strings unless the owner overrides Role 9's token shape.
