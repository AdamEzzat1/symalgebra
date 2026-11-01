# R2-02 Prolog

1. **Edge volume.** My 8-rule probe sent 47 KB at depth 2. Full rules plus replay likely exceed Role 6's 64 KB cap, giving `unavailable` on long equations. Fix: send only edges whose `flat` result equals After's.
2. **Retyping.** A rejected line retyped counts as two steps, so one error gets named. Fix: key evidence on (Before, mal id).
3. **D4.** A line accepted via vs_start can be GAINS against previous; Prolog then diagnoses an accepted line. Fix: send the accepted flag; suppress mal edges.

**Honest work?** Yes, but thin: hypothesis policy, replay, rendering. After fix 1, nothing needs search or unification. M5 must show it.
