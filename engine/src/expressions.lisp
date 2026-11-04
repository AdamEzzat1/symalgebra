;;;; Expression tasks: simplify, expand or factor, where a line has no equals sign. Two expressions are
;;;; compared as functions: do they agree, and where does each have a value? So (x^2 - 1)/(x - 1) to
;;;; x + 1 is the same everywhere but x = 1, where only the second has a value.

(in-package :symalgebra.engine)

(defun expression-parts (tree)
  "TREE as a rational function, and the polynomial whose roots leave its domain."
  (when (chart-line-p tree)
    (refuse "expression_form"))
  (let* ((*zeros* '(1))
         (meaning (meaning-of tree)))
    (when (and (car meaning) (> (degree (car meaning)) +max-degree+))
      (refuse "degree_limit"))
    (values meaning *zeros*)))

(defun first-whole-outside (&rest polynomials)
  "The first whole number from 0 that is a root of none of POLYNOMIALS."
  (loop for candidate from 0
        unless (some (lambda (p) (eql (pvalue p candidate) 0)) polynomials)
          return candidate))

(defun expression-verdict (before after)
  "The verdict on a step between two expression trees: EQUIVALENT, or what separates them."
  (handler-case
      (with-fuel
        (check-radicals before after)
        (multiple-value-bind (a a-zeros) (expression-parts before)
          (multiple-value-bind (b b-zeros) (expression-parts after)
            (let ((top (car (rf- a b))) (common (pgcd a-zeros b-zeros)))
              (if top
                  (list :verdict :unrelated :shape "Differ" :set nil
                        :witness (first-whole-outside top a-zeros b-zeros))
                  (let ((gained (pquo a-zeros common)) (lost (pquo b-zeros common)))
                    (cond ((and (zerop (root-count gained)) (zerop (root-count lost)))
                           (list :verdict :equivalent))
                          ((zerop (root-count lost)) (payload :gains (cons :finite gained)))
                          ((zerop (root-count gained)) (payload :loses (cons :finite lost)))
                          (t (payload :unrelated (cons :finite lost))))))))))
    (refused (r) (list :verdict :out-of-fragment :reason (refused-reason r)))))

(defun check-expressions (before after &key (var #\x))
  (handler-case (expression-verdict (parse-expression-line before var) (parse-expression-line after var))
    (refused (r) (list :verdict :out-of-fragment :reason (refused-reason r)))))

(defun same-as-start-p (verdict)
  "A step may give an expression a value where the first line had none, and nothing else."
  (member (getf verdict :verdict) '(:equivalent :gains)))

(defun finished-p (text finished var)
  "Is TEXT, read up to order, one of the FINISHED forms the problem names?"
  (let ((line (flat (parse-expression-line text var))))
    (some (lambda (form) (equal line (flat (parse-expression-line form var)))) finished)))

(defun check-expression-step (line0 previous text finished &key (var #\x))
  "Judge the expression TEXT after PREVIOUS, in a task that began at LINE0."
  (let* ((from-previous (check-expressions previous text :var var))
         (from-start (check-expressions line0 text :var var)))
    (cond ((eq (getf from-previous :verdict) :out-of-fragment)
           (list :status :out-of-fragment :verdict from-previous :solved nil))
          ((or (same-as-start-p from-previous) (same-as-start-p from-start))
           (list :status :accepted :verdict from-previous
                 :note (and (eq (getf from-start :verdict) :gains) (getf from-start :set))
                 :solved (and (same-as-start-p from-start) (finished-p text finished var))))
          (t (list :status :rejected :verdict from-previous :solved nil)))))
