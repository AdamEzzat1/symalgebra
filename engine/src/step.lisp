;;;; What the tutor does with a verdict: the "Using a verdict" section of docs/SEMANTICS.md.

(in-package :symalgebra.engine)

(defun literal-p (tree)
  (or (numberp tree)
      (and (consp tree) (eq (first tree) '/) (numberp (second tree)) (numberp (third tree)))))

(defun simple-radical-p (tree)
  "sqrt of a whole number with nothing square left in it."
  (and (consp tree) (eq (first tree) 'sqrt) (integerp (second tree)) (> (second tree) 1)
       (= (with-fuel (nth-value 1 (split-square (second tree)))) (second tree))))

(defun radical-term-p (tree)
  (or (simple-radical-p tree)
      (and (consp tree)
           (or (and (eq (first tree) 'neg) (radical-term-p (second tree)))
               (and (eq (first tree) '*) (numberp (second tree)) (radical-term-p (third tree)))
               (and (eq (first tree) '/) (radical-term-p (second tree)) (numberp (third tree)))))))

(defun surd-literal-p (tree)
  "A finished answer with a root in it: a term, a number and a term, or those over a number."
  (or (radical-term-p tree)
      (and (consp tree)
           (or (and (member (first tree) '(+ -)) (literal-p (second tree)) (radical-term-p (third tree)))
               (and (eq (first tree) '+) (radical-term-p (second tree)) (literal-p (third tree)))
               (and (eq (first tree) '/) (surd-literal-p (second tree)) (numberp (third tree)))))))

(defun answer-p (tree)
  (or (literal-p tree) (surd-literal-p tree)))

(defun solved-form-p (line)
  (if (member (first line) '(or and))
      (every #'solved-form-p (rest line))
      (destructuring-bind (left right) (rest line)
        (or (and (eq left :x) (answer-p right))
            (and (answer-p left) (eq right :x))))))

(defun variable-denominator-p (tree)
  (and (consp tree)
       (or (and (eq (first tree) '/) (has-variable-p (third tree)))
           (some #'variable-denominator-p (rest tree)))))

(defun may-add-values-p (line)
  "Could a correct step from LINE add a value? Clearing a denominator or squaring a root can."
  (or (variable-denominator-p line) (holds-variable-radical-p line)))

(defun claim-result (line0 text var)
  (with-fuel
    (let* ((line (parse-line line0 var))
           (none (string= text "no solution"))
           (right (if (chart-line-p line)
                      (if none (chart-empty-p line) (chart-cofinite-p line))
                      (let ((set (solution-set line)))
                        (if none
                            (and (eq (car set) :finite) (empty-set-p set))
                            (eq (car set) :allexcept))))))
      (list :status (if right :accepted :rejected) :solved right))))

(defun check-step (line0 previous text &key (var #\x))
  "Judge TEXT after PREVIOUS in a task that began at LINE0, as a plist with :status and :solved."
  (handler-case
      (if (member text '("no solution" "all real numbers") :test #'string=)
          (claim-result line0 text var)
          (let* ((from-previous (check-lines previous text :var var))
                 (from-start (check-lines line0 text :var var))
                 (kind (getf from-previous :verdict)))
            (cond ((or (eq kind :equivalent) (eq (getf from-start :verdict) :equivalent))
                   (list :status :accepted :verdict from-previous
                         :solved (and (eq (getf from-start :verdict) :equivalent)
                                      (solved-form-p (parse-line text var)))))
                  ((eq kind :out-of-fragment)
                   (list :status :out-of-fragment :verdict from-previous :solved nil))
                  ((and (eq kind :gains)
                        (string= (getf from-previous :shape) "Finite")
                        (may-add-values-p (parse-line previous var)))
                   (list :status :caution :verdict from-previous :solved nil))
                  (t (list :status :rejected :verdict from-previous :solved nil)))))
    (refused (r) (list :status :out-of-fragment :solved nil :reason (refused-reason r)))))
