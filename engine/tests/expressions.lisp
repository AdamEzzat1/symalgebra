;;;; Expression tasks: simplify, expand and factor. Loaded by run.lisp, after roots.lisp.

(in-package :symalgebra.engine)

(defmacro compares (name before after wanted)
  `(check ,name (string= (verdict-text (check-expressions ,before ,after)) ,wanted)
          (verdict-text (check-expressions ,before ,after))))

(defun expression-status (line0 previous text &rest finished)
  (getf (check-expression-step line0 previous text finished) :status))

(defun expression-solved (line0 text &rest finished)
  (getf (check-expression-step line0 line0 text finished) :solved))

(tier "expressions"
  ;; Reading.
  (check "an expression is read" (equal (parse-expression-line "x + 1") '(+ :x 1)))
  (check "an equation is not an expression"
         (eq (getf (check-expressions "x + 1" "x = 1") :verdict) :out-of-fragment))
  (check "an equation line stays an equation" (eq (getf (check-lines "x + 1" "x + 1") :verdict) :out-of-fragment))
  (check "alternatives are not an expression"
         (eq (getf (check-expressions "x" "x or x") :verdict) :out-of-fragment))
  (check "plus or minus is not an expression"
         (string= (getf (check-expressions "x + 1" "x ± 1") :reason) "unparsed"))
  ;; Verdicts.
  (compares "the same polynomial" "(x + 1)(x + 2)" "x^2 + 3x + 2" "EQUIVALENT")
  (compares "a different polynomial" "(x + 1)(x + 2)" "x^2 + 2x + 2" "UNRELATED Differ{} witness=1")
  (compares "the witness skips where they agree" "x^2" "x" "UNRELATED Differ{} witness=2")
  (compares "the witness skips removed values" "1/x" "2/x" "UNRELATED Differ{} witness=1")
  (compares "the witness skips the other side's removed values" "x" "x + 1/(x - 0) - 1/x + 1" "UNRELATED Differ{} witness=1")
  (compares "cancelling gives a value back" "(x^2 - 1)/(x - 1)" "x + 1" "GAINS Finite{1} witness=1")
  (compares "writing a fraction takes one away" "x + 1" "(x^2 - 1)/(x - 1)" "LOSES Finite{1} witness=1")
  (compares "one each way" "x/x" "(x + 1)/(x + 1)" "UNRELATED Finite{-1} witness=-1")
  (compares "a factored form keeps its removed values" "(x^2 - 1)/(x - 1)" "((x - 1)(x + 1))/(x - 1)" "EQUIVALENT")
  (compares "a fraction with no real zero below" "(x^3 + x)/(x^2 + 1)" "x" "EQUIVALENT")
  (compares "numbers" "1/2 + 1/3" "5/6" "EQUIVALENT")
  (compares "a surd" "sqrt(2) * sqrt(2)" "2" "EQUIVALENT")
  (compares "a zero denominator" "1/0" "1" "OUT_OF_FRAGMENT empty_domain")
  (compares "bars have no form here" "|x|" "x" "OUT_OF_FRAGMENT expression_form")
  (compares "a root over the variable has no form here" "sqrt(x)" "x" "OUT_OF_FRAGMENT expression_form")
  (compares "too high" "x^6 * x^6" "x" "OUT_OF_FRAGMENT degree_limit")
  (compares "two kinds of root" "sqrt(2)" "sqrt(3)" "OUT_OF_FRAGMENT many_radicals")
  ;; Using a verdict.
  (check "a step that holds" (eq (expression-status "x + x + 1" "x + x + 1" "2x + 1" "2x + 1") :accepted))
  (check "a step that does not" (eq (expression-status "x + x" "x + x" "x^2" "2x") :rejected))
  (check "a finished form ends the task" (expression-solved "x + x + 1" "2x + 1" "2x + 1"))
  (check "a finished form may be in another order" (expression-solved "x + x + 1" "1 + 2x" "2x + 1"))
  (check "a finished form may be one of several"
         (expression-solved "(x + 1)(x + 2)" "x^2 + 3x + 2" "(x + 2)(x + 1)" "x^2 + 3x + 2"))
  (check "an unfinished form does not"
         (not (expression-solved "(x + 1)x + x" "x^2 + x + x" "x^2 + 2x")))
  (check "cancelling can finish a task, and says where"
         (let ((result (check-expression-step "(x^2 - 1)/(x - 1)" "(x^2 - 1)/(x - 1)" "x + 1" '("x + 1"))))
           (and (getf result :solved) (equal (getf result :note) '(1)))))
  (check "a step that loses a value is rejected"
         (eq (expression-status "x + 1" "x + 1" "(x^2 - 1)/(x - 1)" "x + 1") :rejected))
  (check "an unreadable step is not checked"
         (eq (expression-status "x + 1" "x + 1" "x = 1" "x + 1") :out-of-fragment))
  (check "a later step that matches the start stands"
         (eq (expression-status "x + x" "x + x + 1" "2x" "2x") :accepted))
  (compares "two different roots are not compared" "sqrt(2)x + sqrt(3)x" "(sqrt(2) + sqrt(3))x"
            "OUT_OF_FRAGMENT many_radicals")
  (compares "two roots are refused even when one cancels" "sqrt(2)x - sqrt(2)x + sqrt(3)" "sqrt(3)"
            "OUT_OF_FRAGMENT many_radicals")
  (check "a finished form counts only when it keeps the value of the first line"
         (null (getf (check-expression-step "2x + 2x" "x + 2x" "3x" '("3x")) :solved))))
