;;;; The wrong distribution as if it were sound. rperft's invariant must catch it.

(rule bad-distribute :level expr :class equivalence
  :pattern (* ?a (+ ?b ?c)) :replacement (+ (* ?a ?b) ?c)
  :guards () :params ()
  :explanation "Wrong on purpose."
  :skills (distribution) :mal nil
  :positive () :negative ())
