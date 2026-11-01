# R2-01 Common Lisp Engine Architect

1. D3: `((((9^6)^6)^6)^6)^6…` fits 64 tokens and depth 16. Degree cap ignores constants; one POST hangs the server (`3^20000000` took 70 s). Fix: restore 4096-bit precheck before every multiply and `expt`; over means OOF `limit`.

2. D13: `2x=6 → 0=0` has no root, so "this line has no solution" is false. `x=x → x=1`: substituting 1 shows nothing. Fix: branch on empty, all-reals, identity previous; witness is a point where the lines disagree.

3. D3: `x(x-1)(x²-2)=0 → x=0` loses {1, ±√2}, not "irrational-only". Payload {1} is false; Lean's `Sol A = Sol B ∪ S` fails. Fix: any irrational member in the difference or AllExcept is OOF.
