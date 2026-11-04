;;;; Systems of linear equations in up to three variables. A line is one or more equations, each a row
;;;; (a b c k) meaning ax + by + cz + k = 0, and what a line says is the row space it spans, in reduced
;;;; form. One line follows from another exactly when its rows lie in that space, so any route through
;;;; a system, by substitution or by elimination, is judged the same way.

(in-package :symalgebra.engine)

(defconstant +max-equations+ 4)

(defparameter *system-names* '(:x :y :z))

(defun parse-system (text vars)
  "The equations of TEXT, as (= left right) trees. VARS is a string such as \"xy\"."
  (let* ((*other-variables* (subseq vars 1))
         (*tokens* (tokenize text (char vars 0)))
         (*at* 0)
         (equations '()))
    (loop
      (let ((left (parse-expression 0)))
        (unless (eql (kind) #\=)
          (refuse "unparsed"))
        (take)
        (push (list '= left (parse-expression 0)) equations)
        (cond ((null (kind)) (return))
              ((eql (kind) #\,) (take))
              ((eql (kind) #\=) (refuse "chain"))
              (t (refuse "unparsed")))))
    (when (> (length equations) +max-equations+)
      (refuse "too_many_equations"))
    (nreverse equations)))

(defparameter +no-point+ '(0 0 0 1) "The row 0x + 0y + 0z + 1 = 0, which no point fits.")

(defun contradiction-p (rows)
  (member +no-point+ rows :test #'equal))

(defun form+ (a b) (mapcar #'+ a b))
(defun form-scaled (c a) (mapcar (lambda (q) (* c q)) a))
(defun form-constant (c) (list 0 0 0 c))
(defun form-number (a) (and (every #'zerop (butlast a)) (fourth a)))

(defun form-of (tree)
  "The linear form of TREE, or a refusal if it is not linear."
  (cond ((numberp tree) (form-constant tree))
        ((symbolp tree) (substitute 1 tree (append (mapcar (lambda (n) (if (eq n tree) n 0)) *system-names*) '(0))))
        (t (destructuring-bind (head a &optional b) tree
             (case head
               (+ (form+ (form-of a) (form-of b)))
               (- (form+ (form-of a) (form-scaled -1 (form-of b))))
               (neg (form-scaled -1 (form-of a)))
               (* (let* ((p (form-of a)) (q (form-of b)) (m (form-number p)) (n (form-number q)))
                    (cond (m (form-scaled m q))
                          (n (form-scaled n p))
                          (t (refuse "nonlinear_system")))))
               (/ (let ((n (form-number (form-of b))))
                    (cond ((null n) (refuse "nonlinear_system"))
                          ((zerop n) (refuse "empty_domain"))
                          (t (form-scaled (/ n) (form-of a))))))
               (^ (let ((n (form-number (form-of a))))
                    (cond (n (form-constant (expt n b)))
                          ((= b 1) (form-of a))
                          (t (refuse "nonlinear_system")))))
               (t (refuse "nonlinear_system")))))))

(defun row-of (equation)
  (form+ (form-of (second equation)) (form-scaled -1 (form-of (third equation)))))

(defun rref (rows)
  "The reduced form of ROWS: leading entries 1, alone in their columns, zero rows gone."
  (let ((rows (copy-list rows)) (done '()))
    (dotimes (column 4)
      (let ((pivot (find-if (lambda (row) (/= (nth column row) 0)) rows)))
        (when pivot
          (let ((unit (form-scaled (/ (nth column pivot)) pivot)))
            (flet ((cleared (row) (form+ row (form-scaled (- (nth column row)) unit))))
              (setf rows (mapcar #'cleared (remove pivot rows :count 1))
                    done (append (mapcar #'cleared done) (list unit))))))))
    done))

(defun combination-rows (text vars)
  "The reduced equations of TEXT, keeping which ones were written."
  (rref (mapcar #'row-of (parse-system text vars))))

(defun solution-rows (rows)
  "ROWS as far as their points go: every empty system is the same empty set."
  (if (contradiction-p rows) (list +no-point+) rows))

(defun system-rows (text vars)
  (solution-rows (combination-rows text vars)))


(defun pivot-column (row)
  (position 0 row :test-not #'=))

(defun free-columns (rows count)
  (set-difference (loop for c from 0 below count collect c) (mapcar #'pivot-column rows)))

(defun points-of (rows count)
  "Points fitting ROWS: each free variable 0 or 1, in order, first variable changing slowest."
  (let ((free (sort (copy-list (free-columns rows count)) #'<)))
    (loop for choice from 0 below (ash 1 (length free))
          collect (let ((point (make-list count :initial-element 0)))
                    (loop for column in free
                          for bit downfrom (1- (length free))
                          do (setf (nth column point) (if (logbitp bit choice) 1 0)))
                    (dolist (row rows point)
                      (let ((column (pivot-column row)))
                        (setf (nth column point)
                              (- (+ (fourth row)
                                    (loop for c in free sum (* (nth c row) (nth c point))))))))))))

(defun fits-p (rows point)
  (every (lambda (row)
           (zerop (+ (fourth row) (loop for c from 0 below (length point)
                                        sum (* (nth c row) (nth c point))))))
         rows))

(defun lying-outside (rows other count)
  "The first point of ROWS that does not fit OTHER, or NIL. ROWS is never the contradiction: a
verdict asks for a point only on the side with more of them."
  (find-if-not (lambda (point) (fits-p other point)) (points-of rows count)))

(defun system-verdict (a b count)
  "The verdict on going from rows A to rows B. A witness is a point on one side only."
  (let ((merged (solution-rows (rref (append a b)))))
    (cond ((equal a b) (list :verdict :equivalent))
          ((equal merged a)
           (list :verdict :gains :shape "System" :witness (lying-outside b a count)))
          ((equal merged b)
           (list :verdict :loses :shape "System" :witness (lying-outside a b count)))
          (t (list :verdict :unrelated :shape "System"
                   :witness (or (lying-outside a b count) (lying-outside b a count)))))))

(defun check-systems (before after vars)
  (handler-case (with-fuel (system-verdict (system-rows before vars) (system-rows after vars) (length vars)))
    (refused (r) (list :verdict :out-of-fragment :reason (refused-reason r)))))

(defun point-text (point)
  (format nil "(~{~a~^,~})" (mapcar #'rational-text point)))

(defun system-text (v)
  "The exact text compared byte for byte with the oracle."
  (case (getf v :verdict)
    (:equivalent "EQUIVALENT")
    (:out-of-fragment (format nil "OUT_OF_FRAGMENT ~a" (getf v :reason)))
    (t (format nil "~a System witness=~a" (verdict-name v)
               (let ((w (getf v :witness))) (if w (point-text w) "none"))))))

;;; Using a verdict.

(defun goal-form-p (equations count goal)
  "Is this the line GOAL names? Without one, a task ends on a value for every variable."
  (if goal
      (and (null (rest equations))
           (eq (second (first equations)) (find-goal goal))
           (not (mentions-p (find-goal goal) (third (first equations)))))
      (answer-form-p equations count)))

(defun mentions-p (name tree)
  (if (consp tree)
      (and (not (eq (first tree) :const))
           (some (lambda (part) (mentions-p name part)) (rest tree)))
      (eq tree name)))

(defun find-goal (goal)
  (nth (position (char goal 0) "xyz") *system-names*))

(defun answer-form-p (equations count)
  "One equation for each variable, each that variable against a number."
  (and (= (length equations) count)
       (let ((seen (mapcar (lambda (equation)
                             (destructuring-bind (left right) (rest equation)
                               (cond ((and (symbolp left) (literal-p right)) left)
                                     ((and (symbolp right) (literal-p left)) right))))
                           equations)))
         (and (notany #'null seen)
              (= (length (remove-duplicates seen)) count)))))

(defun system-claim (start text vars)
  (let* ((rows (system-rows start vars))
         (right (if (string= text "no solution")
                    (and (contradiction-p rows) t)
                    (and (not (contradiction-p rows)) (< (length rows) (length vars))))))
    (list :status (if right :accepted :rejected) :solved right)))

(defun check-system-step (line0 text vars &optional goal)
  "Judge TEXT in a task that began at LINE0. A line stands if it follows from LINE0, whatever came between."
  (handler-case
      (with-fuel
        (if (member text '("no solution" "infinitely many") :test #'string=)
            (system-claim line0 text vars)
            (let* ((start (combination-rows line0 vars))
                   (rows (combination-rows text vars))
                   (verdict (system-verdict (solution-rows start) (solution-rows rows) (length vars)))
                   (kind (getf verdict :verdict)))
              ;; Any line follows from a contradiction, so here a line must combine the equations given.
              (cond ((equal (rref (append start rows)) start)
                     (list :status :accepted :verdict verdict
                           :solved (and (eq kind :equivalent)
                                        (goal-form-p (parse-system text vars) (length vars) goal))))
                    (t (list :status :rejected :verdict verdict :solved nil))))))
    (refused (r) (list :status :out-of-fragment :reason (refused-reason r) :solved nil))))

(defun dropped-variable (rows vars)
  "The one variable the rows leave out, when they leave one out and hold another. The contradiction
leaves every variable out, so it never counts."
  (let ((row (first rows)))
    (when (and row (null (rest rows)))
      (let ((zero (loop for c from 0 below (length vars)
                        when (zerop (nth c row)) collect (char vars c))))
        (and (= (length zero) 1) (first zero))))))

(defun system-words (start previous text vars)
  "What a step did, when the rows of TEXT show it. Words only: the verdict has already been given."
  (handler-case
      (let* ((rows (system-rows text vars))
             (before (system-rows previous vars))
             (dropped (dropped-variable rows vars)))
        (cond ((equal rows (system-rows start vars)) nil)
              ((and dropped (/= (length before) 1))
               (format nil "This combines the equations so that ~a drops out." dropped))
              ((and rows (null (rest rows)) (= (count 0 (butlast (first rows)) :test-not #'=) 1))
               (format nil "This gives ~a a value." (char vars (pivot-column (first rows)))))))
    (refused () nil)))
