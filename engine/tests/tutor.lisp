;;;; The practice replies, end to end, on every practice problem. Loaded by run.lisp.

(in-package :symalgebra.engine)

(defvar *practice* (load-practice))

(defun asked (id previous text)
  (practice-check *practice* (list :obj (cons "problem" id) (cons "previous" previous) (cons "text" text))))

(defun hint-for (id previous level)
  (jget (practice-hint *practice* (list :obj (cons "problem" id) (cons "previous" previous)
                                        (cons "level" level)))
        "text"))

(defun walk-practice (problem)
  (let* ((id (jget problem "id")) (previous (jget problem "start")) (answer (jget problem "answer"))
         (last nil))
    (map nil (lambda (step)
               (setf last (asked id previous (jget step "line")))
               (check (format nil "~a accepts ~a" id (jget step "line"))
                      (member (jget last "status") '("accepted" "caution") :test #'string=)
                      (jget last "message"))
               (setf previous (jget step "line")))
         (jget problem "steps"))
    (let ((end (cond ((string= answer "none") (asked id previous "no solution"))
                     ((string= answer "all")
                      (asked id previous (if (jget problem "vars") "infinitely many" "all real numbers")))
                     (t last))))
      (check (format nil "~a ends solved" id) (eq (jget end "solved") :true)))))

(defun dist-m-last-line ()
  (let* ((problem (find "dist-m" *practice* :key (lambda (p) (jget p "id")) :test #'string=))
         (steps (jget problem "steps")))
    (jget (aref steps (1- (length steps))) "line")))

(defun simplify-practice (id previous text)
  (asked id previous text))

(defun graph-of (id)
  (coerce (jget (practice-graph *practice* (list :obj (cons "problem" id))) "points") 'list))

(defun height-at (id x)
  (jget (find x (graph-of id) :key (lambda (p) (jget p "x")) :test #'string=) "y"))

(tier "tutor"
  (check "a graph has a point at each half" (= (length (graph-of "fn-a")) 41))
  (check "a graph starts at -10" (string= (jget (first (graph-of "fn-a")) "x") "-10"))
  (check "a graph ends at 10" (string= (jget (car (last (graph-of "fn-a"))) "x") "10"))
  (check "a height is the function's value" (string= (height-at "fn-a" "3") "7"))
  (check "a height may be a fraction" (string= (height-at "fn-a" "1/2") "2"))
  (check "a curve has its own heights" (string= (height-at "fn-b" "-3") "5"))
  (check "a root has a height" (string= (height-at "fn-j" "3") "1"))
  (check "a root may be rounded" (string= (subseq (height-at "fn-j" "5") 0 2) (subseq "113511/65536" 0 2)))
  (check "outside a root there is no point" (string= (height-at "fn-j" "0") ""))
  (check "a hole has no point" (string= (height-at "fn-k" "3") ""))
  (check "a problem with no graph is refused"
         (handler-case (progn (practice-graph *practice* (list :obj (cons "problem" "fn-c"))) nil)
           (bad-practice () t)))
  (check "two numbers are shown in words"
         (string= (jget (asked "fn-a" "6 + 1" "8") "why") "The line before comes to 7, and this line comes to 8."))
  (check "a line solved for y finishes it" (eq (jget (asked "fn-e" "2x + y = 5" "y = -2x + 5") "solved") :true))
  (check "a log line is checked" (eq (jget (asked "lge-a" "2^x = 8" "x = 3") "solved") :true))
  (let ((reply (asked "lge-a" "2^x = 8" "x = 4")))
    (check "a wrong answer is rejected" (string= (jget reply "status") "rejected"))
    (check "a wrong answer shows a value" (search "x = 3" (jget reply "why"))))
  (let ((reply (asked "lge-d" "2^x = 5" "x = log2(7)")))
    (check "a wrong log shows a log" (search "ln(" (jget reply "why"))))
  (check "a wider line asks for care"
         (string= (jget (asked "lge-i" "log2(x) + log2(x - 2) = 3" "x(x - 2) = 8") "status") "caution"))
  (check "the false root is left out at the end"
         (eq (jget (asked "lge-i" "x = 4 or x = -2" "x = 4") "solved") :true))
  (check "a wrong claim has words" (search "Some value" (jget (asked "lge-a" "2^x = 8" "no solution") "message")))
  (check "a line out of reach says why"
         (search "one log or one power" (jget (asked "lge-a" "2^x = 8" "2^x + x = 8") "message")))
  (check "a log of a negative says why" (search "above zero" (jget (asked "lge-a" "2^x = 8" "x = log2(-1)") "message")))
  (let ((reply (asked "log-a" "log2(8) + log2(4)" "4")))
    (check "a wrong value is rejected" (string= (jget reply "status") "rejected"))
    (check "a wrong value shows both"
           (string= (jget reply "why") "The first line comes to 5, and this line comes to 4.")))
  (check "a wrong expression has no numbers" (string= (jget (asked "exp-b" "x^2 * x^3" "x^6") "why") ""))
  (check "a value out of reach says why" (search "powers of x" (jget (asked "exp-b" "x^2 * x^3" "x^9") "message")))
  (check "a hint on a log follows the path" (string= (hint-for "lge-a" "2^x = 8" 2) "2^x = 2^3"))
  (check "a hint on a value follows the path" (string= (hint-for "log-a" "log2(8) + log2(4)" 2) "3 + 2"))
  (check "a hint off the path talks of powers" (search "powers" (hint-for "lge-a" "2^x = 9 - 1 + 0" 1)))
  (check "a hint at no steps uses the nudge" (search "ever" (hint-for "lge-n" "2^x = -4" 1)))
  (let ((reply (asked "cpx-d" "(2 + i)(3 - i)" "7 - i")))
    (check "a wrong number is rejected" (string= (jget reply "status") "rejected"))
    (check "a wrong number shows both"
           (string= (jget reply "why") "The first line comes to 7 + i, and this line comes to 7 - i.")))
  (check "the right number is accepted" (eq (jget (asked "cpx-d" "(2 + i)(3 - i)" "7 + i") "solved") :true))
  (let ((reply (asked "cpx-k" "x^2 + 4 = 0" "x = 2i")))
    (check "a lost root is rejected" (string= (jget reply "status") "rejected"))
    (check "a lost root is shown" (string= (jget reply "why") "x = -2i solves the first line, and not this one.")))
  (check "a gained root is shown"
         (search "solves this line" (jget (asked "cpx-o" "2x + 3i = 1" "x^2 + 1 = 0 or x = (1 - 3i)/2") "why")))
  (check "a line out of reach says so"
         (search "up to a quadratic" (jget (asked "cpx-k" "x^2 + 4 = 0" "x^3 = 2") "message")))
  (check "a hint on a number follows the path" (string= (hint-for "cpx-a" "(2 + 3i) + (1 - i)" 2) "2 + 1 + 3i - i"))
  (check "a hint on an equation follows the path" (string= (hint-for "cpx-k" "x^2 + 4 = 0" 2) "x^2 = -4"))
  (check "a hint off the path uses i" (search "i^2 = -1" (hint-for "cpx-k" "x^2 + 5 = 1 + i - i" 1)))
  (check "a complex problem offers x" (find-if (lambda (p) (and (string= (jget p "id") "cpx-a") (string= (jget p "var") "x")))
                                               (coerce (jget (practice-list *practice*) "problems") 'list)))
  (let ((reply (asked "sys-a" "x + y = 5, x - y = 1" "2x = 6")))
    (check "a combined line stands" (string= (jget reply "status") "accepted"))
    (check "a combined line is named" (search "y drops out" (aref (jget reply "explanations") 0))))
  (check "a line solved for one letter is named"
         (search "x a value" (aref (jget (asked "sys-a" "2x = 6" "x = 3") "explanations") 0)))
  (let ((reply (asked "sys-a" "x + y = 5, x - y = 1" "x = 9")))
    (check "a wrong line of a system is rejected" (string= (jget reply "status") "rejected"))
    (check "a wrong line shows the point it missed"
           (string= (jget reply "why") "x = 3, y = 2 fits the first line, and not this one.")))
  (check "a line wider than the system shows a point of its own"
         (search "fits this line"
                 (jget (asked "sys-h" "x + y = 2, x + y = 5" "x = 100") "why")))
  (check "a wrong claim on a system has words"
         (search "does have a solution" (jget (asked "sys-a" "x + y = 5, x - y = 1" "no solution") "message")))
  (check "a wrong many claim has words"
         (search "infinitely" (jget (asked "sys-a" "x + y = 5, x - y = 1" "infinitely many") "message")))
  (check "a nonlinear line of a system says why"
         (search "2x + 3y" (jget (asked "sys-a" "x + y = 5, x - y = 1" "xy = 1") "message")))
  (check "the first hint on the path is the step's reason"
         (string= (hint-for "sys-a" "x + y = 5, x - y = 1" 1)
                  (jget (aref (jget (find-practice *practice* "sys-a") "steps") 0) "why")))
  (check "a hint on a system follows the path"
         (string= (hint-for "sys-a" "x + y = 5, x - y = 1" 2) "2x = 6"))
  (check "a hint off the path of a system is general"
         (search "Pick a letter" (hint-for "sys-a" "x + y = 7, x - y = 1" 1)))
  (check "a hint at the end of an empty system points to the buttons"
         (search "buttons" (hint-for "sys-h" "0 = 3" 1)))
  (let ((reply (simplify-practice "rat-a" "(x^2 - 1)/(x - 1)" "x + 1")))
    (check "a cancelled line says where it holds"
           (string= (jget reply "note") "This holds wherever x is not 1."))
    (check "a cancelled line can finish a task" (eq (jget reply "solved") :true)))
  (let ((reply (simplify-practice "poly-a" "x^2 + 5x + 6" "(x^3 + 5x^2 + 6x)/x")))
    (check "a line that loses a value says so"
           (search "no value somewhere" (jget reply "message")))
    (check "the witness of a lost value has no number to show"
           (search "this line has no value" (jget reply "why"))))
  (let ((reply (simplify-practice "rat-a" "x + 1" "x + 2")))
    (check "a wrong step is rejected" (string= (jget reply "status") "rejected"))
    (check "a wrong step shows both numbers"
           (string= (jget reply "why") "At x = 0 the line before comes to 1, and this line comes to 2.")))
  (check "an expression step names its rule"
         (plusp (length (jget (simplify-practice "poly-d" "x^3 - 8" "(x - 2)(x^2 + 2x + 4)") "explanations"))))
  (check "a hint on an expression follows the path"
         (string= (hint-for "rat-a" "(x^2 - 1)/(x - 1)" 2) "((x - 1)(x + 1))/(x - 1)"))
  (check "a hint off the path of an expression is general"
         (search "factor" (hint-for "rat-a" "x + 7" 1)))
  (check "the steps of an expression have words"
         (let ((steps (jget (practice-solution *practice* (list :obj (cons "problem" "poly-d"))) "steps")))
           (search "difference of two cubes" (jget (aref steps 0) "why"))))
  (check "every solved problem is on the page" (= (length *practice*) 209))
  (mapc #'walk-practice *practice*)
  (let ((listed (jget (practice-list *practice*) "problems")))
    (check "the list has only practice areas"
           (every (lambda (p) (member (jget p "area") *practice-areas* :test #'string=))
                  listed)))
  ;; The explanation fills in what the rule matched.
  (let ((good (asked "dist-a" "2(x + 3) = 10" "2x + 2 * 3 = 10")))
    (check "a valid step is not yet solved" (eq (jget good "solved") :false))
    (check "a step names its rule"
           (string= (aref (jget good "explanations") 0) "Multiply 2 by each term in the brackets.")
           (jget good "explanations")))
  ;; An unnamed valid step is still accepted: naming never decides.
  (let ((unnamed (asked "dist-a" "2(x + 3) = 10" "x = 2")))
    (check "a valid leap is accepted and solved" (eq (jget unnamed "solved") :true)))
  ;; A wrong step gets a counterexample built from the two lines.
  (let ((wrong (asked "dist-a" "2(x + 3) = 10" "2x + 3 = 10")))
    (check "a wrong step is rejected" (string= (jget wrong "status") "rejected"))
    (check "the witness is shown in words"
           (string= (jget wrong "why")
                    "x = 2 solves the line before. Put it into this line and it says 7 = 10.")
           (jget wrong "why")))
  (let ((lost (asked "dist-l" "2(x + 1) = 2x + 2" "x = 1")))
    (check "losing values is rejected" (string= (jget lost "status") "rejected")))
  (let ((gain (asked "dist-a" "x = 2" "x^2 = 4")))
    (check "a gained value names the new line first"
           (search "solves this line" (jget gain "why")) (jget gain "why")))
  (let ((caution (asked "frac-f" "x/(x - 1) = 1/(x - 1)" "x = 1")))
    (check "a gained root cautions and stays unsolved"
           (and (string= (jget caution "status") "caution") (eq (jget caution "solved") :false))))
  (check "a wrong claim is not solved"
         (eq (jget (asked "dist-a" "2(x + 3) = 10" "no solution") "solved") :false))
  (check "a wrong claim gets words"
         (search "Some value of x" (jget (asked "dist-a" "2(x + 3) = 10" "no solution") "message")))
  (check "an unreadable line is not a wrong line"
         (string= (jget (asked "dist-a" "2(x + 3) = 10" "2x +") "status") "not_checked"))
  (check "a question is asked for 1/2x"
         (search "brackets" (jget (asked "dist-a" "2(x + 3) = 10" "1/2x = 3") "message")))
  (check "an unknown problem is a bad request"
         (handler-case (progn (asked "nope" "x = 1" "x = 1") nil) (bad-practice () t)))
  (check "a long line is a bad request"
         (handler-case (progn (asked "dist-a" "x = 1" (make-string 257 :initial-element #\1)) nil)
           (bad-practice () t)))
  ;; Square roots.
  (let ((lost (asked "quad-m" "x^2 = 2" "x = sqrt(2)")))
    (check "a lost negative root is rejected" (string= (jget lost "status") "rejected"))
    (check "its witness is a root, in words"
           (string= (jget lost "why")
                    "x = -sqrt(2) solves the line before. Put it into this line and it says -sqrt(2) = sqrt(2).")
           (jget lost "why")))
  (check "two different roots still get an honest reply"
         (string= (jget (asked "quad-m" "x^2 = 2" "x + sqrt(3) = 0") "why")
                  "x = -sqrt(2) solves one of these lines and not the other.")
         (jget (asked "quad-m" "x^2 = 2" "x + sqrt(3) = 0") "why"))
  (check "a negative under the root gets words"
         (search "no real square root" (jget (asked "quad-m" "x^2 = 2" "x = sqrt(-2)") "message")))
  (check "a problem with no real answer is solved by saying so"
         (eq (jget (asked "quad-v" "x^2 + x + 1 = 0" "no solution") "solved") :true))
  (check "a named formula step"
         (string= (aref (jget (asked "quad-r" "x^2 - 3x - 1 = 0"
                                     (format nil "x = (3 ~c sqrt(13))/2" (code-char 177)))
                              "explanations")
                        0)
                  "This is the quadratic formula with a = 1, b = -3 and c = -1."))
  (flet ((said (previous text)
           (jget (practice-check *practice* (list :obj (cons "problem" "lin-i") (cons "previous" previous)
                                                  (cons "text" text)))
                 "explanations")))
    (check "a checked step says each thing once"
           (= 1 (length (said "3x + 2 - 3x = 3x + 5 - 3x" "2 = 5")))))
  (check "a caution says each thing once"
         (= 1 (length (jget (practice-check *practice*
                                            (list :obj (cons "problem" "frac-f")
                                                  (cons "previous" "x/(x - 1) * (x - 1) = 1/(x - 1) * (x - 1)")
                                                  (cons "text" "x = 1")))
                            "explanations"))))
  ;; Worked solutions.
  (dolist (problem *practice*)
    (let* ((id (jget problem "id"))
           (shown (practice-solution *practice* (list :obj (cons "problem" id))))
           (steps (jget shown "steps")))
      (check (format nil "~a shows every step" id) (= (length steps) (length (jget problem "steps"))))
      (check (format nil "~a says why at each step" id)
             (every (lambda (step) (plusp (length (jget step "why")))) steps))
      (check (format nil "~a says how it ends" id)
             (or (plusp (length steps)) (plusp (length (jget shown "ending")))))))
  (let ((first-step (aref (jget (practice-solution *practice* (list :obj (cons "problem" "dist-a"))) "steps") 0)))
    (check "a shown step has its line" (string= (jget first-step "line") "2x + 2 * 3 = 10"))
    (check "a shown step has its reason" (search "Multiply 2" (jget first-step "why"))))
  (flet ((why (id line)
           (jget (find line (jget (practice-solution *practice* (list :obj (cons "problem" id))) "steps")
                       :test #'string= :key (lambda (step) (jget step "line")))
                 "why")))
    (check "a later step explains itself, not the first line"
           (search "Subtract 6" (why "dist-a" "2x = 10 - 6")))
    (check "a reason says each thing once"
           (string= (why "lin-i" "2 = 5") "Anything minus itself is 0."))
    (check "a reordered line says so"
           (string= (why "dist-d" "3x + x + 2 = 14") "The same terms, written in a different order."))
    (check "a line with no one rule says so"
           (string= (why "dist-i" "4x - 4 = 2x + 6") "This line does several moves at once.")))
  (check "a problem with no solution says so at the end"
         (search "no real solution"
                 (jget (practice-solution *practice* (list :obj (cons "problem" "quad-v"))) "ending")))
  (check "an unknown problem has no solution to show"
         (handler-case (progn (practice-solution *practice* (list :obj (cons "problem" "nope"))) nil)
           (bad-practice () t)))
  ;; Hints.
  (check "the first hint is the next rule, filled in"
         (string= (hint-for "dist-a" "2(x + 3) = 10" 1) "Multiply 2 by each term in the brackets.")
         (hint-for "dist-a" "2(x + 3) = 10" 1))
  (check "the last hint is the next line"
         (string= (hint-for "dist-a" "2(x + 3) = 10" 2) "2x + 2 * 3 = 10")
         (hint-for "dist-a" "2(x + 3) = 10" 2))
  (check "a reordered line is still on the path"
         (string= (hint-for "dist-c" "2x + 3x = 15" 2) (hint-for "dist-c" "3x + 2x = 15" 2)))
  (check "an off-path line gets general words"
         (search "same side" (hint-for "dist-a" "2x + 7 = 11" 1)))
  (check "a finished line says so"
         (search "already" (hint-for "dist-a" "x = 2" 1)))
  (check "a dead end points at the buttons"
         (search "buttons" (hint-for "dist-m" (dist-m-last-line) 1)))
  (check "a problem with no steps points at the formula"
         (search "under the root" (hint-for "quad-v" "x^2 + x + 1 = 0" 1)))
  (check "a bad hint level is a bad request"
         (handler-case (progn (hint-for "dist-a" "x = 1" 9) nil) (bad-practice () t))))
