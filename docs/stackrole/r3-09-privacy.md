# R3-09 Privacy

ACCEPT, with two small changes to section 6.

1. "Input alphabet" is undefined, and typed `no solution` tokens (section 2) would need letters, so "a typed name never reaches the server" is false. Define it: digits, operators, the problem's variable. Make the two tokens buttons. Reword to "letters other than the variable never reach the server"; digits still can.
2. Locally refused lines fall outside "Input failure", so my own fix hides failures from the gate. Add "or a line refused locally" to that definition, and count each as an attempt.
