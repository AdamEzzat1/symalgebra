# R1-09 Privacy critique

**Strongest:** role 10's "no M1 deployment". Localhost removes platform IP logs, TLS exposure and the bandwidth risk at once.

**Most dangerous:** role 6's "count hashes at runtime". Short algebra strings are enumerable, so `2x+3=7` is recovered from its hash in seconds. Logged, those hashes become a step record on Render for 7 days. Use corpus cases and a plain integer gap count.

**Conflicts**
- Role 5's rejected strings: rejection is exactly where the allowlist has failed. "I'm Sara, 07700..." reaches the end screen, then an email, then P0n.txt, beside the sender's name. Any export: token shape only. Observers note the characters that failed, not the text.
- Hosting: not needed for M1. Run all sessions observed on the owner's machine; drop role 5's five unmoderated sessions and the export entirely. Cost: observer effect, and no own-device or phone test. Add an owner's test phone over LAN. Hosting first arrives at M3.
- Role 4's `no solution` tokens: accept them as exact whole-line matches, not letters.

**Retract**
- Render for M1, and "M1: IP at platform".
- "Blocks phones and SSNs": `555+0100` passes, so it only deters.
- 1 KB body: adopt role 7's 512 bytes.
