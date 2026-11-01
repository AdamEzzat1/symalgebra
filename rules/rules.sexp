;;;; The single source for every rule. Format and meaning: docs/RULE-FORMAT.md.
;;;; Never copy a rule elsewhere: Lisp tables, Prolog facts and Lean statements are generated.
;;;; Metavariables start with ?. `eval` computes exact arithmetic on literals.

;;; Arithmetic

(rule add-literals :level expr :class equivalence
  :pattern (+ ?m ?n) :replacement (eval (+ ?m ?n))
  :guards ((literal ?m) (literal ?n)) :params ()
  :explanation "Add the numbers {?m} and {?n}."
  :skills (arithmetic) :mal nil
  :positive (("x = 2 + 3" "x = 5"))
  :negative (("x = 2 + 3" "x = 6")))

(rule sub-literals :level expr :class equivalence
  :pattern (- ?m ?n) :replacement (eval (- ?m ?n))
  :guards ((literal ?m) (literal ?n)) :params ()
  :explanation "Subtract {?n} from {?m}."
  :skills (arithmetic) :mal nil
  :positive (("x = 17 - 5" "x = 12"))
  :negative (("x = 2 - 5" "x = 3")))

(rule mul-literals :level expr :class equivalence
  :pattern (* ?m ?n) :replacement (eval (* ?m ?n))
  :guards ((literal ?m) (literal ?n)) :params ()
  :explanation "Multiply {?m} by {?n}."
  :skills (arithmetic) :mal nil
  :positive (("x = 3 * 4" "x = 12"))
  :negative (("x = 3 * 4" "x = 7")))

(rule div-literals :level expr :class equivalence
  :pattern (/ ?m ?n) :replacement (eval (/ ?m ?n))
  :guards ((literal ?m) (nonzero-literal ?n)) :params ()
  :explanation "Divide {?m} by {?n}."
  :skills (arithmetic) :mal nil
  :positive (("x = 12/3" "x = 4"))
  :negative (("x = 12/3" "x = 9")))

;;; Identities

(rule add-zero :level expr :class equivalence
  :pattern (+ ?a 0) :replacement ?a
  :guards () :params ()
  :explanation "Adding 0 changes nothing."
  :skills (identities) :mal nil
  :positive (("2x + 0 = 6" "2x = 6"))
  :negative (("2x + 1 = 6" "2x = 6")))

(rule mul-one :level expr :class equivalence
  :pattern (* ?a 1) :replacement ?a
  :guards () :params ()
  :explanation "Multiplying by 1 changes nothing."
  :skills (identities) :mal nil
  :positive (("x * 1 = 6" "x = 6"))
  :negative (("x * 2 = 6" "x = 6")))

(rule mul-zero :level expr :class equivalence
  :pattern (* ?a 0) :replacement 0
  :guards ((total ?a)) :params ()
  :explanation "Anything multiplied by 0 is 0."
  :skills (identities domains) :mal nil
  :positive (("(x + 1) * 0 = x" "0 = x"))
  :negative (("(1/x) * 0 = 0" "0 = 0" guard)))

(rule sub-self :level expr :class equivalence
  :pattern (- ?a ?a) :replacement 0
  :guards ((total ?a)) :params ()
  :explanation "Anything minus itself is 0."
  :skills (identities domains) :mal nil
  :positive (("(x + 1) - (x + 1) = 2" "0 = 2"))
  :negative (("1/x - 1/x = 0" "0 = 0" guard)))

;;; Order. These leave the AC-sorted flat view unchanged, so they name a step without moving it.

(rule add-comm :level expr :class equivalence
  :pattern (+ ?a ?b) :replacement (+ ?b ?a)
  :guards () :params ()
  :explanation "Terms can be added in either order."
  :skills (ordering) :mal nil
  :positive (("5 + 2x = 17" "2x + 5 = 17"))
  :negative (("5 - 2x = 17" "2x - 5 = 17")))

(rule mul-comm :level expr :class equivalence
  :pattern (* ?a ?b) :replacement (* ?b ?a)
  :guards () :params ()
  :explanation "Factors can be multiplied in either order."
  :skills (ordering) :mal nil
  :positive (("x * 3 = 6" "3 * x = 6"))
  :negative (("x / 3 = 6" "3 / x = 6")))

(rule add-assoc :level expr :class equivalence
  :pattern (+ (+ ?a ?b) ?c) :replacement (+ ?a (+ ?b ?c))
  :guards () :params ()
  :explanation "Terms can be grouped either way when adding."
  :skills (ordering) :mal nil
  :positive (("x + 2 + 3 = 7" "x + (2 + 3) = 7"))
  :negative (("x - 2 + 3 = 7" "x - (2 + 3) = 7")))

(rule mul-assoc :level expr :class equivalence
  :pattern (* (* ?a ?b) ?c) :replacement (* ?a (* ?b ?c))
  :guards () :params ()
  :explanation "Factors can be grouped either way when multiplying."
  :skills (ordering) :mal nil
  :positive (("2 * 3 * x = 6" "2 * (3 * x) = 6"))
  :negative (("2 / 3 * x = 6" "2 / (3 * x) = 6")))

;;; Distribution

(rule distribute :level expr :class equivalence
  :pattern (* ?a (+ ?b ?c)) :replacement (+ (* ?a ?b) (* ?a ?c))
  :guards () :params ()
  :explanation "Multiply {?a} by each term in the brackets."
  :skills (distribution) :mal nil
  :positive (("2(x + 3) = 10" "2x + 2 * 3 = 10"))
  :negative (("2(x + 3) = 10" "2x + 3 = 10")))

(rule distribute-sub :level expr :class equivalence
  :pattern (* ?a (- ?b ?c)) :replacement (- (* ?a ?b) (* ?a ?c))
  :guards () :params ()
  :explanation "Multiply {?a} by each term in the brackets."
  :skills (distribution) :mal nil
  :positive (("3(x - 2) = 6" "3x - 3 * 2 = 6"))
  :negative (("3(x - 2) = 6" "3x - 2 = 6")))

(rule negate-sum :level expr :class equivalence
  :pattern (neg (+ ?a ?b)) :replacement (- (neg ?a) ?b)
  :guards () :params ()
  :explanation "A minus sign in front of brackets changes the sign of each term."
  :skills (distribution) :mal nil
  :positive (("-(x + 3) = 2" "-x - 3 = 2"))
  :negative (("-(x + 3) = 2" "-x + 3 = 2")))

(rule sub-bracket :level expr :class equivalence
  :pattern (- ?a (+ ?b ?c)) :replacement (- (- ?a ?b) ?c)
  :guards () :params ()
  :explanation "Subtracting a bracket subtracts each term in it."
  :skills (distribution) :mal nil
  :positive (("5 - (x + 2) = 1" "5 - x - 2 = 1"))
  :negative (("5 - (x + 2) = 1" "5 - x + 2 = 1")))

(rule sub-bracket-sub :level expr :class equivalence
  :pattern (- ?a (- ?b ?c)) :replacement (+ (- ?a ?b) ?c)
  :guards () :params ()
  :explanation "Subtracting a difference adds back the term that was being taken away."
  :skills (distribution) :mal nil
  :positive (("5 - (x - 2) = 1" "5 - x + 2 = 1"))
  :negative (("5 - (x - 2) = 1" "5 - x - 2 = 1")))

;;; Like terms

(rule combine-like :level expr :class equivalence
  :pattern (+ (* ?m ?a) (* ?n ?a)) :replacement (* (eval (+ ?m ?n)) ?a)
  :guards ((literal ?m) (literal ?n)) :params ()
  :explanation "These are like terms: add the numbers in front of {?a}."
  :skills (like-terms) :mal nil
  :positive (("3x + 2x = 10" "5x = 10"))
  :negative (("3x + 2 = 10" "5x = 10")))

(rule combine-like-sub :level expr :class equivalence
  :pattern (- (* ?m ?a) (* ?n ?a)) :replacement (* (eval (- ?m ?n)) ?a)
  :guards ((literal ?m) (literal ?n)) :params ()
  :explanation "These are like terms: subtract the numbers in front of {?a}."
  :skills (like-terms) :mal nil
  :positive (("5x - 2x = 9" "3x = 9"))
  :negative (("5x - 2 = 9" "3x = 9")))

(rule combine-unit :level expr :class equivalence
  :pattern (+ ?a ?a) :replacement (* 2 ?a)
  :guards () :params ()
  :explanation "Two copies of {?a} make 2 of them."
  :skills (like-terms) :mal nil
  :positive (("x + x = 4" "2x = 4"))
  :negative (("x + 1 = 4" "2x = 4")))

(rule combine-implicit :level expr :class equivalence
  :pattern (+ ?a (* ?n ?a)) :replacement (* (eval (+ 1 ?n)) ?a)
  :guards ((literal ?n)) :params ()
  :explanation "{?a} on its own counts as one of them, so add 1 to {?n}."
  :skills (like-terms) :mal nil
  :positive (("x + 3x = 8" "4x = 8"))
  :negative (("x + 3x = 8" "3x = 8")))

;;; Fractions

(rule add-same-denom :level expr :class equivalence
  :pattern (+ (/ ?a ?c) (/ ?b ?c)) :replacement (/ (+ ?a ?b) ?c)
  :guards () :params ()
  :explanation "With the same denominator, add the numerators."
  :skills (fractions) :mal nil
  :positive (("x/3 + 2/3 = 1" "(x + 2)/3 = 1"))
  :negative (("x/3 + 2/5 = 1" "(x + 2)/3 = 1")))

(rule sub-same-denom :level expr :class equivalence
  :pattern (- (/ ?a ?c) (/ ?b ?c)) :replacement (/ (- ?a ?b) ?c)
  :guards () :params ()
  :explanation "With the same denominator, subtract the numerators."
  :skills (fractions) :mal nil
  :positive (("x/3 - 2/3 = 1" "(x - 2)/3 = 1"))
  :negative (("x/3 - 2/5 = 1" "(x - 2)/3 = 1")))

(rule add-cross :level expr :class equivalence
  :pattern (+ (/ ?a ?b) (/ ?c ?d)) :replacement (/ (+ (* ?a ?d) (* ?c ?b)) (* ?b ?d))
  :guards () :params ()
  :explanation "Put both fractions over the common denominator {?b} times {?d}."
  :skills (fractions) :mal nil
  :positive (("x/2 + 1/3 = 1" "(x * 3 + 1 * 2)/(2 * 3) = 1"))
  :negative (("x/2 + 1/3 = 1" "(x + 1)/(2 + 3) = 1")))

(rule mul-fractions :level expr :class equivalence
  :pattern (* (/ ?a ?b) (/ ?c ?d)) :replacement (/ (* ?a ?c) (* ?b ?d))
  :guards () :params ()
  :explanation "Multiply the numerators and multiply the denominators."
  :skills (fractions) :mal nil
  :positive (("(x/2) * (3/5) = 1" "(x * 3)/(2 * 5) = 1"))
  :negative (("(x/2) * (3/5) = 1" "(x + 3)/(2 + 5) = 1")))

(rule mul-by-fraction :level expr :class equivalence
  :pattern (* ?a (/ ?b ?c)) :replacement (/ (* ?a ?b) ?c)
  :guards () :params ()
  :explanation "Multiply the numerator by {?a}."
  :skills (fractions) :mal nil
  :positive (("2 * (x/3) = 1" "(2 * x)/3 = 1"))
  :negative (("2 * (x/3) = 1" "(2 * x)/(2 * 3) = 1")))

(rule div-by-fraction :level expr :class equivalence
  :pattern (/ ?a (/ ?b ?c)) :replacement (/ (* ?a ?c) ?b)
  :guards ((nonzero-literal ?c)) :params ()
  :explanation "Dividing by a fraction is multiplying by its reciprocal."
  :skills (fractions) :mal nil
  :positive (("x/(2/3) = 1" "(x * 3)/2 = 1"))
  :negative (("1/(x/(x - 1)) = 0" "(1 * (x - 1))/x = 0" guard)))

(rule scale-fraction :level expr :class equivalence
  :pattern (/ ?a ?b) :replacement (/ (* ?a ?n) (* ?b ?n))
  :guards ((nonzero-literal ?n)) :params ((?n lcd))
  :explanation "Multiply the top and bottom by {?n}, which keeps the value the same."
  :skills (fractions) :mal nil
  :positive (("x/2 = 1" "(x * 3)/(2 * 3) = 1"))
  :negative (("x/2 = 1" "(x * 3)/2 = 1")))

(rule cancel-literal :level expr :class equivalence
  :pattern (/ (* ?a ?n) (* ?b ?n)) :replacement (/ ?a ?b)
  :guards ((nonzero-literal ?n)) :params ()
  :explanation "{?n} is a common factor of the top and bottom, so it cancels."
  :skills (fractions) :mal nil
  :positive (("(x * 3)/(2 * 3) = 1" "x/2 = 1"))
  :negative (("(x + 3)/(2 + 3) = 1" "x/2 = 1")))

(rule cancel-variable :level expr :class implication
  :pattern (/ (* ?a ?c) (* ?b ?c)) :replacement (/ ?a ?b)
  :guards () :params ()
  :explanation "{?c} cancels, but only where it is not zero, so keep that value excluded."
  :skills (fractions domains) :mal nil
  :positive (("(x * (x - 1))/(2 * (x - 1)) = 1" "x/2 = 1"))
  :negative (("(x + (x - 1))/(2 + (x - 1)) = 1" "x/2 = 1")))

;;; Equations: the same change to both sides

(rule add-both :level equation :class equivalence
  :pattern (= ?l ?r) :replacement (= (+ ?l ?t) (+ ?r ?t))
  :guards ((total ?t)) :params ((?t term))
  :explanation "Add {?t} to both sides."
  :skills (balance) :mal nil
  :positive (("x - 3 = 5" "x - 3 + 3 = 5 + 3"))
  :negative (("x = 0" "x + 1/x = 0 + 1/x" guard)))

(rule sub-both :level equation :class equivalence
  :pattern (= ?l ?r) :replacement (= (- ?l ?t) (- ?r ?t))
  :guards ((total ?t)) :params ((?t term))
  :explanation "Subtract {?t} from both sides."
  :skills (balance) :mal nil
  :positive (("2x + 5 = 17" "2x + 5 - 5 = 17 - 5"))
  :negative (("x = 0" "x - 1/x = 0 - 1/x" guard)))

(rule mul-both :level equation :class equivalence
  :pattern (= ?l ?r) :replacement (= (* ?l ?n) (* ?r ?n))
  :guards ((nonzero-literal ?n)) :params ((?n coefficient))
  :explanation "Multiply both sides by {?n}, which is not zero."
  :skills (balance) :mal nil
  :positive (("x/2 = 3" "x/2 * 2 = 3 * 2"))
  :negative (("x = 1" "x * 0 = 1 * 0" guard)))

(rule div-both :level equation :class equivalence
  :pattern (= ?l ?r) :replacement (= (/ ?l ?n) (/ ?r ?n))
  :guards ((nonzero-literal ?n)) :params ((?n coefficient))
  :explanation "Divide both sides by {?n}, which is not zero."
  :skills (balance) :mal nil
  :positive (("2x = 12" "2x/2 = 12/2"))
  :negative (("2x = 12" "2x/2 = 12")))

(rule swap-sides :level equation :class equivalence
  :pattern (= ?l ?r) :replacement (= ?r ?l)
  :guards () :params ()
  :explanation "An equation says the same thing read from either side."
  :skills (balance) :mal nil
  :positive (("12 = 2x" "2x = 12"))
  :negative (("12 = 2x" "2x = 10")))

(rule transpose-add :level equation :class equivalence
  :pattern (= (+ ?a ?b) ?c) :replacement (= ?a (- ?c ?b))
  :guards () :params ()
  :explanation "Subtract {?b} from both sides, which moves it across."
  :skills (balance) :mal nil
  :positive (("2x + 5 = 17" "2x = 17 - 5"))
  :negative (("2x + 5 = 17" "2x = 17 + 5")))

(rule transpose-sub :level equation :class equivalence
  :pattern (= (- ?a ?b) ?c) :replacement (= ?a (+ ?c ?b))
  :guards () :params ()
  :explanation "Add {?b} to both sides, which moves it across."
  :skills (balance) :mal nil
  :positive (("3x - 4 = 11" "3x = 11 + 4"))
  :negative (("3x - 4 = 11" "3x = 11 - 4")))

(rule isolate-by-division :level equation :class equivalence
  :pattern (= (* ?n ?a) ?c) :replacement (= ?a (/ ?c ?n))
  :guards ((nonzero-literal ?n)) :params ()
  :explanation "Divide both sides by {?n}, which leaves {?a} alone."
  :skills (balance) :mal nil
  :positive (("2x = 12" "x = 12/2"))
  :negative (("0x = 0" "x = 0/0" guard)))

(rule clear-denominators :level equation :class implication
  :pattern (= ?l ?r) :replacement (= (* ?l ?t) (* ?r ?t))
  :guards ((total ?t)) :params ((?t lcd))
  :explanation "Multiply both sides by {?t}. It may be zero somewhere, so check your answer at the end."
  :skills (fractions balance domains) :mal nil
  :positive (("1/x = 2" "1/x * x = 2 * x"))
  :negative (("x = 0" "x * (1/x) = 0 * (1/x)" guard)))

(rule cross-multiply :level equation :class implication
  :pattern (= (/ ?a ?b) (/ ?c ?d)) :replacement (= (* ?a ?d) (* ?c ?b))
  :guards () :params ()
  :explanation "Multiply each numerator by the other denominator, then check your answer at the end."
  :skills (fractions balance domains) :mal nil
  :positive (("x/2 = 3/4" "x * 4 = 3 * 2"))
  :negative (("x/2 = 3/4" "x + 4 = 3 + 2")))
