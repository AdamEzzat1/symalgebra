;;;; The practice page's replies. Stateless: every reply depends only on the request and the
;;;; problem file. The verdict comes from check-step, and attribution only adds words afterwards.

(in-package :symalgebra.engine)

(define-condition bad-practice (error) ())

(defparameter *practice-areas*
  '("linear" "distribution" "fractions" "quadratics" "inequalities" "absolute"
    "radicals" "polynomials" "rational" "systems" "complex" "exponents" "logarithms" "functions"))

(defun read-json-file (path)
  (with-open-file (in path :external-format :utf-8)
    (let ((text (make-string (file-length in))))
      (parse-json (subseq text 0 (read-sequence text in))))))

(defun load-practice (&optional (path "corpus/solutions.json"))
  (remove-if-not (lambda (p) (member (jget p "area") *practice-areas* :test #'string=))
                 (coerce (read-json-file path) 'list)))

(defun line-variable (line)
  "The first letter of LINE that is not part of a function's name."
  (let ((at 0))
    (loop
      (let ((i (position-if #'alpha-char-p line :start at)))
        (unless i (return #\x))
        (let ((word (find-if (lambda (w) (eql (search w line :start2 i) i)) '("sqrt" "abs" "log" "ln"))))
          (if word
              (setf at (+ i (length word)))
              (return (char line i))))))))

(defun reply (&rest fields)
  (list* :obj (cons "v" 1)
         (loop for (key value) on fields by #'cddr collect (cons key value))))

(defun task-variable (problem)
  (if (or (complex-task-p problem) (log-task-p problem))
      #\x
      (line-variable (jget problem "start"))))

(defun practice-list (problems)
  (reply "problems"
         (map 'vector
              (lambda (p)
                (list :obj (cons "id" (jget p "id")) (cons "area" (jget p "area"))
                      (cons "start" (jget p "start"))
                      (cons "prompt" (or (jget p "prompt") ""))
                      (cons "ask" (or (jget p "ask") ""))
                      (cons "vars" (or (jget p "vars") ""))
                      (cons "form" (or (jget p "form") ""))
                      (cons "graph" (or (jget p "graph") ""))
                      (cons "var" (string (task-variable p)))))
              problems)))

(defun find-practice (problems id)
  (or (and (stringp id) (find id problems :key (lambda (p) (jget p "id")) :test #'string=))
      (error 'bad-practice)))

(defun request-text (request key)
  (let ((value (jget request key)))
    (unless (and (stringp value) (<= (length value) 256)) (error 'bad-practice))
    value))

(defun says (line x)
  "What LINE, a tree, comes to at X."
  (if (member (first line) '(or and))
      (if (holds line x) "it holds" "it does not hold")
      (let ((left (value (second line) x)) (right (value (third line) x)))
        (if (and left right)
            (format nil "it says ~a ~a ~a" (rational-text left) (first line) (rational-text right))
            "it has no value there"))))

(defun why-text (previous text verdict var)
  "The witness in words, tested against the two lines as typed."
  (let* ((before (parse-line previous var)) (after (parse-line text var))
         (x (getf verdict :witness)) (shown (rational-text x)))
    (handler-case
        (if (holds before x)
            (format nil "~a = ~a solves the line before. Put it into this line and ~a." var shown (says after x))
            (format nil "~a = ~a solves this line. Put it into the line before and ~a." var shown (says before x)))
      ;; A witness and a line can hold two different roots, which have no common form to print.
      (refused () (format nil "~a = ~a solves one of these lines and not the other." var shown)))))

(defun expression-rules ()
  (remove-if-not (lambda (rule) (eq (rule-field rule :level) 'expr)) *rules*))

(defun explanations (previous text var)
  "Words for an accepted step, or an empty vector when no rule names it."
  (handler-case
      (let ((found (attribute (read-tree previous var) (read-tree text var)
                              :rules (if *expression-task* (expression-rules) *rules*))))
        (coerce (remove-duplicates (mapcar (lambda (use) (use-text use var)) (getf found :uses))
                                   :test #'string= :from-end t)
                'vector))
    (error () #())))

(defun refusal-text (reason)
  (cond ((string= reason "ambiguous_division")
         "Please add brackets: this could be read two ways, such as (1/2)x or 1/(2x).")
        ((string= reason "unparsed") "I could not read this line. Check it for a missing number or bracket.")
        ((string= reason "negative_radicand")
         "A negative number has no real square root, so this line has no value. Check the number under the root.")
        ((string= reason "log_domain")
         "A logarithm needs a number above zero, so this line has no value. Check the number inside it.")
        ((string= reason "log_form")
         "Not checked. This page reads one log or one power in x at a time, or logs of one base added together.")
        ((string= reason "log_bases")
         "Not checked. These logs have different bases. Write them all in one base.")
        ((string= reason "exponent_range")
         "Not checked. This page reads powers of x up to 6, whole numbers only.")
        ((string= reason "complex_degree")
         "Not checked. This page reads lines up to a quadratic over the complex numbers.")
        ((string= reason "nonlinear_system")
         "Not checked. In a system each letter stands alone, so this page reads 2x + 3y but not xy or x^2.")
        ((string= reason "many_radicals")
         "Not checked. These lines hold two different square roots, and this page can only compare one kind at a time.")
        (t "Not checked. This line is outside what this page covers.")))

(defun claim-text (text var)
  (if (string= text "no solution")
      (format nil "Some value of ~a does work here. Keep going." var)
      (format nil "Not every value of ~a works here. Keep going." var)))

(defun solved-flag (result)
  (if (getf result :solved) :true :false))

(defun claim-p (text)
  (member text '("no solution" "all real numbers") :test #'string=))

(defun expression-task-p (problem)
  (equal (jget problem "kind") "expression"))

(defun comes-to (value)
  (if value (format nil "comes to ~a" (rational-text value)) "has no value"))

(defun expression-why (previous text verdict var)
  "The witness in words, tested against the two expressions as typed."
  (let ((x (getf verdict :witness)))
    (handler-case
        (format nil "At ~a = ~a the line before ~a, and this line ~a." var (rational-text x)
                (comes-to (value (parse-expression-line previous var) x))
                (comes-to (value (parse-expression-line text var) x)))
      (refused () (format nil "They differ at ~a = ~a." var (rational-text x))))))

(defun numbers-why (before after)
  "Two numbers in words, when neither line has a variable."
  (format nil "The line before ~a, and this line ~a." (comes-to (value before 0)) (comes-to (value after 0))))

(defun expression-note (values var)
  (if values
      (format nil "This holds wherever ~a is not ~{~a~^ or ~}." var (mapcar #'rational-text values))
      ""))

(defun expression-reply (problem request)
  (let* ((*expression-task* t)
         (start (jget problem "start"))
         (var (line-variable start))
         (previous (request-text request "previous"))
         (text (request-text request "text"))
         (result (check-expression-step start previous text (coerce (jget problem "finished") 'list) :var var))
         (verdict (getf result :verdict)))
    (ecase (getf result :status)
      (:accepted
       (reply "status" "accepted" "solved" (solved-flag result)
              "explanations" (explanations previous text var)
              "note" (expression-note (getf result :note) var)))
      (:rejected
       (reply "status" "rejected" "solved" :false
              "message" (if (eq (getf verdict :verdict) :loses)
                            "This line has no value somewhere the line before does."
                            "These two lines are not the same expression.")
              "why" (let ((before (parse-expression-line previous var)) (after (parse-expression-line text var)))
                      (if (or (has-variable-p before) (has-variable-p after))
                          (expression-why previous text verdict var)
                          (numbers-why before after)))))
      (:out-of-fragment
       (reply "status" "not_checked" "solved" :false
              "message" (refusal-text (or (getf verdict :reason) "")))))))

(defun system-task-p (problem)
  (equal (jget problem "kind") "system"))

(defun point-words (point vars)
  (format nil "~{~a~^, ~}"
          (loop for value in point
                for name across vars
                collect (format nil "~a = ~a" name (rational-text value)))))

(defun system-why (line0 point vars)
  "The witness in words, tested against the first line."
  (cond ((null point) "")
        ((fits-p (combination-rows line0 vars) point)
         (format nil "~a fits the first line, and not this one." (point-words point vars)))
        (t (format nil "~a fits this line, and not the first line." (point-words point vars)))))

(defun system-claim-text (text)
  (if (string= text "no solution")
      "This system does have a solution. Keep going."
      "This system does not have infinitely many solutions. Keep going."))

(defun system-reply (problem request)
  (let* ((start (jget problem "start"))
         (vars (jget problem "vars"))
         (previous (request-text request "previous"))
         (text (request-text request "text"))
         (result (check-system-step start text vars (jget problem "goal")))
         (verdict (getf result :verdict)))
    (ecase (getf result :status)
      (:accepted
       (let ((words (system-words start previous text vars)))
         (reply "status" "accepted" "solved" (solved-flag result)
                "explanations" (if words (vector words) #()))))
      (:rejected
       (if verdict
           (reply "status" "rejected" "solved" :false
                  "message" "This line does not follow from the first line."
                  "why" (system-why start (getf verdict :witness) vars))
           (reply "status" "rejected" "solved" :false "message" (system-claim-text text) "why" "")))
      (:out-of-fragment
       (reply "status" "not_checked" "solved" :false "message" (refusal-text (getf result :reason)))))))

(defun complex-task-p (problem)
  (equal (jget problem "kind") "complex"))

(defun number-task-p (problem)
  (equal (jget problem "form") "number"))

(defun complex-why (start text verdict number-task)
  "The witness in words, tested against the two lines."
  (let ((shown (complex-text (getf verdict :witness))))
    (cond (number-task
           (handler-case
               (with-fuel (format nil "The first line comes to ~a, and this line comes to ~a."
                                  (complex-text (number-of (number-line start))) shown))
             (refused () "")))
          ((eq (getf verdict :verdict) :gains)
           (format nil "x = ~a solves this line, and not the first line." shown))
          (t (format nil "x = ~a solves the first line, and not this one." shown)))))

(defun complex-reply (problem request)
  (let* ((start (jget problem "start"))
         (text (request-text request "text"))
         (number-task (number-task-p problem))
         (result (check-complex-step start text number-task))
         (verdict (getf result :verdict)))
    (ecase (getf result :status)
      (:accepted (reply "status" "accepted" "solved" (solved-flag result) "explanations" #()))
      (:rejected
       (reply "status" "rejected" "solved" :false
              "message" (if number-task
                            "This line is a different number from the first line."
                            "These two lines do not have the same solutions.")
              "why" (complex-why start text verdict number-task)))
      (:out-of-fragment
       (reply "status" "not_checked" "solved" :false "message" (refusal-text (getf verdict :reason)))))))

(defun log-task-p (problem)
  (equal (jget problem "kind") "log"))

(defun value-task-p (problem)
  (equal (jget problem "form") "value"))

(defun log-value-why (start verdict)
  (handler-case
      (with-fuel
        (let ((tree (fold (log-value-line start #\x))))
          (if (or (has-x-p tree) (null (getf verdict :witness)))
              ""
              (format nil "The first line comes to ~a, and this line comes to ~a."
                      (witness-text (lconst tree)) (witness-text (getf verdict :witness))))))
    (refused () "")))

(defun log-value-reply (problem request)
  (let* ((start (jget problem "start"))
         (text (request-text request "text"))
         (result (check-log-value-step start text (coerce (jget problem "finished") 'list)))
         (verdict (getf result :verdict)))
    (ecase (getf result :status)
      (:accepted (reply "status" "accepted" "solved" (solved-flag result) "explanations" #()))
      (:rejected
       (reply "status" "rejected" "solved" :false
              "message" "This line is not the same as the first line."
              "why" (log-value-why start verdict)))
      (:out-of-fragment
       (reply "status" "not_checked" "solved" :false "message" (refusal-text (getf verdict :reason)))))))

(defun log-reply (problem request)
  (let* ((start (jget problem "start"))
         (text (request-text request "text"))
         (result (check-log-step start text))
         (verdict (getf result :verdict)))
    (ecase (getf result :status)
      (:accepted (reply "status" "accepted" "solved" (solved-flag result) "explanations" #()))
      (:caution
       (reply "status" "caution" "solved" :false "explanations" #()
              "message" "That can follow, but it may have added a value that fails the first line. Check it there."))
      (:rejected
       (if (claim-p text)
           (reply "status" "rejected" "solved" :false "message" (claim-text text "x") "why" "")
           (reply "status" "rejected" "solved" :false
                  "message" "These two lines do not have the same solutions."
                  "why" (format nil "x = ~a fits one of these lines and not the other."
                                (witness-text (getf verdict :witness))))))
      (:out-of-fragment
       (reply "status" "not_checked" "solved" :false "message" (refusal-text (getf verdict :reason)))))))

(defun practice-check (problems request)
  (let ((problem (find-practice problems (jget request "problem"))))
    (cond ((expression-task-p problem) (expression-reply problem request))
          ((and (log-task-p problem) (value-task-p problem)) (log-value-reply problem request))
          ((log-task-p problem) (log-reply problem request))
          ((system-task-p problem) (system-reply problem request))
          ((complex-task-p problem) (complex-reply problem request))
          (t (equation-reply problem request)))))

(defun equation-reply (problem request)
  (let* ((start (jget problem "start"))
         (var (line-variable start))
         (previous (request-text request "previous"))
         (text (request-text request "text"))
         (result (check-step start previous text :var var))
         (verdict (getf result :verdict)))
    (ecase (getf result :status)
      (:accepted
       (reply "status" "accepted" "solved" (solved-flag result)
              "explanations" (if (claim-p text) #() (explanations previous text var))))
      (:caution
       (reply "status" "caution" "solved" :false
              "explanations" (explanations previous text var)
              "message" "That can follow, but it may have added a value that fails the first line. Check it there."))
      (:rejected
       (if (claim-p text)
           (reply "status" "rejected" "solved" :false "message" (claim-text text var) "why" "")
           (reply "status" "rejected" "solved" :false
                  "message" "These two lines do not have the same solutions."
                  "why" (why-text previous text verdict var))))
      (:out-of-fragment
       (reply "status" "not_checked" "solved" :false
              "message" (refusal-text (or (getf result :reason) (getf verdict :reason) "")))))))

;;; The whole authored solution, each line with the words for how it follows from the one before.
;;; Rules see lines in sorted order, so a reordered line has no rule to name it.

(defun solution-ending (problem var)
  (let ((answer (jget problem "answer")))
    (cond ((jget problem "ending"))
          ((string= answer "all")
           (format nil "Every allowed value of ~a works, so the answer is all real numbers." var))
          ((string/= answer "none") "")
          ((zerop (length (jget problem "steps")))
           "The number under the root in the quadratic formula is negative, so there is no real solution.")
          (t "This line is never true, so there is no solution."))))

(defun solution-reason (step before after var)
  (or (jget step "why")
      (reason-words before after var)
      (if (equal (flat (read-tree before var)) (flat (read-tree after var)))
          "The same terms, written in a different order."
          "This line does several moves at once.")))

(defun line-task-p (problem)
  "Does this task write expressions rather than equations?"
  (or (expression-task-p problem) (number-task-p problem) (value-task-p problem)))

(defun practice-solution (problems request)
  (let* ((problem (find-practice problems (jget request "problem")))
         (*imaginary* (complex-task-p problem))
         (*logs* (log-task-p problem))
         (*expression-task* (line-task-p problem))
         (var (task-variable problem))
         (previous (jget problem "start")))
    (reply "steps" (map 'vector
                        (lambda (step)
                          (let ((line (jget step "line")))
                            (prog1 (list :obj (cons "line" line)
                                         (cons "why" (solution-reason step previous line var)))
                              (setf previous line))))
                        (jget problem "steps"))
           "ending" (solution-ending problem var))))

;;; A graph is a list of points worked out here. The page only draws them.

(defconstant +graph-bits+ 16)

(defun graph-height (tree x)
  "The height of TREE at X as an exact number, or NIL where it has none. A root is rounded down."
  (handler-case
      (with-fuel
        (if (holds-variable-radical-p tree)
            (and (defined-at-p tree x) (car (bracket tree x +graph-bits+)))
            (let ((y (value tree x)))
              (if (consp y) (car (bounds-of-number y +graph-bits+)) y))))
    (refused () nil)))

(defun practice-graph (problems request)
  (let* ((problem (find-practice problems (jget request "problem")))
         (formula (jget problem "graph")))
    (unless formula (error 'bad-practice))
    (let ((tree (parse-expression-line formula #\x)))
      (reply "points"
             (coerce (loop for step from -20 to 20
                           collect (let* ((x (/ step 2)) (y (graph-height tree x)))
                                     (list :obj (cons "x" (format nil "~a" x))
                                           (cons "y" (if y (format nil "~a" y) "")))))
                     'vector)))))

;;; Hints follow the authored solution. A line off that path gets general wording.

(defun line-key (problem line var)
  "What makes two written lines the same line of this task."
  (cond ((system-task-p problem) (mapcar #'row-of (parse-system line (jget problem "vars"))))
        ((log-task-p problem) (read-tree line var))
        (t (flat (read-tree line var)))))

(defun path-position (problem previous var)
  (handler-case
      (let ((target (line-key problem previous var))
            (lines (cons (jget problem "start")
                         (map 'list (lambda (s) (jget s "line")) (jget problem "steps")))))
        (position target lines :test #'equal :key (lambda (line) (line-key problem line var))))
    (refused () nil)))

(defun reason-words (before after var)
  (let ((words (coerce (explanations before after var) 'list)))
    (when words (format nil "~{~a~^ ~}" words))))

(defun step-hint (before after var)
  (or (reason-words before after var) "Work out the next simpler line."))

(defun practice-hint (problems request)
  (let* ((problem (find-practice problems (jget request "problem")))
         (*imaginary* (complex-task-p problem))
         (*logs* (log-task-p problem))
         (*expression-task* (line-task-p problem))
         (var (task-variable problem))
         (previous (request-text request "previous"))
         (level (jget request "level"))
         (steps (jget problem "steps"))
         (index (path-position problem previous var)))
    (unless (member level '(1 2)) (error 'bad-practice))
    (reply "text"
           (cond ((and (null index) (log-task-p problem))
                  (if (= level 1)
                      "Write both sides as powers of one base, or join the logs into one."
                      "A power and a log undo each other, so use one to free x."))
                 ((and (null index) (complex-task-p problem))
                  (if (= level 1)
                      "Treat i like a letter, then use i^2 = -1."
                      "Bring the line to the form a + bi, or to x = a + bi."))
                 ((and (null index) (system-task-p problem))
                  (if (= level 1)
                      "Pick a letter to remove. Put what it equals into another equation, or add the equations so it cancels."
                      "Every line you write has to follow from the first line."))
                 ((and (null index) *expression-task*)
                  (if (= level 1)
                      "Look for a factor the terms share, or like terms to add."
                      "Change one thing at a time, and keep what the line is worth the same."))
                 ((null index)
                  (if (= level 1)
                      (format nil "Look at what is still on the same side as ~a." var)
                      "Undo one operation at a time, and do it to both sides."))
                 ((= index (length steps))
                  (if (member (jget problem "answer") '("none" "all") :test #'string=)
                      (if (zerop (length steps))
                          (or (jget problem "nudge")
                              "Try the quadratic formula, and look at the number under the root.")
                          (if (system-task-p problem)
                              "Look at this line. What does it say about the system? Use the buttons below."
                              "Is this ever true? Use the buttons below."))
                      "This line already gives the answer."))
                 ((= level 2) (jget (aref steps index) "line"))
                 ((jget (aref steps index) "why"))
                 (t (step-hint previous (jget (aref steps index) "line") var))))))
