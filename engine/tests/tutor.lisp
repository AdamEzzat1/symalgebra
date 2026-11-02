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
                     ((string= answer "all") (asked id previous "all real numbers"))
                     (t last))))
      (check (format nil "~a ends solved" id) (eq (jget end "solved") :true)))))

(defun dist-m-last-line ()
  (let* ((problem (find "dist-m" *practice* :key (lambda (p) (jget p "id")) :test #'string=))
         (steps (jget problem "steps")))
    (jget (aref steps (1- (length steps))) "line")))

(tier "tutor"
  (check "27 practice problems" (= (length *practice*) 27))
  (mapc #'walk-practice *practice*)
  (let ((listed (jget (practice-list *practice*) "problems")))
    (check "the list has only practice areas"
           (every (lambda (p) (member (jget p "area") '("distribution" "fractions") :test #'string=)) listed)))
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
  (check "a bad hint level is a bad request"
         (handler-case (progn (hint-for "dist-a" "x = 1" 9) nil) (bad-practice () t))))
