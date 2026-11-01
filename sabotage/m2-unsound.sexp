;;; Forgets to multiply the second term, a real and common mistake written as if it were sound.
(rule bad-distribute :level expr :class equivalence
  :pattern (* ?a (+ ?b ?c)) :replacement (+ (* ?a ?b) ?c)
  :guards () :params ()
  :explanation "Wrong on purpose."
  :skills (distribution) :mal nil
  :positive (("2(x + 3) = 10" "2x + 3 = 10"))
  :negative (("x = 1" "x = 2")))
