;;;; Inequalities and absolute values: reading them, sign charts, witnesses and solved forms.
;;;; Loaded by run.lisp, after radicals.lisp.

(in-package :symalgebra.engine)

(defun explained (previous line)
  (coerce (explanations previous line #\x) 'list))

(tier "ranges"
  ;; Reading.
  (check "an inequality is read" (equal (parse-line "x <= 3") '(<= :x 3)))
  (check "the other direction is read" (equal (parse-line "2 > x") '(> 2 :x)))
  (check "the printed signs read the same"
         (equal (parse-line (format nil "x ~c 3" (code-char 8804))) (parse-line "x <= 3")))
  (check "the other printed sign reads the same"
         (equal (parse-line (format nil "x ~c 3" (code-char 8805))) (parse-line "x >= 3")))
  (check "a range is two inequalities" (equal (parse-line "1 < x <= 5") '(and (< 1 :x) (<= :x 5))))
  (check "bars are an absolute value" (equal (parse-line "|x| = 1") '(= (abs :x) 1)))
  (check "abs is the same as bars" (equal (parse-line "abs(x) = 1") (parse-line "|x| = 1")))
  (check "a number beside bars multiplies" (equal (parse-line "2|x| = 4") '(= (* 2 (abs :x)) 4)))
  (check "alternatives can be inequalities"
         (equal (parse-line "x < 1 or x > 3") '(or (< :x 1) (> :x 3))))
  (check "flat reads a greater-than as a less-than"
         (equal (flat (parse-line "x > 3")) (flat (parse-line "3 < x"))))
  ;; Refusals.
  (says-text "a range running both ways" "1 < x > 0" "x = 1" "OUT_OF_FRAGMENT chain")
  (says-text "an inequality beside an equals" "1 < x = 2" "x = 1" "OUT_OF_FRAGMENT chain")
  (says-text "three inequalities in a row" "1 < x < 2 < 3" "x = 1" "OUT_OF_FRAGMENT chain")
  (says-text "an open bar" "|x = 1" "x = 1" "OUT_OF_FRAGMENT unparsed")
  (says-text "bars inside bars" "|2|x|| = 1" "x = 1" "OUT_OF_FRAGMENT unparsed")
  (says-text "bars after a division" "1/2|x| = 1" "x = 1" "OUT_OF_FRAGMENT ambiguous_division")
  (says-text "too many absolute values" "|x| + |x - 1| + |x - 2| + |x - 3| = 1" "x = 1"
             "OUT_OF_FRAGMENT abs_limit")
  (says-text "a breakpoint with no exact form" "x^3 < 2" "x < 1" "OUT_OF_FRAGMENT irrational_root")
  (says-text "two kinds of root" "x^2 < 2" "x^2 < 3" "OUT_OF_FRAGMENT many_radicals")
  ;; Verdicts on inequalities.
  (says-text "take the same number off both sides" "2x + 1 < 7" "2x < 6" "EQUIVALENT")
  (says-text "divide by a positive" "2x < 6" "x < 3" "EQUIVALENT")
  (says-text "read from the other side" "x < 3" "3 > x" "EQUIVALENT")
  (says-text "divide by a negative and flip" "-2x < 6" "x > -3" "EQUIVALENT")
  (says-text "the mistake of not flipping" "-2x < 6" "x < -3"
             "UNRELATED Ranges{(-3,inf)} witness=-2")
  (says-text "a strict sign loosened" "x < 3" "x <= 3" "GAINS Finite{3} witness=3")
  (says-text "a loose sign tightened" "x <= 3" "x < 3" "LOSES Finite{3} witness=3")
  (says-text "a bound moved" "x > 1" "x > 3" "LOSES Ranges{(1,3]} witness=2")
  (says-text "two pieces of a square" "x^2 > 4" "x < -2 or x > 2" "EQUIVALENT")
  (says-text "the piece between" "x^2 < 4" "-2 < x < 2" "EQUIVALENT")
  (says-text "a range between roots" "x^2 < 2" "-sqrt(2) < x < sqrt(2)" "EQUIVALENT")
  (says-text "a witness beside a root" "x^2 < 2" "x < 5"
             "GAINS Ranges{(-inf,-sqrt(2)],[sqrt(2),5)} witness=-1 - sqrt(2)")
  (says-text "a denominator's sign" "1/x > 0" "x > 0" "EQUIVALENT")
  (says-text "a domain still counts" "x/x < 2" "1 < 2" "GAINS Finite{0} witness=0")
  (says-text "an equation against an inequality" "2x = 6" "x < 4"
             "GAINS Ranges{(-inf,3),(3,4)} witness=2")
  (says-text "an inequality against an equation" "x < 1" "x = 0"
             "LOSES Ranges{(-inf,0),(0,1)} witness=-1")
  ;; Verdicts on absolute values.
  (says-text "two cases" "|x - 3| = 5" "x - 3 = 5 or x - 3 = -5" "EQUIVALENT")
  (says-text "the two answers" "|x - 3| = 5" "x = 8 or x = -2" "EQUIVALENT")
  (says-text "one case lost" "|x - 3| = 5" "x = 8" "LOSES Finite{-2} witness=-2")
  (says-text "a band" "|x| < 3" "-3 < x < 3" "EQUIVALENT")
  (says-text "half a band" "|x| < 3" "x < 3" "GAINS Ranges{(-inf,-3]} witness=-4")
  (says-text "outside a band" "|x - 1| >= 2" "x <= -1 or x >= 3" "EQUIVALENT")
  (says-text "bars on both sides" "|2x| = |x + 3|" "x = 3 or x = -1" "EQUIVALENT")
  (says-text "a number outside the bars" "2|x| = 6" "|x| = 3" "EQUIVALENT")
  (says-text "bars never come to a negative" "|x| = -1" "0 = 1" "EQUIVALENT")
  (says-text "bars are never below zero" "|x| >= 0" "0 = 0" "EQUIVALENT")
  (says-text "bars inside abs" "abs(|x| - 1) = 0" "x = 1 or x = -1" "EQUIVALENT")
  (says-text "a flat stretch between two kinks" "|x| + |x - 2| = 2" "0 <= x <= 2" "EQUIVALENT")
  (says-text "a kink that changes nothing" "|x| > -1" "0 = 0" "EQUIVALENT")
  ;; Using a verdict.
  (check "a bound is an answer" (solved-at "2x < 6" "2x < 6" "x < 3"))
  (check "read from the other side too" (solved-at "2x < 6" "2x < 6" "3 > x"))
  (check "a range is an answer" (solved-at "x^2 < 4" "x^2 < 4" "-2 < x < 2"))
  (check "pieces are an answer" (solved-at "x^2 > 4" "x^2 > 4" "x < -2 or x > 2"))
  (check "a root can be a bound" (solved-at "x^2 < 2" "x^2 < 2" "-sqrt(2) < x < sqrt(2)"))
  (check "an unfinished line is not an answer" (not (solved-at "2x < 6" "2x < 6" "x + 1 < 4")))
  (check "a line that is not simple is not an answer" (not (solved-at "2x < 6" "2x < 6" "2x < 6")))
  (check "nothing fits below zero"
         (eq (getf (check-step "x^2 < 0" "x^2 < 0" "no solution") :status) :accepted))
  (check "everything fits above zero"
         (eq (getf (check-step "x^2 >= 0" "x^2 >= 0" "all real numbers") :status) :accepted))
  (check "bars can have no solution"
         (eq (getf (check-step "|x| < -1" "|x| < -1" "no solution") :status) :accepted))
  (check "a line with answers is not no solution"
         (eq (getf (check-step "x < 3" "x < 3" "no solution") :status) :rejected))
  (check "all but one value counts as all real numbers"
         (eq (getf (check-step "|x| > 0" "|x| > 0" "all real numbers") :status) :accepted))
  (check "a range is not all real numbers"
         (eq (getf (check-step "x < 3" "x < 3" "all real numbers") :status) :rejected))
  ;; Explaining.
  (check "a range takes one number off every part"
         (= 1 (length (getf (attribute (parse-line "-1 < 2x + 1 < 7")
                                       (parse-line "-1 - 1 < 2x + 1 - 1 < 7 - 1"))
                            :rules))))
  (check "a range cannot take different numbers off its parts"
         (eq (getf (attribute (parse-line "-1 < 2x + 1 < 7") (parse-line "-1 - 2 < 2x + 1 - 1 < 7 - 1")
                              :depth 1)
                   :state)
             :none))
  (check "both parts of a range take the same number"
         (every (lambda (edge)
                  (destructuring-bind (one two) (rest (second edge))
                    (or (equal (third one) (second two)) (equal (third two) (second one)))))
                (edges (flat (parse-line "1 < x < 5")) (list (find-rule "ineq-sub-both")))))
  (check "one rel in a rule stands for one sign"
         (null (match '(and (rel ?a 1) (rel ?a 2)) '(and (< :x 1) (<= :x 2)) nil)))
  (check "nothing is multiplied by zero as if it were positive"
         (eq (guard-state (find-rule "ineq-mul-pos") '((?n . 0))) :failed))
  (check "nothing is multiplied by zero as if it were negative"
         (eq (guard-state (find-rule "ineq-mul-neg") '((?n . 0))) :failed))
  (check "one part of a range can be worked out alone"
         (equal (getf (attribute (parse-line "1 + 1 < x < 5") (parse-line "2 < x < 5")) :rules)
                '("add-literals")))
  (check "a flip is named" (search "flips" (format nil "~{~a ~}" (explained "-2x > 6" "x < 6/(-2)"))))
  (check "bars are named" (search "two cases" (format nil "~{~a ~}" (explained "|x - 3| = 5"
                                                                              "x - 3 = 5 or x - 3 = -5"))))
  (check "a rejected inequality shows both sides"
         (search "it says -1 > 1" (why-text "x > -3" "x > 1" (check-lines "x > -3" "x > 1") #\x)))
  (check "a rejected range still has words"
         (plusp (length (why-text "-1 < x < 1" "x > 0" (check-lines "-1 < x < 1" "x > 0") #\x)))))
