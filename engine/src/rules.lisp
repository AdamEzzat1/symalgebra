;;;; The rule table, read unchanged from rules/rules.sexp, and the `flat` view rules match against.
;;;; Flat is derived, AC-sorted and unevaluated: sums and products are n-ary and sorted, a difference
;;;; is a sum with a negated term, and division stays, so no denominator disappears.

(in-package :symalgebra.engine)

(defun term-key (term)
  (let ((*print-pretty* nil))
    (prin1-to-string term)))

(defun sorted-terms (terms)
  (mapcar #'cdr (sort (mapcar (lambda (term) (cons (term-key term) term)) terms)
                      #'string< :key #'car)))

(defun negated (flat-term)
  (cond ((numberp flat-term) (- flat-term))
        ((and (consp flat-term) (eq (first flat-term) 'neg)) (second flat-term))
        ;; -(3x) and -3x are one term, written two ways.
        ((and (consp flat-term) (eq (first flat-term) '*) (find-if #'numberp (rest flat-term)))
         (let ((factor (find-if #'numberp (rest flat-term))))
           (node '* (cons (- factor) (remove factor (rest flat-term) :count 1)))))
        (t (list 'neg flat-term))))

(defun node (head items)
  (cond ((null (rest items)) (first items))
        ;; So is -1x and -x.
        ((and (eq head '*) (null (cddr items)) (member -1 items)
              (notany (lambda (item) (or (numberp item) (and (consp item) (eq (first item) 'neg))))
                      (remove -1 items :count 1)))
         (negated (first (remove -1 items :count 1))))
        (t (cons head (sorted-terms items)))))

(defun items-of (head tree)
  (let ((flat-tree (flat tree)))
    (if (and (consp flat-tree) (eq (first flat-tree) head))
        (copy-list (rest flat-tree))
        (list flat-tree))))

(defun flat (tree)
  (if (atom tree)
      tree
      (case (first tree)
        (+ (node '+ (mapcan (lambda (arg) (items-of '+ arg)) (rest tree))))
        (- (node '+ (append (items-of '+ (second tree)) (list (negated (flat (third tree)))))))
        (* (node '* (mapcan (lambda (arg) (items-of '* arg)) (rest tree))))
        (neg (negated (flat (second tree))))
        (/ (list '/ (flat (second tree)) (flat (third tree))))
        (^ (list '^ (flat (second tree)) (third tree)))
        (= (list '= (flat (second tree)) (flat (third tree))))
        (eval tree)
        (t (error "unknown head ~a" (first tree))))))

(defun read-rule-forms (path)
  (with-open-file (in path :external-format :utf-8)
    (let ((*package* (find-package :symalgebra.engine))
          (*read-eval* nil))
      (loop for form = (read in nil :end)
            until (eq form :end)
            collect form))))

(defun rule-field (rule key) (getf (getf rule :fields) key))
(defun rule-id (rule) (getf rule :id))
(defun rule-pattern (rule) (getf rule :pattern))
(defun rule-replacement (rule) (getf rule :replacement))

(defun compile-rule (form)
  (destructuring-bind (tag id &rest fields) form
    (assert (eq tag 'rule))
    (let ((pattern (flat (getf fields :pattern)))
          (replacement (flat (getf fields :replacement))))
      (list :id (string-downcase (symbol-name id))
            :fields fields
            :pattern pattern
            :replacement replacement
            ;; Order rules leave the flat view unchanged, so they name a step without moving it.
            :order (equal pattern replacement)))))

(defun load-rules (&optional (path "rules/rules.sexp"))
  (mapcar #'compile-rule (read-rule-forms path)))

(defvar *rules* (load-rules))

(defun find-rule (name &optional (rules *rules*))
  (find name rules :key #'rule-id :test #'string=))
