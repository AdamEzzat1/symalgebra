;;;; Square roots of numbers: reading them, sets and witnesses over a + b*sqrt(d), and solved forms.
;;;; Loaded by run.lisp.

(in-package :symalgebra.engine)

(defun text-of-step (previous line)
  (verdict-text (check-lines previous line)))

(defun says-text (name previous line wanted)
  (let ((got (text-of-step previous line)))
    (check name (string= got wanted) got)))

(defun solved-at (start previous text)
  (getf (check-step start previous text) :solved))

(tier "radicals"
  ;; Reading.
  (check "sqrt is read as a function of a number"
         (equal (parse-line "x = sqrt(2)") '(= :x (sqrt 2))))
  (check "the root sign reads the same" (equal (parse-line (format nil "x = ~c2" (code-char 8730)))
                                               (parse-line "x = sqrt(2)")))
  (check "juxtaposition works on both sides"
         (equal (parse-line "2sqrt(3)x = 1") '(= (* (* 2 (sqrt 3)) :x) 1)))
  (check "plus or minus is two alternatives"
         (equal (flat (parse-line (format nil "x = 1 ~c sqrt(5)" (code-char 177))))
                (flat (parse-line "x = 1 + sqrt(5) or x = 1 - sqrt(5)"))))
  (check "a leading plus or minus is two alternatives"
         (equal (flat (parse-line (format nil "x = ~csqrt(2)" (code-char 177))))
                (flat (parse-line "x = sqrt(2) or x = -sqrt(2)"))))
  (check "two plus-or-minus signs are not read"
         (handler-case (progn (parse-line (format nil "x = 1 ~c 2 ~c 3" (code-char 177) (code-char 177))) nil)
           (refused (r) (string= (refused-reason r) "unparsed"))))
  (check "a space and a minus are still a sum" (equal (parse-line "x = 3 +-2") '(= :x (+ 3 -2))))
  (check "a tree with a root prints and reparses"
         (equal (parse-line (tree-text (parse-line "x = 1 + sqrt(5)"))) (parse-line "x = 1 + sqrt(5)")))
  ;; Equal meaning.
  (says-text "both roots" "x^2 = 2" "x = sqrt(2) or x = -sqrt(2)" "EQUIVALENT")
  (says-text "a square root simplifies" "x = sqrt(12)" "x = 2sqrt(3)" "EQUIVALENT")
  (says-text "a perfect square is a number" "x = sqrt(9)" "x = 3" "EQUIVALENT")
  (says-text "a fraction under the root" "x = sqrt(1/2)" "x = sqrt(2)/2" "EQUIVALENT")
  (says-text "the formula's two answers" "x^2 - 3x - 1 = 0"
             "x = (3 + sqrt(13))/2 or x = (3 - sqrt(13))/2" "EQUIVALENT")
  (says-text "completing the square" "x^2 + 6x = 4" "(x + 3)^2 = 13" "EQUIVALENT")
  (says-text "brackets with roots" "x^2 = 5" "(x - sqrt(5))(x + sqrt(5)) = 0" "EQUIVALENT")
  (says-text "roots as coefficients" "sqrt(2)x = 2" "x = sqrt(2)" "EQUIVALENT")
  (says-text "a root in a denominator" "x/sqrt(2) = 1" "x = sqrt(2)" "EQUIVALENT")
  (says-text "a root squared" "x = sqrt(3)^2" "x = 3" "EQUIVALENT")
  (says-text "a domain hole at a root" "x/(x - sqrt(2)) = 1/(x - sqrt(2))" "x = 1" "EQUIVALENT")
  ;; A wrong step is shown with an exact witness, even when no line wrote a root.
  (says-text "losing the negative root" "x^2 = 2" "x = sqrt(2)"
             "LOSES Finite{-sqrt(2)} witness=-sqrt(2)")
  (says-text "a wrong number against irrational roots" "x^2 = 2" "x = 1"
             "UNRELATED Finite{-sqrt(2),sqrt(2)} witness=-sqrt(2)")
  (says-text "gaining a root" "x = sqrt(2)" "x^2 = 2" "GAINS Finite{-sqrt(2)} witness=-sqrt(2)")
  (says-text "rational and irrational members in order" "(x - 3)(x^2 - 2) = 0" "x = 1"
             "UNRELATED Finite{-sqrt(2),sqrt(2),3} witness=-sqrt(2)")
  (says-text "a surd with a rational part" "x^2 - 2x - 4 = 0" "x = 1 + sqrt(5)"
             "LOSES Finite{1 - sqrt(5)} witness=1 - sqrt(5)")
  (says-text "a surd over a denominator" "x^2 - x - 1 = 0" "x = (1 + sqrt(5))/2"
             "LOSES Finite{(1 - sqrt(5))/2} witness=(1 - sqrt(5))/2")
  (says-text "a multiple of a root" "x^2 = 12" "x = 2sqrt(3)"
             "LOSES Finite{-2sqrt(3)} witness=-2sqrt(3)")
  (says-text "a witness can only be a root of the typed field too" "x^2 = 2" "x^2 = 3"
             "UNRELATED Finite{-sqrt(2),sqrt(2)} witness=-sqrt(2)")
  (says-text "a line with a root and a rational answer" "x = 1 or x = sqrt(2)" "x = 1"
             "LOSES Finite{sqrt(2)} witness=sqrt(2)")
  (says-text "two roots in one field" "x = sqrt(2) or x = 1 + sqrt(2)" "x = 5"
             "UNRELATED Finite{sqrt(2),1 + sqrt(2)} witness=sqrt(2)")
  (says-text "another field in the witness only" "x^2 = 5" "x = sqrt(3)"
             "UNRELATED Finite{-sqrt(5),sqrt(5)} witness=-sqrt(5)")
  (says-text "the sign of a surd with parts of opposite sign" "x = 0 or x = 2 - sqrt(5)" "x = 5"
             "UNRELATED Finite{2 - sqrt(5),0} witness=2 - sqrt(5)")
  (says-text "a discriminant that is itself a surd" "x = 1 + sqrt(2) or x = 2 + 2sqrt(2)" "x = 5"
             "UNRELATED Finite{1 + sqrt(2),2 + 2sqrt(2)} witness=1 + sqrt(2)")
  ;; Refusals.
  (says-text "a negative under the root" "x = sqrt(-1)" "x = 1" "OUT_OF_FRAGMENT negative_radicand")
  (says-text "a root of a root" "x = sqrt(sqrt(2))" "x = 1" "OUT_OF_FRAGMENT nested_radical")
  (says-text "two different roots on one line" "x = sqrt(2) + sqrt(3)" "x = 1"
             "OUT_OF_FRAGMENT many_radicals")
  (says-text "two different roots in one step" "x = sqrt(2)" "x = sqrt(3)"
             "OUT_OF_FRAGMENT many_radicals")
  (says-text "two different roots that the arithmetic never meets" "sqrt(2) = sqrt(2)" "x = sqrt(3)"
             "OUT_OF_FRAGMENT many_radicals")
  (says-text "a root of an empty value" "x = sqrt(1/0)" "x = 1" "OUT_OF_FRAGMENT empty_domain")
  (says-text "a cubic root stays refused" "x^3 = 2" "x = 1" "OUT_OF_FRAGMENT irrational_root")
  (says-text "a quartic with four irrational roots stays refused" "x^4 - 5x^2 + 6 = 0" "x = 1"
             "OUT_OF_FRAGMENT irrational_root")
  (says-text "the sum of two fields stays refused" "x^2 - 2sqrt(2)x - 1 = 0" "x = 1"
             "OUT_OF_FRAGMENT irrational_root")
  ;; Sets with no real members in them are still empty.
  (says-text "complex roots are no members" "x^2 + 1 = 0" "x^2 + 2 = 0" "EQUIVALENT")
  ;; Solved forms.
  (check "both surds are solved" (solved-at "x^2 = 2" "x^2 = 2" "x = sqrt(2) or x = -sqrt(2)"))
  (check "a formula answer is solved"
         (solved-at "x^2 - 3x - 1 = 0" "x^2 - 3x - 1 = 0"
                    (format nil "x = (3 ~c sqrt(13))/2" (code-char 177))))
  (check "split fractions are solved" (solved-at "x^2 - x - 1 = 0" "x^2 - x - 1 = 0"
                                                 "x = 1/2 + sqrt(5)/2 or x = 1/2 - sqrt(5)/2"))
  (check "a multiple is solved" (solved-at "x^2 = 12" "x^2 = 12" "x = 2sqrt(3) or x = -2sqrt(3)"))
  (check "an unsimplified root is not solved"
         (not (solved-at "x^2 = 12" "x^2 = 12" "x = sqrt(12) or x = -sqrt(12)")))
  (check "a perfect square under the root is not solved"
         (not (solved-at "x^2 = 9" "x^2 = 9" "x = sqrt(9) or x = -sqrt(9)")))
  (check "a sum under the root is not solved"
         (not (solved-at "x^2 = 5" "x^2 = 5" "x = sqrt(2 + 3) or x = -sqrt(2 + 3)")))
  ;; Naming: each of these used to be accepted with no rule.
  (flet ((named (before after rule)
           (check (format nil "~a names ~a -> ~a" rule before after)
                  (labels-describe-p before after (list rule) #\x))))
    (named "2x^2 + 7x + 3 = 0" "(2x + 1)(x + 3) = 0" "factor-leading")
    (named "6x^2 - x - 2 = 0" "(2x + 1)(3x - 2) = 0" "factor-leading")
    (named "2x + 4 = 0" "2(x + 2) = 0" "factor-number")
    (named "2x^2 + 8x + 6 = 0" "2(x^2 + 4x + 3) = 0" "factor-number-three")
    (named "x^2 = 7" "x = sqrt(7) or x = -sqrt(7)" "take-root")
    (named "x = sqrt(18)" "x = 3sqrt(2)" "simplify-root")
    (named "x = sqrt(25)" "x = 5" "root-of-square")
    (named "x = (2 - 2sqrt(3))/2" "x = 1 - sqrt(3)" "divide-terms")
    (named "x^2 - 8x = 1" "x^2 - 8x + 16 = 1 + 16" "complete-square")
    (named "x^2 - 8x + 16 = 17" "(x - 4)^2 = 17" "factor-perfect-square")
    (named "x^2 - 3x - 1 = 0" "x = (3 + sqrt(13))/2 or x = (3 - sqrt(13))/2" "quadratic-formula")
    (named "x^2 - 3x - 1 = 0"
           (format nil "x = (-(-3) ~c sqrt((-3)^2 - 4 * 1 * (-1)))/(2 * 1)" (code-char 177))
           "quadratic-substitute"))
  (check "no formula when the roots are not real"
         (not (rule-reaches-p (find-rule "quadratic-formula") "x^2 + x + 1 = 0"
                              "x = (-1 + sqrt(-3))/2 or x = (-1 - sqrt(-3))/2")))
  ;; The status is the same as for any other line.
  (check "a lost root is rejected"
         (eq (getf (check-step "x^2 = 2" "x^2 = 2" "x = sqrt(2)") :status) :rejected))
  (check "a negative radicand is not a wrong line"
         (eq (getf (check-step "x^2 = 2" "x^2 = 2" "x = sqrt(-2)") :status) :out-of-fragment))
  ;; A root over x, worked out at one point.
  (check "a root over x has no value below zero" (null (value '(sqrt :x) -4)))
  (check "a root over x at a surd has no exact value"
         (handler-case (progn (value '(sqrt :x) (surd 1 1 2)) nil)
           (refused (r) (string= (refused-reason r) "irrational_root"))))
  (check "a root over x has no polynomial reading"
         (handler-case (progn (meaning-of '(sqrt :x)) nil)
           (refused (r) (string= (refused-reason r) "radical_variable")))))
