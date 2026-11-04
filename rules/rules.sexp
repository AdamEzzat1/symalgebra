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

;;; Quadratics: expanding, factoring and splitting a product that is zero

(rule expand-product :level expr :class equivalence
  :pattern (* (+ ?a ?b) (+ ?c ?d)) :replacement (+ (+ (+ (* ?a ?c) (* ?a ?d)) (* ?b ?c)) (* ?b ?d))
  :guards () :params ()
  :explanation "Multiply each term in the first bracket by each term in the second."
  :skills (quadratics distribution) :mal nil
  :positive (("(x + 2)(x + 3) = 0" "x * x + x * 3 + 2 * x + 2 * 3 = 0"))
  :negative (("(x + 2)(x + 3) = 0" "x * x + 2 * 3 = 0")))

(rule square-as-product :level expr :class equivalence
  :pattern (^ ?a 2) :replacement (* ?a ?a)
  :guards () :params ()
  :explanation "A square is {?a} multiplied by itself."
  :skills (quadratics) :mal nil
  :positive (("(x + 1)^2 = 4" "(x + 1)(x + 1) = 4"))
  :negative (("(x + 1)^2 = 4" "x^2 + 1 = 4")))

(rule product-as-square :level expr :class equivalence
  :pattern (* ?a ?a) :replacement (^ ?a 2)
  :guards () :params ()
  :explanation "{?a} multiplied by itself is its square."
  :skills (quadratics) :mal nil
  :positive (("x * x = 4" "x^2 = 4"))
  :negative (("x * 2 = 4" "x^2 = 4")))

(rule square-sum :level expr :class equivalence
  :pattern (^ (+ ?a ?b) 2) :replacement (+ (+ (^ ?a 2) (* (* 2 ?a) ?b)) (^ ?b 2))
  :guards () :params ()
  :explanation "Squaring a sum gives the first squared, twice the product, and the second squared."
  :skills (quadratics) :mal nil
  :positive (("(x + 3)^2 = 1" "x^2 + 2 * x * 3 + 3^2 = 1"))
  :negative (("(x + 3)^2 = 1" "x^2 + 3^2 = 1")))

(rule square-literal :level expr :class equivalence
  :pattern (^ ?m 2) :replacement (eval (* ?m ?m))
  :guards ((literal ?m)) :params ()
  :explanation "Work out {?m} squared."
  :skills (arithmetic quadratics) :mal nil
  :positive (("x = 3^2" "x = 9"))
  :negative (("x = 3^2" "x = 6")))

(rule factor-common :level expr :class equivalence
  :pattern (+ (* ?a ?b) (* ?a ?c)) :replacement (* ?a (+ ?b ?c))
  :guards () :params ()
  :explanation "Both terms share {?a}, so take it outside a bracket."
  :skills (quadratics distribution) :mal nil
  :positive (("x * x + x * 3 = 0" "x(x + 3) = 0"))
  :negative (("x * x + x * 3 = 0" "x(x * 3) = 0")))

(rule factor-trinomial :level expr :class equivalence
  :pattern (+ (+ (^ ?a 2) (* ?s ?a)) ?p) :replacement (* (+ ?a ?m) (+ ?a ?n))
  :guards ((literal ?s) (literal ?p) (literal ?m) (literal ?n) (factors ?m ?n ?s ?p))
  :params ((?m pair) (?n pair))
  :explanation "{?m} and {?n} add to {?s} and multiply to {?p}, so these are the two brackets."
  :skills (quadratics) :mal nil
  :positive (("x^2 + 5x + 6 = 0" "(x + 2)(x + 3) = 0"))
  :negative (("x^2 + 5x + 6 = 0" "(x + 1)(x + 6) = 0" guard)))

(rule factor-squares :level expr :class equivalence
  :pattern (- (^ ?a 2) ?p) :replacement (* (- ?a ?m) (+ ?a ?m))
  :guards ((literal ?p) (literal ?m) (square-of ?m ?p))
  :params ((?m pair))
  :explanation "This is a difference of two squares, because {?p} is {?m} squared."
  :skills (quadratics) :mal nil
  :positive (("x^2 - 9 = 0" "(x - 3)(x + 3) = 0"))
  :negative (("x^2 - 9 = 0" "(x - 9)(x + 9) = 0" guard)))

(rule zero-product :level equation :class equivalence
  :pattern (= (* ?a ?b) 0) :replacement (or (= ?a 0) (= ?b 0))
  :guards ((total ?a) (total ?b)) :params ()
  :explanation "A product is zero only when one of its factors is zero."
  :skills (quadratics) :mal nil
  :positive (("(x + 2)(x + 3) = 0" "x + 2 = 0 or x + 3 = 0"))
  :negative (("x * (1/x) = 0" "x = 0 or 1/x = 0" guard)))

(rule square-root :level equation :class equivalence
  :pattern (= (^ ?a 2) ?p) :replacement (or (= ?a ?m) (= ?a (neg ?m)))
  :guards ((literal ?p) (literal ?m) (square-of ?m ?p))
  :params ((?m pair))
  :explanation "Two numbers square to {?p}: {?m} and its negative."
  :skills (quadratics) :mal nil
  :positive (("x^2 = 9" "x = 3 or x = -3"))
  :negative (("x^2 = 9" "x = 9 or x = -9" guard)))

;;; Square roots, completing the square and the quadratic formula

(rule take-root :level equation :class equivalence
  :pattern (= (^ ?a 2) ?p) :replacement (or (= ?a (sqrt ?p)) (= ?a (neg (sqrt ?p))))
  :guards ((literal ?p) (positive-literal ?p)) :params ()
  :explanation "Take the square root of both sides, and keep both signs."
  :skills (quadratics radicals) :mal nil
  :positive (("x^2 = 2" "x = sqrt(2) or x = -sqrt(2)"))
  :negative (("x^2 = 2" "x = sqrt(2) or x = sqrt(2)")))

(rule simplify-root :level expr :class equivalence
  :pattern (sqrt ?p) :replacement (* ?m (sqrt ?k))
  :guards ((literal ?p) (literal ?m) (literal ?k) (split-root ?m ?k ?p))
  :params ((?m pair) (?k pair))
  :explanation "{?p} is {?m} squared times {?k}, so {?m} comes out of the root."
  :skills (radicals) :mal nil
  :positive (("x = sqrt(12)" "x = 2 * sqrt(3)"))
  :negative (("x = sqrt(12)" "x = 3 * sqrt(2)" guard)))

(rule root-of-square :level expr :class equivalence
  :pattern (sqrt ?p) :replacement ?m
  :guards ((literal ?p) (positive-literal ?m) (square-of ?m ?p)) :params ((?m pair))
  :explanation "{?m} squared is {?p}, so this root is {?m}."
  :skills (radicals) :mal nil
  :positive (("x = sqrt(9)" "x = 3"))
  :negative (("x = sqrt(9)" "x = -3")))

(rule divide-terms :level expr :class equivalence
  :pattern (/ (+ ?m (* ?k ?r)) ?n) :replacement (+ (eval (/ ?m ?n)) (* (eval (/ ?k ?n)) ?r))
  :guards ((literal ?m) (literal ?k) (nonzero-literal ?n)) :params ()
  :explanation "Divide each term on top by {?n}."
  :skills (radicals fractions) :mal nil
  :positive (("x = (2 + 4sqrt(3))/2" "x = 1 + 2sqrt(3)"))
  :negative (("x = (2 + 4sqrt(3))/2" "x = 1 + 4sqrt(3)")))

(rule complete-square :level equation :class equivalence
  :pattern (= (+ (^ ?a 2) (* ?s ?a)) ?c)
  :replacement (= (+ (+ (^ ?a 2) (* ?s ?a)) (eval (* (/ ?s 2) (/ ?s 2))))
                  (+ ?c (eval (* (/ ?s 2) (/ ?s 2)))))
  :guards ((literal ?s)) :params ()
  :explanation "Half of {?s}, squared, goes on both sides, which makes a perfect square."
  :skills (quadratics balance) :mal nil
  :positive (("x^2 + 6x = 4" "x^2 + 6x + 9 = 4 + 9"))
  :negative (("x^2 + 6x = 4" "x^2 + 6x + 36 = 4 + 36")))

(rule factor-perfect-square :level expr :class equivalence
  :pattern (+ (+ (^ ?a 2) (* ?s ?a)) ?p) :replacement (^ (+ ?a (eval (/ ?s 2))) 2)
  :guards ((literal ?s) (literal ?p) (half-square ?s ?p)) :params ()
  :explanation "{?p} is half of {?s}, squared, so this is a perfect square."
  :skills (quadratics) :mal nil
  :positive (("x^2 + 6x + 9 = 13" "(x + 3)^2 = 13"))
  :negative (("x^2 + 6x + 8 = 13" "(x + 3)^2 = 13" guard)))

(rule quadratic-formula :level equation :class equivalence
  :pattern (= (+ (+ (* ?a (^ ?v 2)) (* ?b ?v)) ?c) 0)
  :replacement (or (= ?v (/ (+ (eval (neg ?b)) (sqrt (eval (- (* ?b ?b) (* (* 4 ?a) ?c)))))
                            (eval (* 2 ?a))))
                   (= ?v (/ (- (eval (neg ?b)) (sqrt (eval (- (* ?b ?b) (* (* 4 ?a) ?c)))))
                            (eval (* 2 ?a)))))
  :guards ((literal ?a) (literal ?b) (literal ?c) (nonzero-literal ?a) (real-discriminant ?a ?b ?c))
  :params ()
  :explanation "This is the quadratic formula with a = {?a}, b = {?b} and c = {?c}."
  :skills (quadratics radicals) :mal nil
  :positive (("2x^2 + 5x + 1 = 0" "x = (-5 + sqrt(17))/4 or x = (-5 - sqrt(17))/4"))
  :negative (("2x^2 + 5x + 1 = 0" "x = (-5 + sqrt(33))/4 or x = (-5 - sqrt(33))/4")))

(rule quadratic-substitute :level equation :class equivalence
  :pattern (= (+ (+ (* ?a (^ ?v 2)) (* ?b ?v)) ?c) 0)
  :replacement (or (= ?v (/ (+ (neg ?b) (sqrt (- (^ ?b 2) (* (* 4 ?a) ?c)))) (* 2 ?a)))
                   (= ?v (/ (- (neg ?b) (sqrt (- (^ ?b 2) (* (* 4 ?a) ?c)))) (* 2 ?a))))
  :guards ((literal ?a) (literal ?b) (literal ?c) (nonzero-literal ?a) (real-discriminant ?a ?b ?c))
  :params ()
  :explanation "Put a = {?a}, b = {?b} and c = {?c} into the quadratic formula."
  :skills (quadratics radicals) :mal nil
  :positive (("2x^2 + 5x + 1 = 0"
              "x = (-5 + sqrt(5^2 - 4 * 2 * 1))/(2 * 2) or x = (-5 - sqrt(5^2 - 4 * 2 * 1))/(2 * 2)"))
  :negative (("2x^2 + 5x + 1 = 0"
              "x = (-5 + sqrt(5^2 + 4 * 2 * 1))/(2 * 2) or x = (-5 - sqrt(5^2 + 4 * 2 * 1))/(2 * 2)")))

;;; Factoring with a leading number, and taking a number out

(rule factor-leading :level expr :class equivalence
  :pattern (+ (+ (* ?a (^ ?v 2)) (* ?b ?v)) ?c)
  :replacement (* (+ (* ?p ?v) ?q) (+ (* (eval (/ ?a ?p)) ?v) (eval (/ ?c ?q))))
  :guards ((literal ?a) (literal ?b) (literal ?c) (literal ?p) (literal ?q) (splits ?p ?q ?a ?b ?c))
  :params ((?p pair) (?q pair))
  :explanation "The first terms multiply to give {?a}, the last terms to give {?c}, and the outer and inner products add to {?b}."
  :skills (quadratics) :mal nil
  :positive (("6x^2 + 7x + 2 = 0" "(2x + 1)(3x + 2) = 0"))
  :negative (("6x^2 + 7x + 2 = 0" "(2x + 2)(3x + 1) = 0" guard)))

(rule factor-number :level expr :class equivalence
  :pattern (+ (* ?c ?a) ?m) :replacement (* ?n (+ (* (eval (/ ?c ?n)) ?a) (eval (/ ?m ?n))))
  :guards ((literal ?c) (literal ?m) (literal ?n) (common-factor ?n ?c ?m)) :params ((?n pair))
  :explanation "Both terms share the factor {?n}, so take it outside a bracket."
  :skills (quadratics distribution) :mal nil
  :positive (("4x + 6 = 0" "2(2x + 3) = 0"))
  :negative (("4x + 6 = 0" "2(2x + 6) = 0")))

(rule factor-number-three :level expr :class equivalence
  :pattern (+ (+ (* ?c ?a) (* ?d ?b)) ?m)
  :replacement (* ?n (+ (+ (* (eval (/ ?c ?n)) ?a) (* (eval (/ ?d ?n)) ?b)) (eval (/ ?m ?n))))
  :guards ((literal ?c) (literal ?d) (literal ?m) (literal ?n) (common-factor ?n ?c ?d ?m))
  :params ((?n pair))
  :explanation "All three terms share the factor {?n}, so take it outside a bracket."
  :skills (quadratics distribution) :mal nil
  :positive (("4x^2 + 6x + 8 = 0" "2(2x^2 + 3x + 4) = 0"))
  :negative (("4x^2 + 6x + 8 = 0" "2(2x^2 + 3x + 8) = 0")))
;;; Inequalities. `rel` stands for < or <=, the same one throughout a rule, and a > b is read as
;;; b < a, so a flipped sign is the two sides swapped.

(rule ineq-add-both :level equation :class equivalence
  :pattern (rel ?l ?r) :replacement (rel (+ ?l ?t) (+ ?r ?t))
  :guards ((total ?t)) :params ((?t term))
  :explanation "Add {?t} to both sides. The sign stays the same."
  :skills (balance inequalities) :mal nil
  :positive (("x - 3 < 5" "x - 3 + 3 < 5 + 3"))
  :negative (("x < 1" "x + 1/x < 1 + 1/x" guard)))

(rule ineq-sub-both :level equation :class equivalence
  :pattern (rel ?l ?r) :replacement (rel (- ?l ?t) (- ?r ?t))
  :guards ((total ?t)) :params ((?t term))
  :explanation "Subtract {?t} from both sides. The sign stays the same."
  :skills (balance inequalities) :mal nil
  :positive (("2x + 5 < 17" "2x + 5 - 5 < 17 - 5"))
  :negative (("x < 1" "x - 1/x < 1 - 1/x" guard)))

(rule ineq-mul-pos :level equation :class equivalence
  :pattern (rel ?l ?r) :replacement (rel (* ?l ?n) (* ?r ?n))
  :guards ((positive-number ?n)) :params ((?n coefficient))
  :explanation "Multiply both sides by {?n}. It is positive, so the sign stays the same."
  :skills (balance inequalities) :mal nil
  :positive (("x/2 < 3" "x/2 * 2 < 3 * 2"))
  :negative (("x < 1" "x * (-1) < 1 * (-1)" guard)))

(rule ineq-div-pos :level equation :class equivalence
  :pattern (rel ?l ?r) :replacement (rel (/ ?l ?n) (/ ?r ?n))
  :guards ((positive-number ?n)) :params ((?n coefficient))
  :explanation "Divide both sides by {?n}. It is positive, so the sign stays the same."
  :skills (balance inequalities) :mal nil
  :positive (("2x < 12" "2x/2 < 12/2"))
  :negative (("x < 1" "x/(-1) < 1/(-1)" guard)))

(rule ineq-mul-neg :level equation :class equivalence
  :pattern (rel ?l ?r) :replacement (rel (* ?r ?n) (* ?l ?n))
  :guards ((negative-number ?n)) :params ((?n coefficient))
  :explanation "Multiply both sides by {?n}. It is negative, so the sign flips."
  :skills (balance inequalities) :mal nil
  :positive (("-x < 3" "3 * (-1) < -x * (-1)"))
  :negative (("-x < 3" "-x * (-1) < 3 * (-1)")))

(rule ineq-div-neg :level equation :class equivalence
  :pattern (rel ?l ?r) :replacement (rel (/ ?r ?n) (/ ?l ?n))
  :guards ((negative-number ?n)) :params ((?n coefficient))
  :explanation "Divide both sides by {?n}. It is negative, so the sign flips."
  :skills (balance inequalities) :mal nil
  :positive (("-2x < 6" "6/(-2) < -2x/(-2)"))
  :negative (("-2x < 6" "-2x/(-2) < 6/(-2)")))

(rule ineq-move-add-left :level equation :class equivalence
  :pattern (rel (+ ?a ?b) ?c) :replacement (rel ?a (- ?c ?b))
  :guards () :params ()
  :explanation "Subtract {?b} from both sides, which moves it across. The sign stays the same."
  :skills (balance inequalities) :mal nil
  :positive (("2x + 5 < 17" "2x < 17 - 5"))
  :negative (("2x + 5 < 17" "2x < 17 + 5")))

(rule ineq-move-sub-left :level equation :class equivalence
  :pattern (rel (- ?a ?b) ?c) :replacement (rel ?a (+ ?c ?b))
  :guards () :params ()
  :explanation "Add {?b} to both sides, which moves it across. The sign stays the same."
  :skills (balance inequalities) :mal nil
  :positive (("3x - 4 < 11" "3x < 11 + 4"))
  :negative (("3x - 4 < 11" "3x < 11 - 4")))

(rule ineq-move-add-right :level equation :class equivalence
  :pattern (rel ?c (+ ?a ?b)) :replacement (rel (- ?c ?b) ?a)
  :guards () :params ()
  :explanation "Subtract {?b} from both sides, which moves it across. The sign stays the same."
  :skills (balance inequalities) :mal nil
  :positive (("17 < 2x + 5" "17 - 5 < 2x"))
  :negative (("17 < 2x + 5" "17 + 5 < 2x")))

(rule ineq-move-sub-right :level equation :class equivalence
  :pattern (rel ?c (- ?a ?b)) :replacement (rel (+ ?c ?b) ?a)
  :guards () :params ()
  :explanation "Add {?b} to both sides, which moves it across. The sign stays the same."
  :skills (balance inequalities) :mal nil
  :positive (("11 < 3x - 4" "11 + 4 < 3x"))
  :negative (("11 < 3x - 4" "11 - 4 < 3x")))

(rule ineq-isolate-pos-left :level equation :class equivalence
  :pattern (rel (* ?n ?a) ?c) :replacement (rel ?a (/ ?c ?n))
  :guards ((positive-number ?n)) :params ()
  :explanation "Divide both sides by {?n}, which leaves {?a} alone. It is positive, so the sign stays the same."
  :skills (balance inequalities) :mal nil
  :positive (("2x < 12" "x < 12/2"))
  :negative (("-2x < 12" "x < 12/(-2)" guard)))

(rule ineq-isolate-pos-right :level equation :class equivalence
  :pattern (rel ?c (* ?n ?a)) :replacement (rel (/ ?c ?n) ?a)
  :guards ((positive-number ?n)) :params ()
  :explanation "Divide both sides by {?n}, which leaves {?a} alone. It is positive, so the sign stays the same."
  :skills (balance inequalities) :mal nil
  :positive (("12 < 2x" "12/2 < x"))
  :negative (("12 < -2x" "12/(-2) < x" guard)))

(rule ineq-isolate-neg-left :level equation :class equivalence
  :pattern (rel (* ?n ?a) ?c) :replacement (rel (/ ?c ?n) ?a)
  :guards ((negative-number ?n)) :params ()
  :explanation "Divide both sides by {?n}, which leaves {?a} alone. It is negative, so the sign flips."
  :skills (balance inequalities) :mal nil
  :positive (("-2x < 6" "6/(-2) < x"))
  :negative (("-2x < 6" "x < 6/(-2)")))

(rule ineq-isolate-neg-right :level equation :class equivalence
  :pattern (rel ?c (* ?n ?a)) :replacement (rel ?a (/ ?c ?n))
  :guards ((negative-number ?n)) :params ()
  :explanation "Divide both sides by {?n}, which leaves {?a} alone. It is negative, so the sign flips."
  :skills (balance inequalities) :mal nil
  :positive (("6 < -2x" "x < 6/(-2)"))
  :negative (("6 < -2x" "6/(-2) < x")))

;;; Absolute value

(rule abs-equal :level equation :class equivalence
  :pattern (= (abs ?a) ?b) :replacement (or (= ?a ?b) (= ?a (neg ?b)))
  :guards ((positive-number ?b)) :params ()
  :explanation "An absolute value equal to {?b} gives two cases: what is inside is {?b} or the negative of it."
  :skills (absolute-value) :mal nil
  :positive (("|x - 3| = 5" "x - 3 = 5 or x - 3 = -5"))
  :negative (("|x| = -1" "x = -1 or x = 1" guard)))

(rule abs-less :level equation :class equivalence
  :pattern (rel (abs ?a) ?b) :replacement (and (rel (neg ?b) ?a) (rel ?a ?b))
  :guards () :params ()
  :explanation "An absolute value below {?b} means what is inside lies between the negative of {?b} and {?b}."
  :skills (absolute-value inequalities) :mal nil
  :positive (("|x| < 3" "-3 < x < 3"))
  :negative (("|x| < 3" "x < 3")))

(rule abs-more :level equation :class equivalence
  :pattern (rel ?b (abs ?a)) :replacement (or (rel ?a (neg ?b)) (rel ?b ?a))
  :guards () :params ()
  :explanation "An absolute value above {?b} gives two cases: what is inside is below the negative of {?b}, or above {?b}."
  :skills (absolute-value inequalities) :mal nil
  :positive (("3 < |x|" "x < -3 or 3 < x"))
  :negative (("3 < |x|" "3 < x")))

(rule abs-zero :level equation :class equivalence
  :pattern (= (abs ?a) 0) :replacement (= ?a 0)
  :guards () :params ()
  :explanation "Only 0 has an absolute value of 0."
  :skills (absolute-value) :mal nil
  :positive (("|x + 2| = 0" "x + 2 = 0"))
  :negative (("|x + 2| = 0" "x + 2 = 1")))

(rule ineq-square-below :level equation :class equivalence
  :pattern (rel (^ ?a 2) ?p) :replacement (and (rel (neg ?m) ?a) (rel ?a ?m))
  :guards ((literal ?p) (positive-literal ?m) (square-of ?m ?p)) :params ((?m pair))
  :explanation "A square below {?p} means {?a} lies between the negative of {?m} and {?m}."
  :skills (quadratics inequalities) :mal nil
  :positive (("x^2 < 9" "-3 < x < 3"))
  :negative (("x^2 < 9" "-9 < x < 9" guard)))

(rule ineq-square-above :level equation :class equivalence
  :pattern (rel ?p (^ ?a 2)) :replacement (or (rel ?a (neg ?m)) (rel ?m ?a))
  :guards ((literal ?p) (positive-literal ?m) (square-of ?m ?p)) :params ((?m pair))
  :explanation "A square above {?p} gives two cases: {?a} is below the negative of {?m}, or above {?m}."
  :skills (quadratics inequalities) :mal nil
  :positive (("9 < x^2" "x < -3 or 3 < x"))
  :negative (("9 < x^2" "x < -9 or 9 < x" guard)))

;;; Roots over the variable

(rule radical-square :level equation :class implication
  :pattern (= (sqrt ?a) ?b) :replacement (= ?a (^ ?b 2))
  :guards () :params ()
  :explanation "Square both sides to clear the root. Squaring can add a false answer, so test each answer in the first line."
  :skills (radicals) :mal nil
  :positive (("sqrt(x + 3) = 5" "x + 3 = 5^2"))
  :negative (("sqrt(x + 3) = 5" "x + 3 = 5")))

(rule radical-both :level equation :class implication
  :pattern (= (sqrt ?a) (sqrt ?b)) :replacement (= ?a ?b)
  :guards () :params ()
  :explanation "The two roots are equal, so what is under them is equal. Both must have a value, so test each answer in the first line."
  :skills (radicals) :mal nil
  :positive (("sqrt(x + 5) = sqrt(2x + 1)" "x + 5 = 2x + 1"))
  :negative (("sqrt(x + 5) = sqrt(2x + 1)" "x + 5 = 2x")))

(rule radical-squared :level expr :class implication
  :pattern (^ (sqrt ?a) 2) :replacement ?a
  :guards () :params ()
  :explanation "The square of the root of {?a} is {?a}, wherever the root has a value."
  :skills (radicals) :mal nil
  :positive (("sqrt(x)^2 = 4" "x = 4"))
  :negative (("sqrt(x)^2 = 4" "x = 2")))

(rule radical-of-square :level expr :class equivalence
  :pattern (sqrt (^ ?a 2)) :replacement (abs ?a)
  :guards () :params ()
  :explanation "The root of a square is the absolute value of {?a}, because a root is never negative."
  :skills (radicals absolute-value) :mal nil
  :positive (("sqrt(x^2) = 3" "|x| = 3"))
  :negative (("sqrt(x^2) = 3" "x = 3")))

;;; Higher polynomials

(rule cube-as-product :level expr :class equivalence
  :pattern (^ ?a 3) :replacement (* ?a (^ ?a 2))
  :guards () :params ()
  :explanation "A cube is {?a} times the square of {?a}."
  :skills (polynomials) :mal nil
  :positive (("(x + 1)^3 = 1" "(x + 1)(x + 1)^2 = 1"))
  :negative (("(x + 1)^3 = 1" "(x + 1)(x + 1) = 1")))

(rule difference-of-cubes :level expr :class equivalence
  :pattern (- (^ ?a 3) ?p)
  :replacement (* (- ?a ?m) (+ (+ (^ ?a 2) (* ?m ?a)) (eval (* ?m ?m))))
  :guards ((literal ?p) (literal ?m) (cube-of ?m ?p)) :params ((?m pair))
  :explanation "This is a difference of two cubes, because {?p} is {?m} cubed."
  :skills (polynomials) :mal nil
  :positive (("x^3 - 8 = 0" "(x - 2)(x^2 + 2x + 4) = 0"))
  :negative (("x^3 - 8 = 0" "(x - 4)(x^2 + 4x + 16) = 0" guard)))

(rule sum-of-cubes :level expr :class equivalence
  :pattern (+ (^ ?a 3) ?p)
  :replacement (* (+ ?a ?m) (+ (- (^ ?a 2) (* ?m ?a)) (eval (* ?m ?m))))
  :guards ((literal ?p) (literal ?m) (cube-of ?m ?p)) :params ((?m pair))
  :explanation "This is a sum of two cubes, because {?p} is {?m} cubed."
  :skills (polynomials) :mal nil
  :positive (("x^3 + 27 = 0" "(x + 3)(x^2 - 3x + 9) = 0"))
  :negative (("x^3 + 27 = 0" "(x + 9)(x^2 - 9x + 81) = 0" guard)))
