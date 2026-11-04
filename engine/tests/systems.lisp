;;;; Systems of linear equations. Loaded by run.lisp, after expressions.lisp.

(in-package :symalgebra.engine)

(defmacro system-says (name before after wanted &optional (vars "xy"))
  `(check ,name (string= (system-text (check-systems ,before ,after ,vars)) ,wanted)
          (system-text (check-systems ,before ,after ,vars))))

(defun system-status (line0 text &optional (vars "xy"))
  (getf (check-system-step line0 text vars) :status))

(defun system-solved (line0 text &optional (vars "xy"))
  (getf (check-system-step line0 text vars) :solved))

(tier "systems"
  ;; Reading.
  (check "two equations are read" (= (length (parse-system "x + y = 3, x - y = 1" "xy")) 2))
  (check "a second variable reads as itself"
         (equal (first (parse-system "y = 2x" "xy")) '(= :y (* 2 :x))))
  (check "the second variable multiplies" (equal (first (parse-system "2y = 1" "xy")) '(= (* 2 :y) 1)))
  (check "a third variable reads" (equal (first (parse-system "z = 1" "xyz")) '(= :z 1)))
  (check "an equation with no second variable stays one line" (equal (parse-line "x = 1") '(= :x 1)))
  (check "y is unknown outside a system" (eq (getf (check-lines "y = 1" "x = 1") :verdict) :out-of-fragment))
  ;; Refusals.
  (system-says "a product of variables" "xy = 1" "x = 1" "OUT_OF_FRAGMENT nonlinear_system")
  (system-says "a square" "x^2 + y = 1" "x = 1" "OUT_OF_FRAGMENT nonlinear_system")
  (system-says "a variable below" "1/x + y = 1" "x = 1" "OUT_OF_FRAGMENT nonlinear_system")
  (system-says "a root" "sqrt(x) = 1" "x = 1" "OUT_OF_FRAGMENT nonlinear_system")
  (system-says "a zero below" "x/0 = 1" "x = 1" "OUT_OF_FRAGMENT empty_domain")
  (system-says "an inequality" "x < 1" "x = 1" "OUT_OF_FRAGMENT unparsed")
  (system-says "no equals" "x + y" "x = 1" "OUT_OF_FRAGMENT unparsed")
  (system-says "two equals" "x = y = 1" "x = 1" "OUT_OF_FRAGMENT chain")
  (system-says "too many" "x = 1, y = 1, x = 1, y = 1, x = 1" "x = 1" "OUT_OF_FRAGMENT too_many_equations")
  (system-says "another letter" "w = 1" "x = 1" "OUT_OF_FRAGMENT unknown_symbol")
  ;; Linear forms.
  (system-says "numbers worked out" "2 * 3x = 6" "x = 1" "EQUIVALENT")
  (system-says "a power of a number" "2^3 x = 8" "x = 1" "EQUIVALENT")
  (system-says "a power of one" "x^1 = 8" "x = 8" "EQUIVALENT")
  (system-says "dividing by a number" "x/2 + y/3 = 1" "3x + 2y = 6" "EQUIVALENT")
  (system-says "dividing by a sum of numbers" "x/(1 + 1) = 1" "x = 2" "EQUIVALENT")
  (system-says "brackets" "2(x + y) - (x - y) = 3" "x + 3y = 3" "EQUIVALENT")
  (system-says "a product with the number second" "x * 2 = 4" "x = 2" "EQUIVALENT")
  (system-says "a negative" "-x = 1" "x = -1" "EQUIVALENT")
  ;; Verdicts.
  (system-says "the same system" "x + y = 3, x - y = 1" "x = 2, y = 1" "EQUIVALENT")
  (system-says "in another order" "x + y = 3, x - y = 1" "x - y = 1, x + y = 3" "EQUIVALENT")
  (system-says "a line that follows" "x + y = 3, x - y = 1" "2x = 4" "GAINS System witness=(2,0)")
  (system-says "narrowing a line" "2x = 4" "x + y = 3, x - y = 1" "LOSES System witness=(2,0)")
  (system-says "a line that does not follow" "x + y = 3, x - y = 1" "x = 5" "UNRELATED System witness=(2,1)")
  (system-says "a witness on the other side" "x = 1" "y = 1" "UNRELATED System witness=(1,0)")
  (system-says "nothing fits the line before" "x = 1, x = 2" "y = 1" "GAINS System witness=(0,1)")
  (system-says "nothing fits this line" "y = 1" "x = 1, x = 2" "LOSES System witness=(0,1)")
  (system-says "both empty" "x = 1, x = 2" "0 = 1" "EQUIVALENT")
  (system-says "no point on the line before" "x = 1, x = 2" "0 = 1, x = 1" "EQUIVALENT")
  (system-says "three variables" "x + y + z = 6, y - z = 0, z = 1" "x = 4, y = 1, z = 1" "EQUIVALENT" "xyz")
  (system-says "a free variable's first choice" "x + y = 1" "x = 1, y = 0" "LOSES System witness=(0,1)")
  (system-says "free variables in order" "z = 1" "x = 0, y = 0, z = 1" "LOSES System witness=(0,1,1)" "xyz")
  ;; Using a verdict.
  (check "a line that follows stands" (eq (system-status "x + y = 3, x - y = 1" "2x = 4") :accepted))
  (check "a substituted line stands" (eq (system-status "x + y = 3, x - y = 1" "(3 - y) - y = 1") :accepted))
  (check "a line that does not follow is rejected" (eq (system-status "x + y = 3, x - y = 1" "x = 5") :rejected))
  (check "a line out of reach is not checked" (eq (system-status "x + y = 3" "xy = 1") :out-of-fragment))
  (check "both values finish it" (system-solved "x + y = 3, x - y = 1" "x = 2, y = 1"))
  (check "the values may be the other way round" (system-solved "x + y = 3, x - y = 1" "1 = y, 2 = x"))
  (check "fractions finish it" (system-solved "2x = 1, y = 1" "x = 1/2, y = 1"))
  (check "one value does not" (not (system-solved "x + y = 3, x - y = 1" "x = 2")))
  (check "the system again does not" (not (system-solved "x + y = 3, x - y = 1" "x - y = 1, x + y = 3")))
  (check "the same variable twice does not" (not (system-solved "x = 1, y = 1" "x = 1, x = 1")))
  (check "a whole line that is not an answer does not" (not (system-solved "x + y = 3, y = 1" "x + 1 = 3, y = 1")))
  (check "no solution can be right" (system-solved "x + y = 1, x + y = 2" "no solution"))
  (check "no solution can be wrong" (eq (system-status "x + y = 1" "no solution") :rejected))
  (check "infinitely many can be right" (system-solved "x + y = 1, 2x + 2y = 2" "infinitely many"))
  (check "infinitely many can be wrong" (eq (system-status "x = 1, y = 1" "infinitely many") :rejected))
  (check "a contradiction has not infinitely many" (eq (system-status "x = 1, x = 2" "infinitely many") :rejected))
  (check "a wrong line on an empty system is rejected" (eq (system-status "x + y = 1, x + y = 2" "x = 100") :rejected))
  (check "a right line on an empty system stands" (eq (system-status "x + y = 1, x + y = 2" "0 = 1") :accepted))
  ;; A task that ends on one line.
  (check "a line solved for y finishes it"
         (getf (check-system-step "2x + y = 3" "y = 3 - 2x" "xy" "y") :solved))
  (check "y with y on the other side does not"
         (not (getf (check-system-step "2x + y = 3" "y = 3 - 2x - y + y" "xy" "y") :solved)))
  (check "the same line in another form does not"
         (not (getf (check-system-step "2x + y = 3" "2x + y - 3 = 0" "xy" "y") :solved)))
  (check "y on the right does not" (not (getf (check-system-step "2x + y = 3" "3 - 2x = y" "xy" "y") :solved)))
  ;; Words.
  (check "elimination is named"
         (search "drops out" (system-words "x + y = 3, x - y = 1" "x + y = 3, x - y = 1" "2x = 4" "xy")))
  (check "the variable named is the one gone"
         (search "y drops" (system-words "x + y = 3, x - y = 1" "x + y = 3, x - y = 1" "2x = 4" "xy")))
  (check "a value is named"
         (search "x a value" (system-words "x + y = 3, x - y = 1" "2x = 4" "x = 2" "xy")))
  (check "the first line has no move" (null (system-words "x = 1" "x = 1" "x = 1" "xy")))
  (check "a line with no clear move has no words"
         (null (system-words "x + y = 3, x - y = 1" "x + y = 3, x - y = 1" "x + y = 3, 2x = 4" "xy")))
  (check "a goal line that drops an equation does not finish"
         (null (getf (check-system-step "x + y = 3, x - y = 1" "y = 3 - x" "xy" "y") :solved)))
  (check "a goal is one equation"
         (null (getf (check-system-step "2x + y = 5" "y = -2x + 5, y = -2x + 5" "xy" "y") :solved)))
  (check "a letter missing from one of two equations is not a combination"
         (null (system-words "x + y = 3, x - y = 1" "x + y = 3, x - y = 1" "2x = 4, x + y = 5" "xy")))
  (check "one letter twice is not an answer" (null (system-solved "x = 1, 2x = 2" "x = 1, x = 1"))))
