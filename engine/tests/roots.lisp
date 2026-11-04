;;;; Radical equations: the variable under a square root. Loaded by run.lisp, after ranges.lisp.

(in-package :symalgebra.engine)

(defun accepted-as (previous text)
  (getf (check-step previous previous text) :status))

(tier "roots"
  ;; Reading.
  (check "a root over the variable is read" (equal (parse-line "sqrt(x) = 3") '(= (sqrt :x) 3)))
  (check "a root over a sum is read"
         (equal (parse-line "sqrt(x + 1) = 3") '(= (sqrt (+ :x 1)) 3)))
  ;; Equations.
  (says-text "squaring a root that is alone" "sqrt(x) = 3" "x = 9" "EQUIVALENT")
  (says-text "squaring a root over a sum" "sqrt(x + 3) = 5" "x + 3 = 25" "EQUIVALENT")
  (says-text "a root that cannot be negative" "sqrt(x) = -1" "0 = 1" "EQUIVALENT")
  (says-text "squaring adds a false answer" "sqrt(x + 2) = x" "x + 2 = x^2" "GAINS Finite{-1} witness=-1")
  (says-text "the answer that survives" "sqrt(x + 2) = x" "x = 2" "EQUIVALENT")
  (says-text "keeping the false answer" "sqrt(x + 2) = x" "x = 2 or x = -1" "GAINS Finite{-1} witness=-1")
  (says-text "a wrong answer" "sqrt(x) = 3" "x = 3" "UNRELATED Finite{9} witness=9")
  (says-text "two roots" "sqrt(x + 5) = sqrt(2x + 1)" "x = 4" "EQUIVALENT")
  (says-text "two roots and a number" "sqrt(x) + sqrt(x + 5) = 5" "x = 4" "EQUIVALENT")
  (says-text "a surd answer" "sqrt(x) = x - 1" "x = (3 + sqrt(5))/2" "EQUIVALENT")
  (says-text "a root squared" "sqrt(x)^2 = 4" "x = 4" "EQUIVALENT")
  (says-text "a root's domain counts" "sqrt(x)^2 = x" "x >= 0" "EQUIVALENT")
  (says-text "the domain of a root over a difference" "sqrt(x - 1) = sqrt(x - 1)" "x >= 1" "EQUIVALENT")
  (says-text "a root times itself" "sqrt(x) * sqrt(x) = x" "x >= 0" "EQUIVALENT")
  (says-text "a root over a fraction" "sqrt(1/x) = 2" "x = 1/4" "EQUIVALENT")
  (says-text "a root beside a fraction" "sqrt(x)/2 = 3" "x = 36" "EQUIVALENT")
  (says-text "a fraction's zero still counts" "sqrt(x) + 1/x = 1 + 1/x" "x = 1" "EQUIVALENT")
  ;; Inequalities and bars.
  (says-text "a root below a number" "sqrt(x) < 3" "0 <= x < 9" "EQUIVALENT")
  (says-text "the domain is not lost" "sqrt(x) < 3" "x < 9" "GAINS Ranges{(-inf,0)} witness=-1")
  (says-text "a root above a number" "sqrt(x - 1) >= 2" "x >= 5" "EQUIVALENT")
  (says-text "a root above a line" "sqrt(x) > x" "0 < x < 1" "EQUIVALENT")
  (says-text "bars around a root" "|sqrt(x) - 2| = 1" "x = 1 or x = 9" "EQUIVALENT")
  (says-text "bars under a root" "sqrt(|x|) = 2" "x = 4 or x = -4" "EQUIVALENT")
  ;; Refusals.
  (says-text "a root under a root" "sqrt(sqrt(x)) = 1" "x = 1" "OUT_OF_FRAGMENT nested_radical")
  (says-text "a root in a denominator" "1/sqrt(x) = 1" "x = 1" "OUT_OF_FRAGMENT radical_denominator")
  (says-text "too many roots" "sqrt(x) + sqrt(x + 1) + sqrt(x + 2) + sqrt(x + 3) = 1" "x = 1"
             "OUT_OF_FRAGMENT radical_limit")
  (says-text "a number's root stays checked" "sqrt(x) = sqrt(-1)" "x = 1" "OUT_OF_FRAGMENT negative_radicand")
  ;; Using a verdict.
  (check "squaring may add a value, so it stays" (eq (accepted-as "sqrt(x + 2) = x" "x + 2 = x^2") :caution))
  (check "a caution does not finish the problem"
         (not (getf (check-step "sqrt(x + 2) = x" "sqrt(x + 2) = x" "x + 2 = x^2") :solved)))
  (check "dropping the false answer is the first line again"
         (solved-at "sqrt(x + 2) = x" "x = 2 or x = -1" "x = 2"))
  (check "a line with a true answer only is an answer" (solved-at "sqrt(x) = 3" "sqrt(x) = 3" "x = 9"))
  (check "no solution can be right"
         (eq (accepted-as "sqrt(x) = -1" "no solution") :accepted))
  (check "no solution can be wrong"
         (eq (accepted-as "sqrt(x) = 1" "no solution") :rejected))
  ;; Explaining.
  (check "squaring both sides is named"
         (search "Square both sides" (format nil "~{~a ~}" (explained "sqrt(x + 3) = 5" "x + 3 = 5^2"))))
  (check "a root squared is named"
         (search "root" (format nil "~{~a ~}" (explained "sqrt(x)^2 = 4" "x = 4"))))
  (check "a rejected root shows both sides"
         (search "it says 9 = 3" (why-text "sqrt(x) = 3" "x = 3" (check-lines "sqrt(x) = 3" "x = 3") #\x)))
  ;; Exact work: the sign in a gap comes from bounds, and agrees with an exact value when both exist.
  (check "bounds hold a root"
         (destructuring-bind (low . high) (bracket '(sqrt :x) 2 64)
           (and (< low high) (< (* low low) 2) (> (* high high) 2))))
  (check "bounds tighten with precision"
         (flet ((width (precision) (destructuring-bind (low . high) (bracket '(sqrt :x) 2 precision)
                                     (- high low))))
           (< (width 128) (width 64))))
  (check "bounds on a surd hold it"
         (destructuring-bind (low . high) (bracket :x (surd 1 1 2) 64)
           (and (< 2414/1000 low) (< high 2415/1000))))
  (check "bounds on a surd less a root are in order"
         (destructuring-bind (low . high) (bracket :x (surd 1 -1 2) 64)
           (and (< -415/1000 low) (< low high) (< high -414/1000))))
  (check "bounds on a size stay at zero or above"
         (eql (with-fuel (difference-sign '(abs (- (sqrt :x) 5)) 0 (surd 1 1 2))) 1))
  (check "a difference too small for the bounds is worked out exactly"
         (eql (with-fuel (difference-sign '(sqrt (^ :x 2)) 0 (expt 2 -2000))) 1)))
