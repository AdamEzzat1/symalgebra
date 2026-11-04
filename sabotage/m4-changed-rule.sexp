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
