;;;; Engine tests: sbcl --script engine/tests/run.lisp, from the repository root.
;;;; ENGINE_SRC points at another copy of the source, which is how mutation testing runs these.

(defvar *source* (or (sb-ext:posix-getenv "ENGINE_SRC") "engine/src/"))

(handler-bind ((warning #'muffle-warning))
  (load (concatenate 'string *source* "load.lisp")))

(in-package :symalgebra.engine)

(defvar *ran* 0)
(defvar *passed* 0)
(defvar *quiet* (sb-ext:posix-getenv "ENGINE_QUIET"))
;; Mutation testing needs only to know that some check fails, so it stops at the first.
(defvar *stop* (sb-ext:posix-getenv "ENGINE_STOP"))

(defun check (name ok &optional detail)
  (incf *ran*)
  (cond (ok (incf *passed*))
        (*stop* (sb-ext:exit :code 1 :abort t))
        ((not *quiet*) (format t "FAIL ~a~@[ ~a~]~%" name detail))))

(defmacro tier (name &body body)
  `(let ((*ran* 0) (*passed* 0))
     (handler-case (progn ,@body)
       (error (e)
         (when *stop* (sb-ext:exit :code 1 :abort t))
         (incf *ran*)
         (unless *quiet* (format t "ERROR in ~a: ~a~%" ,name e))))
     (format t "COUNT ~a ran=~d passed=~d~%" ,name *ran* *passed*)
     (unless (= *ran* *passed*) (setf *failed* t))))

(defvar *failed* nil)

(defun read-json (path)
  (with-open-file (in path :external-format :utf-8)
    (let ((text (make-string (file-length in))))
      (parse-json (subseq text 0 (read-sequence text in))))))

(defvar *solutions* (read-json "corpus/solutions.json"))
(defvar *verdicts* (read-json "corpus/verdicts.json"))
(defvar *differential* (read-json "corpus/differential.json"))

(defun as-list (vector) (coerce vector 'list))

(defun solution-lines (solution)
  (cons (jget solution "start")
        (map 'list (lambda (step) (jget step "line")) (jget solution "steps"))))

;;; Tier A: the decision procedure on the corpus.

(defun check-verdict-case (case)
  (let* ((name (jget case "name"))
         (got (check-lines (jget case "previous") (jget case "line")))
         (wanted (jget case "verdict")))
    (check name (string= (verdict-name got) wanted) (verdict-text got))
    (when (jget case "reason")
      (check (format nil "~a: reason" name) (equal (getf got :reason) (jget case "reason"))
             (getf got :reason)))
    (when (jget case "shape")
      (check (format nil "~a: shape" name) (equal (getf got :shape) (jget case "shape"))))
    (when (jget case "set")
      (check (format nil "~a: set" name)
             (equal (sort (if (getf got :set)
                              (mapcar #'rational-text (getf got :set))
                              (mapcar #'piece-text (getf got :pieces)))
                          #'string<)
                    (sort (as-list (jget case "set")) #'string<))
             (verdict-text got)))
    (when (getf got :witness)
      (let ((before (parse-line (jget case "previous")))
            (after (parse-line (jget case "line")))
            (w (getf got :witness)))
        (check (format nil "~a: witness" name) (not (eq (holds before w) (holds after w))))))))

(defun check-expression-solution (solution)
  (let* ((name (jget solution "id"))
         (lines (solution-lines solution))
         (line0 (first lines))
         (finished (as-list (jget solution "finished")))
         (previous line0)
         (last-result nil))
    (dolist (line (rest lines))
      (setf last-result (check-expression-step line0 previous line finished))
      (check (format nil "~a: ~a" name line) (eq (getf last-result :status) :accepted)
             (getf last-result :status))
      (setf previous line))
    (check (format nil "~a: solved" name) (getf last-result :solved) last-result)))

(defun check-system-solution (solution)
  (let* ((name (jget solution "id"))
         (lines (solution-lines solution))
         (line0 (first lines))
         (vars (jget solution "vars"))
         (goal (jget solution "goal"))
         (last-result nil))
    (dolist (line (rest lines))
      (setf last-result (check-system-step line0 line vars goal))
      (check (format nil "~a: ~a" name line) (eq (getf last-result :status) :accepted)
             (getf last-result :status)))
    (let ((answer (jget solution "answer")))
      (check (format nil "~a: solved" name)
             (cond ((string= answer "none") (getf (check-system-step line0 "no solution" vars) :solved))
                   ((string= answer "all") (getf (check-system-step line0 "infinitely many" vars) :solved))
                   (t (getf last-result :solved)))
             last-result))))

(defun check-complex-solution (solution)
  (let* ((name (jget solution "id"))
         (lines (solution-lines solution))
         (number-task (equal (jget solution "form") "number"))
         (last-result nil))
    (dolist (line (rest lines))
      (setf last-result (check-complex-step (first lines) line number-task))
      (check (format nil "~a: ~a" name line) (eq (getf last-result :status) :accepted)
             (getf last-result :status)))
    (check (format nil "~a: solved" name) (getf last-result :solved) last-result)))

(defun check-log-solution (solution)
  (let* ((name (jget solution "id"))
         (lines (solution-lines solution))
         (value-task (equal (jget solution "form") "value"))
         (finished (as-list (jget solution "finished")))
         (answer (jget solution "answer"))
         (last-result nil))
    (dolist (line (rest lines))
      (setf last-result (if value-task
                            (check-log-value-step (first lines) line finished)
                            (check-log-step (first lines) line)))
      (check (format nil "~a: ~a" name line) (member (getf last-result :status) '(:accepted :caution))
             (getf last-result :status)))
    (check (format nil "~a: solved" name)
           (if (string= answer "none")
               (getf (check-log-step (first lines) "no solution") :solved)
               (getf last-result :solved))
           last-result)))

(defun check-solution (solution)
  (cond ((equal (jget solution "kind") "complex") (check-complex-solution solution))
        ((equal (jget solution "kind") "log") (check-log-solution solution))
        ((jget solution "finished") (check-expression-solution solution))
        ((jget solution "vars") (check-system-solution solution))
        (t (check-equation-solution solution))))

(defun check-equation-solution (solution)
  (let* ((name (jget solution "id"))
         (lines (solution-lines solution))
         (line0 (first lines))
         (var (line-variable line0))
         (previous line0)
         (last-result nil))
    (dolist (line (rest lines))
      (let ((result (check-step line0 previous line :var var)))
        (check (format nil "~a: ~a" name line)
               (member (getf result :status) '(:accepted :caution))
               (getf result :status))
        (setf previous line last-result result)))
    (let ((answer (jget solution "answer")))
      (cond ((string= answer "none")
             (check (format nil "~a: none" name) (getf (check-step line0 previous "no solution" :var var) :solved)))
            ((string= answer "all")
             (check (format nil "~a: all" name)
                    (getf (check-step line0 previous "all real numbers" :var var) :solved)))
            (t (check (format nil "~a: solved" name) (getf last-result :solved) last-result))))))

(tier "tier-a"
  (map nil #'check-verdict-case *verdicts*)
  (map nil #'check-solution *solutions*)
  ;; The caution path stays open, and a gained root never counts as solved.
  (let ((line0 "x/(x - 1) = 1/(x - 1)"))
    (let ((step (check-step line0 line0 "x = 1")))
      (check "gained root cautions" (eq (getf step :status) :caution))
      (check "gained root is unsolved" (not (getf step :solved))))
    (check "no solution stays reachable" (getf (check-step line0 "x = 1" "no solution") :solved)))
  (let ((line0 "x/(x - 1) = 1/(x - 1)"))
    (check "a line matching only the caution line is not solved"
           (not (getf (check-step line0 "x = 1" "1 = x") :solved))))
  (check "an answer may be written on the right or the left" (getf (check-step "2x = 6" "2x = 6" "3 = x") :solved))
  (check "every value gained is rejected even with variable denominators"
         (eq (getf (check-step "1/x = 2" "1/x = 2" "0 = 0") :status) :rejected))
  (check "a finite gain without variable denominators is rejected"
         (eq (getf (check-step "x = 1" "x = 1" "x^2 = 1") :status) :rejected))
  (check "alternatives are solved only when each one is an answer"
         (not (getf (check-step "(x - 1)(x - 2) = 0" "x - 1 = 0 or x - 2 = 0" "x = 1 or x + 1 = 3") :solved)))
  (check "a lost alternative is rejected"
         (eq (getf (check-step "x^2 = 9" "x^2 = 9" "x = 3") :status) :rejected))
  (check "decimals are exact" (string= (verdict-text (check-lines "0.25x = 1" "x = 4")) "EQUIVALENT"))
  (check "decimals and fractions agree" (string= (verdict-text (check-lines "x = 1.5" "x = 3/2")) "EQUIVALENT"))
  (check "x/x keeps its hole"
         (string= (verdict-text (check-lines "x/x = 1" "1 = 1")) "GAINS Finite{0} witness=0"))
  (check "shared irrational roots" (string= (verdict-text (check-lines "x^2 = 2" "x^4 = 4")) "EQUIVALENT"))
  (check "irrational difference" (string= (verdict-text (check-lines "x^2 = 2" "x = 1"))
                                          "UNRELATED Finite{-sqrt(2),sqrt(2)} witness=-sqrt(2)"))
  (check "a huge power stops at a limit"
         (string= (verdict-text (check-lines "(((9^6)^6)^6)^6 = x" "x = 1"))
                  "OUT_OF_FRAGMENT limit")))

;;; Tier D: byte-for-byte agreement with the independent oracle.

(defun differential-text (case)
  (let ((previous (jget case "previous")) (line (jget case "line")) (vars (jget case "system")))
    (cond (vars (system-text (check-systems previous line vars)))
          ((equal (jget case "log") "value") (log-verdict-text (check-log-values previous line)))
          ((jget case "log") (log-verdict-text (check-log-lines previous line)))
          ((equal (jget case "complex") "number")
           (complex-verdict-text (check-complex-numbers previous line)))
          ((jget case "complex") (complex-verdict-text (check-complex-lines previous line)))
          ((jget case "expression") (verdict-text (check-expressions previous line)))
          (t (verdict-text (check-lines previous line))))))

(tier "tier-d"
  (map nil (lambda (case)
             (let ((got (differential-text case)))
               (check (format nil "~a -> ~a" (jget case "previous") (jget case "line"))
                      (string= got (jget case "expected"))
                      (format nil "got ~a, oracle ~a" got (jget case "expected")))))
       *differential*))

;;; Tier F: properties and metamorphic relations, on a fixed random stream.

(defvar *random* (sb-ext:seed-random-state 20261101))

(defun pick (&rest items) (nth (random (length items) *random*) items))

(defun random-side (depth)
  (if (or (zerop depth) (zerop (random 3 *random*)))
      (pick "x" "1" "2" "3" "5" "-2")
      (let ((a (random-side (1- depth))) (b (random-side (1- depth))))
        (format nil "(~a ~a ~a)" a (pick "+" "-" "*" "/") b))))

(defun random-line ()
  (format nil "~a = ~a" (random-side 3) (random-side 2)))

(defun mirrored (name)
  (cond ((string= name "GAINS") "LOSES")
        ((string= name "LOSES") "GAINS")
        (t name)))

(defun check-properties (a b)
  (let ((fwd (check-lines a b)) (back (check-lines b a)))
    (check (format nil "swap of ~a | ~a" a b)
           (string= (mirrored (verdict-name fwd)) (verdict-name back))
           (format nil "~a / ~a" (verdict-text fwd) (verdict-text back)))
    (when (getf fwd :witness)
      (check (format nil "witness of ~a | ~a" a b)
             (not (eq (holds (parse-line a) (getf fwd :witness))
                      (holds (parse-line b) (getf fwd :witness))))))))

(defun split-equation (line)
  (let ((at (position #\= line)))
    (values (string-trim " " (subseq line 0 at)) (string-trim " " (subseq line (1+ at))))))

(defun in-fragment-p (line)
  (not (string= (verdict-name (check-lines line line)) "OUT_OF_FRAGMENT")))

(defun check-metamorphic (line)
  (multiple-value-bind (l r) (split-equation line)
    (check (format nil "reflexive ~a" line)
           (or (not (in-fragment-p line))
               (string= (verdict-name (check-lines line line)) "EQUIVALENT")))
    (let ((pairs (list (format nil "~a = ~a" r l)
                       (format nil "(~a) + 7 = (~a) + 7" l r)
                       (format nil "(~a) * 3 = (~a) * 3" l r)
                       (format nil "(~a) / 4 = (~a) / 4" l r)
                       (format nil "(~a) - (~a) = (~a) - (~a)" l "2" r "2"))))
      (dolist (other pairs)
        (when (in-fragment-p other)
          (check (format nil "same meaning ~a | ~a" line other)
                 (string= (verdict-name (check-lines line other)) "EQUIVALENT")
                 (verdict-text (check-lines line other))))))))

(defun commuted (tree)
  (cond ((atom tree) tree)
        ((member (first tree) '(+ *))
         (list (first tree) (commuted (third tree)) (commuted (second tree))))
        (t (cons (first tree) (mapcar #'commuted (rest tree))))))

(defun finite-meaning (line)
  (handler-case (with-fuel (canonical-line (parse-line line)))
    (refused () nil)))

(tier "tier-f"
  (dotimes (i 300)
    (let ((a (random-line)) (b (random-line)))
      (check-properties a b)
      (check-metamorphic a)
      (let ((meaning (finite-meaning a)))
        (when meaning
          (let ((tree (parse-line a)))
            (check (format nil "printed line reparses ~a" a)
                   (handler-case (equal (parse-line (tree-text tree)) tree)
                     ;; Full bracketing can pass the token limit. That is a refusal, not a mismatch.
                     (refused (r) (string= (refused-reason r) "too_many_tokens"))))
            (check (format nil "tree stays as typed ~a" a)
                   (equal (parse-line a) tree))
            (check (format nil "order does not change meaning ~a" a)
                   (equal meaning (with-fuel (canonical-line (commuted tree))))))))))
  ;; Evaluation must agree with the solution set at every small point.
  (dotimes (i 120)
    (let ((line (random-line)))
      (when (in-fragment-p line)
        (let ((zeros (handler-case (with-fuel (solution-members (parse-line line))) (refused () :skip))))
          (unless (eq zeros :skip)
            (dolist (point '(-3 -2 -1 -1/2 0 1/2 1 2 3 5))
              (check (format nil "membership of ~a in ~a" point line)
                     (eq (holds (parse-line line) point)
                         (with-fuel (solution-member-p zeros point)))))))))))

;;; Every rule's own examples, through the real matcher.

(defun check-rule-examples (rule)
  (dolist (example (rule-field rule :positive))
    (check (format nil "~a does ~a -> ~a" (rule-id rule) (first example) (second example))
           (rule-reaches-p rule (first example) (second example))))
  (dolist (example (rule-field rule :negative))
    (destructuring-bind (before after &optional guard) example
      (check (format nil "~a refuses ~a -> ~a" (rule-id rule) before after)
             (not (rule-reaches-p rule before after)))
      (when guard
        (check (format nil "~a is stopped only by its guard: ~a" (rule-id rule) after)
               (rule-reaches-p rule before after :failed-guards t))))))

(tier "rule-examples"
  (mapc #'check-rule-examples *rules*)
  (check "the rule count" (= (length *rules*) 88))
  (check "no mal-rules yet" (notany (lambda (r) (rule-field r :mal)) *rules*)))

;;; M2 left this open: does each corpus label really describe its step?

(defun check-labels (solution)
  (let* ((*expression-task* (and (jget solution "finished") t))
         (lines (solution-lines solution))
         (var (line-variable (first lines)))
         (steps (as-list (jget solution "steps"))))
    (loop for before in lines
          for after in (rest lines)
          for step in steps
          do (let ((names (as-list (jget step "rules"))))
               ;; A step with no rule says in words why it is right, and meaning decides it.
               (check (format nil "~a: ~a by ~{~a~^ ~}" (jget solution "id") after names)
                      (or (and (null names) (jget step "why"))
                          (labels-describe-p before after names var)))))))

(tier "corpus-labels"
  (map nil #'check-labels *solutions*))

(load "engine/tests/tutor.lisp")
(load "engine/tests/radicals.lisp")
(load "engine/tests/ranges.lisp")
(load "engine/tests/roots.lisp")
(load "engine/tests/expressions.lisp")
(load "engine/tests/systems.lisp")
(load "engine/tests/complex.lisp")
(load "engine/tests/logs.lisp")

(unless (sb-ext:posix-getenv "ENGINE_FAST")
  (load "engine/tests/graph.lisp"))

(sb-ext:exit :code (if *failed* 1 0))
