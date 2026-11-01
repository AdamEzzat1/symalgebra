;;;; A trial rule changed without regenerating the Lean statements.
(rule mul-zero :level expr :class equivalence
  :pattern (* ?a 0) :replacement 0
  :guards ((total ?a)) :params ()
  :explanation "Anything multiplied by 0 is 0."
  :skills (identities domains) :mal nil
  :positive (("(x + 1) * 0 = x" "0 = x"))
  :negative (("(1/x) * 0 = 0" "0 = 0" guard)))

(rule distribute :level expr :class equivalence
  :pattern (* ?a (+ ?b ?c)) :replacement (+ (* ?a ?b) ?c)
  :guards () :params ()
  :explanation "Multiply {?a} by each term in the brackets."
  :skills (distribution) :mal nil
  :positive (("2(x + 3) = 10" "2x + 2 * 3 = 10"))
  :negative (("2(x + 3) = 10" "2x + 3 = 10")))

(rule div-by-fraction :level expr :class equivalence
  :pattern (/ ?a (/ ?b ?c)) :replacement (/ (* ?a ?c) ?b)
  :guards ((nonzero-literal ?c)) :params ()
  :explanation "Dividing by a fraction is multiplying by its reciprocal."
  :skills (fractions) :mal nil
  :positive (("x/(2/3) = 1" "(x * 3)/2 = 1"))
  :negative (("1/(x/(x - 1)) = 0" "(1 * (x - 1))/x = 0" guard)))

(rule add-both :level equation :class equivalence
  :pattern (= ?l ?r) :replacement (= (+ ?l ?t) (+ ?r ?t))
  :guards ((total ?t)) :params ((?t term))
  :explanation "Add {?t} to both sides."
  :skills (balance) :mal nil
  :positive (("x - 3 = 5" "x - 3 + 3 = 5 + 3"))
  :negative (("x = 0" "x + 1/x = 0 + 1/x" guard)))

(rule cross-multiply :level equation :class implication
  :pattern (= (/ ?a ?b) (/ ?c ?d)) :replacement (= (* ?a ?d) (* ?c ?b))
  :guards () :params ()
  :explanation "Multiply each numerator by the other denominator, then check your answer at the end."
  :skills (fractions balance domains) :mal nil
  :positive (("x/2 = 3/4" "x * 4 = 3 * 2"))
  :negative (("x/2 = 3/4" "x + 4 = 3 + 2")))
