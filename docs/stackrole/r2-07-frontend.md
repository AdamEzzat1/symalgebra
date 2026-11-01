# R2-07 Frontend

1. **D12/D4.** A stateless server needs the previous line in the request. Two 256-character lines exceed 512 bytes, so a valid step shows "not checked". Fix: send `previous`, cap 1 KB.

2. **D15/D16.** Stage A's phone uses plain HTTP over LAN. `navigator.clipboard` needs a secure context, so Copy fails and the export is lost. Fix: end screen also shows results in a selectable read-only textarea.

3. **D4/D13.** "Solved" states only a necessary condition, which every accepted line meets. `2x=6` could end a problem; `3=x` might not, corrupting step completion. Fix: solved means EQUIVALENT and the line is `x=` a literal or a literal `=x`, decided by Lisp.
