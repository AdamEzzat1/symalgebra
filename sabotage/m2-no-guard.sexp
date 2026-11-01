;;; mul-zero with its guard removed. SymPy alone would pass this: only strict evaluation fails it.
(rule mul-zero-unguarded :level expr :class equivalence
  :pattern (* ?a 0) :replacement 0
  :guards () :params ()
  :explanation "Wrong on purpose."
  :skills (identities) :mal nil
  :positive (("(x + 1) * 0 = x" "0 = x"))
  :negative (("x = 1" "x = 2")))
