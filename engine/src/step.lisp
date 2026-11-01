;;;; What the tutor does with a verdict: the "Using a verdict" section of docs/SEMANTICS.md.

(in-package :symalgebra.engine)

(defun literal-p (tree)
  (or (numberp tree)
      (and (consp tree) (eq (first tree) '/) (numberp (second tree)) (numberp (third tree)))))

(defun solved-form-p (line)
  (destructuring-bind (left right) (rest line)
    (or (and (eq left :x) (literal-p right))
        (and (literal-p left) (eq right :x)))))

(defun variable-denominator-p (tree)
  (and (consp tree)
       (or (and (eq (first tree) '/) (has-variable-p (third tree)))
           (some #'variable-denominator-p (rest tree)))))

(defun claim-result (line0 text var)
  (let* ((set (with-fuel (solution-set (parse-line line0 var))))
         (right (if (string= text "no solution")
                    (and (eq (car set) :finite) (empty-set-p set))
                    (eq (car set) :allexcept))))
    (list :status (if right :accepted :rejected) :solved right)))

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
                        (variable-denominator-p (parse-line previous var)))
                   (list :status :caution :verdict from-previous :solved nil))
                  (t (list :status :rejected :verdict from-previous :solved nil)))))
    (refused (r) (list :status :out-of-fragment :solved nil :reason (refused-reason r)))))
