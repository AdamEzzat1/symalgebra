;;; A guard that is not on the closed list, so no generator or proof could rely on it.
(rule invented-guard :level expr :class equivalence
  :pattern (+ ?a 0) :replacement ?a
  :guards ((seems-fine ?a)) :params ()
  :explanation "Wrong on purpose."
  :skills (identities) :mal nil
  :positive (("x + 0 = 1" "x = 1"))
  :negative (("x = 1" "x = 2")))
