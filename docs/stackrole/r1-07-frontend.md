# R1-07 Frontend critique

**(a) Strongest.** Role 5's input-failure definition: parser rejection, or an accepted line flagged "not what I meant". It catches silent misreadings that my echo only displayed.

**(b) Most dangerous.** Role 5 counting silence as abandonment on a sleeping host. A tester opens the link after Render's 15-minute spin-down, sees nothing for a minute, closes the tab. No export, so a delivery failure scores as "will not type", and enough of these trip the stop rule. My one-container design serves the page from that sleeping server, and nothing can separate the cases, since we record nothing.

**(c) Conflict.** Role 10's localhost M1 loses phones; my hosted M1 meets (b). Settle: at least five observed sessions decide the gate, on the owner's laptop plus a real phone over the LAN, so no host sees steps. Hosted unmoderated sessions become a separate delivery test: silence is reported, never gate-counting. Exports use role 9's token shapes; role 5's raw strings could hold anything the allowlist rejected.

**(d) Retract.** MathML and the spoken string. With no brackets or fractions in role 5's bank, a plain-text echo suffices, removing two assumptions. Also 512 bytes: adopt role 9's 1 KB.
