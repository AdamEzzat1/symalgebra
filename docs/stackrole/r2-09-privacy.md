# R2-09 Privacy

1. D16 guards exports, not transit: a typed name reaches Render in the POST. Fix: the page refuses to send characters outside the input alphabet, counting them locally. This is input handling, not algebra truth.
2. D15 bookings plus D16 "per-code" results: a name-to-slot list beside coded results re-identifies everyone. Fix: tester picks a random code; owner keeps no mapping and deletes bookings after sessions.
3. Scaffold crash prints a step into Render's 7-day logs. Fix: run the canary test against the hosted image first.

**Stage B: acceptable** if those fixes land, plus: no card, an 18+ statement, a notice that the host sees IPs and steps, D3 limits in the scaffold, service suspended outside slots.
