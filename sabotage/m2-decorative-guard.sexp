;;; The guard this rule first had by mistake. It is sound, but the guard refuses valid steps.
(rule transpose-add-overguarded :level equation :class equivalence
  :pattern (= (+ ?a ?b) ?c) :replacement (= ?a (- ?c ?b))
  :guards ((total ?b)) :params ()
  :explanation "Wrong on purpose."
  :skills (balance) :mal nil
  :positive (("2x + 5 = 17" "2x = 17 - 5"))
  :negative (("x = 1" "x = 2")))
