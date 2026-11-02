;;;; The meaning of a line and the verdict on a step, as defined in docs/SEMANTICS.md.
;;;; Domains come from the typed tree. A solution set is (:finite . p), the real roots of p, or
;;;; (:allexcept . p), every real number but those roots. p is squarefree, so sets compare by gcd.

(in-package :symalgebra.engine)

(defconstant +max-degree+ 8)

(defvar *zeros*)

(defun rf-power (base n)
  (let ((out base))
    (dotimes (i (1- n) out)
      (setf out (rf* out base)))))

(defun meaning-of (tree)
  "TREE as a rational function, recording in *ZEROS* each value its denominators remove."
  (cond ((eq tree :x) (cons '(0 1) '(1)))
        ((numberp tree) (cons (trim (list tree)) '(1)))
        (t (destructuring-bind (head a &optional b) tree
             (ecase head
               (+ (rf+ (meaning-of a) (meaning-of b)))
               (- (rf- (meaning-of a) (meaning-of b)))
               (* (rf* (meaning-of a) (meaning-of b)))
               (neg (rf- (cons nil '(1)) (meaning-of a)))
               (^ (rf-power (meaning-of a) b))
               (/ (let ((top (meaning-of a)) (bottom (meaning-of b)))
                    (when (null (car bottom))
                      (refuse "empty_domain"))
                    (setf *zeros* (plcm *zeros* (psquarefree (car bottom))))
                    (rf/ top bottom))))))))

(defun line-parts (line)
  "The difference of the two sides, and the polynomial whose roots leave the domain."
  (let* ((*zeros* '(1))
         (difference (rf- (meaning-of (second line)) (meaning-of (third line)))))
    (values difference *zeros*)))

(defun equation-set (line)
  (multiple-value-bind (difference zeros) (line-parts line)
    (let ((top (car difference)))
      (cond ((null top) (cons :allexcept zeros))
            ((> (degree top) +max-degree+) (refuse "degree_limit"))
            (t (let ((square-free (psquarefree top)))
                 (cons :finite (pnormal (pquo square-free (pgcd square-free zeros))))))))))

(defun join-sets (a b)
  "A or B, for sets of either shape. An excluded value stays out only if neither set has it."
  (let ((p (cdr a)) (q (cdr b)))
    (cond ((and (eq (car a) :finite) (eq (car b) :finite)) (cons :finite (pnormal (plcm p q))))
          ((eq (car a) :finite) (cons :allexcept (pquo q (pgcd p q))))
          ((eq (car b) :finite) (cons :allexcept (pquo p (pgcd p q))))
          (t (cons :allexcept (pgcd p q))))))

(defun solution-set (line)
  (if (eq (first line) 'or)
      (reduce #'join-sets (mapcar #'equation-set (rest line)))
      (equation-set line)))

(defun canonical-line (line)
  "The canonical form: the line's numerator and the domain's removed-values polynomial."
  (multiple-value-bind (difference zeros) (line-parts line)
    (list :numerator (pnormal (car difference)) :removed zeros)))

(defun subtract (a b)
  "A \\ B, for sets of either shape."
  (let ((p (cdr a)) (q (cdr b)))
    (cond ((and (eq (car a) :finite) (eq (car b) :finite))
           (cons :finite (pquo p (pgcd p q))))
          ((eq (car a) :finite) (cons :finite (pgcd p q)))
          ((eq (car b) :finite) (cons :allexcept (plcm p q)))
          (t (cons :finite (pquo q (pgcd p q)))))))

(defun empty-set-p (s)
  (and (eq (car s) :finite) (zerop (root-count (cdr s)))))

(defun witness-of (kind members)
  (if (eq kind :finite)
      (first members)
      (loop for candidate from 0
            unless (member candidate members) return candidate)))

(defun payload (name difference)
  (let ((members (rational-roots (cdr difference))))
    (list :verdict name
          :shape (if (eq (car difference) :finite) "Finite" "AllExcept")
          :set members
          :witness (witness-of (car difference) members))))

(defun verdict (previous line)
  "The verdict on a step from one line tree to the next, with an exact witness."
  (handler-case
      (with-fuel
        (let* ((before (solution-set previous))
               (after (solution-set line))
               (lost (subtract before after))
               (gained (subtract after before))
               (no-loss (empty-set-p lost))
               (no-gain (empty-set-p gained)))
          ;; An irrational gain must refuse even where the payload would only show the loss.
          (unless no-gain (rational-roots (cdr gained)))
          (cond ((and no-loss no-gain) (list :verdict :equivalent))
                (no-loss (payload :gains gained))
                (no-gain (payload :loses lost))
                (t (payload :unrelated lost)))))
    (refused (r) (list :verdict :out-of-fragment :reason (refused-reason r)))))

(defun check-lines (previous line &key (var #\x))
  (handler-case (verdict (parse-line previous var) (parse-line line var))
    (refused (r) (list :verdict :out-of-fragment :reason (refused-reason r)))))

(defun verdict-name (v)
  (ecase (getf v :verdict)
    (:equivalent "EQUIVALENT")
    (:gains "GAINS")
    (:loses "LOSES")
    (:unrelated "UNRELATED")
    (:out-of-fragment "OUT_OF_FRAGMENT")))

(defun rational-text (q)
  (format nil "~a" q))

(defun verdict-text (v)
  "The exact text compared byte for byte with the oracle."
  (case (getf v :verdict)
    (:equivalent "EQUIVALENT")
    (:out-of-fragment (format nil "OUT_OF_FRAGMENT ~a" (getf v :reason)))
    (t (format nil "~a ~a{~{~a~^,~}} witness=~a" (verdict-name v) (getf v :shape)
               (mapcar #'rational-text (getf v :set)) (rational-text (getf v :witness))))))

;;; Strict evaluation: a zero divisor has no value, and NIL spreads upward.

(defun combine (head values)
  (ecase head
    (+ (reduce #'+ values))
    (- (reduce #'- values))
    (* (reduce #'* values))
    (/ (unless (zerop (second values))
         (/ (first values) (second values))))))

(defun value (tree x)
  (cond ((eq tree :x) x)
        ((numberp tree) tree)
        ((eq (first tree) '^)
         (let ((base (value (second tree) x)))
           (and base (expt base (third tree)))))
        ((eq (first tree) 'neg)
         (let ((inner (value (second tree) x)))
           (and inner (- inner))))
        (t (let ((values (mapcar (lambda (arg) (value arg x)) (rest tree))))
             (and (notany #'null values)
                  (combine (first tree) values))))))

(defun holds (line x)
  (if (eq (first line) 'or)
      (some (lambda (equation) (holds equation x)) (rest line))
      (let ((left (value (second line) x)) (right (value (third line) x)))
        (and left right (= left right)))))

(defun solution-members (line)
  (solution-set line))

(defun solution-member-p (set x)
  (let ((root (zerop (pvalue (cdr set) x))))
    (if (eq (car set) :finite) root (not root))))
