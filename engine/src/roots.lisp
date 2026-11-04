;;;; Roots over the variable. Each root is a new unknown whose square is known, so the difference of two
;;;; sides is a set of terms, each a rational function times some of the roots. Multiplying it by itself
;;;; with every choice of signs squares every root away, and leaves a polynomial whose roots hold every
;;;; place the sides could meet. Whether a line holds at a point is then decided at that point, so the
;;;; false answers squaring brings in do no harm. A sign comes from rational bounds, or failing that
;;;; from an exact value, so no float enters.

(in-package :symalgebra.engine)

(defconstant +max-radicals+ 3)
(defconstant +bracket-start+ 64)
(defconstant +bracket-limit+ 1024)

(defvar *radicals* nil "The trees under the roots of a difference, in the order they were met.")

(defun radical-bit (inner)
  (or (position inner *radicals* :test #'equal)
      (progn
        (when (= (length *radicals*) +max-radicals+)
          (refuse "radical_limit"))
        (setf *radicals* (append *radicals* (list inner)))
        (1- (length *radicals*)))))

(defun rf-one ()
  (cons (list 1) (list 1)))

(defun rf-negated (value)
  (rf- (cons nil (list 1)) value))

(defun term+ (terms mask value)
  "TERMS, an alist from sets of roots to rational functions, with VALUE added at MASK."
  (let* ((found (assoc mask terms))
         (total (if found (rf+ (cdr found) value) value))
         (others (remove found terms)))
    (if (car total) (acons mask total others) others)))

(defun terms+ (a b)
  (let ((out a))
    (loop for (mask . value) in b
          do (setf out (term+ out mask value)))
    out))

(defun terms-negated (terms)
  (loop for (mask . value) in terms
        collect (cons mask (rf-negated value))))

(defun squared-roots (shared)
  "The radicands of the roots in the mask SHARED, each met twice in a product."
  (loop for bit from 0 below (length *radicals*)
        when (logbitp bit shared)
          collect (meaning-of (nth bit *radicals*))))

(defun terms* (a b)
  (let ((out '()))
    (loop for (mask . value) in a
          do (loop for (other . other-value) in b
                   do (setf out (term+ out (logxor mask other)
                                       (reduce #'rf* (squared-roots (logand mask other))
                                               :initial-value (rf* value other-value))))))
    out))

(defun terms-of (tree)
  (if (not (holds-variable-radical-p tree))
      (let ((value (meaning-of tree)))
        (and (car value) (list (cons 0 value))))
      (destructuring-bind (head a &optional b) tree
        (ecase head
          (sqrt (when (holds-variable-radical-p a)
                  (refuse "nested_radical"))
           (list (cons (ash 1 (radical-bit a)) (rf-one))))
          (+ (terms+ (terms-of a) (terms-of b)))
          (- (terms+ (terms-of a) (terms-negated (terms-of b))))
          (neg (terms-negated (terms-of a)))
          (* (terms* (terms-of a) (terms-of b)))
          (^ (let ((base (terms-of a)))
               (reduce #'terms* (make-list (1- b) :initial-element base) :initial-value base)))
          (/ (when (holds-variable-radical-p b)
               (refuse "radical_denominator"))
           (terms* (terms-of a) (terms-of (list '/ 1 b))))))))

(defun with-signs (terms signs)
  "TERMS with the roots in the mask SIGNS read as negative."
  (loop for (mask . value) in terms
        collect (cons mask (if (oddp (logcount (logand mask signs))) (rf-negated value) value))))

(defun radical-norm (terms)
  "The product of TERMS over every choice of signs, as a rational function with no root left."
  (let ((out (list (cons 0 (rf-one)))))
    (dotimes (signs (ash 1 (length *radicals*)))
      (setf out (terms* out (with-signs terms signs))))
    (or (cdr (assoc 0 out)) (cons nil (list 1)))))

(defun radical-bounds (left right)
  "Everywhere the two sides might meet, and everywhere a root or a denominator starts or stops."
  (let* ((*radicals* nil)
         (*zeros* '(1))
         (terms (terms+ (terms-of left) (terms-negated (terms-of right))))
         (top (and terms (car (radical-norm terms))))
         (edges (loop for inner in *radicals*
                      append (exact-roots (psquarefree (car (meaning-of inner)))))))
    (append edges (polynomial-bounds top *zeros*))))

;;; Holding at a point.

(defun defined-at-p (tree x)
  "Does TREE have a value at X? A denominator here holds no root, so each test is exact."
  (or (atom tree)
      (and (every (lambda (arg) (defined-at-p arg x)) (rest tree))
           (case (first tree)
             (sqrt (not (minusp (ksign (value (second tree) x)))))
             (/ (not (eql (value (third tree) x) 0)))
             (t t)))))

(defun low-root (q precision)
  (/ (isqrt (floor (* q (ash 1 (* 2 precision))))) (ash 1 precision)))

(defun high-root (q precision)
  (/ (1+ (isqrt (floor (* q (ash 1 (* 2 precision)))))) (ash 1 precision)))

(defun bounds-of-number (x precision)
  "Rational bounds (low . high) on the exact number X."
  (if (rationalp x)
      (cons x x)
      (let* ((d (part-d x)) (b (part-b x))
             (near (* b (low-root d precision))) (far (* b (high-root d precision))))
        (cons (+ (part-a x) (min near far)) (+ (part-a x) (max near far))))))

(defun bounds* (a b)
  (let ((corners (list (* (car a) (car b)) (* (car a) (cdr b)) (* (cdr a) (car b)) (* (cdr a) (cdr b)))))
    (cons (reduce #'min corners) (reduce #'max corners))))

(defun bracket (tree x precision)
  "Rational bounds on the value of TREE at X, where it has one, to about PRECISION bits."
  (if (not (holds-variable-radical-p tree))
      (bounds-of-number (evaluate tree x) precision)
      (destructuring-bind (head a &optional b) tree
        (flet ((inside (part) (bracket part x precision)))
          (ecase head
            (sqrt (let ((inner (inside a)))
                    (cons (low-root (max (car inner) 0) precision)
                          (high-root (max (cdr inner) 0) precision))))
            (+ (let ((p (inside a)) (q (inside b)))
                 (cons (+ (car p) (car q)) (+ (cdr p) (cdr q)))))
            (- (let ((p (inside a)) (q (inside b)))
                 (cons (- (car p) (cdr q)) (- (cdr p) (car q)))))
            (neg (let ((p (inside a))) (cons (- (cdr p)) (- (car p)))))
            (abs (let ((p (inside a)))
                   (cons (max 0 (car p) (- (cdr p))) (max (cdr p) (- (car p))))))
            (* (bounds* (inside a) (inside b)))
            (^ (let ((base (inside a)))
                 (reduce #'bounds* (make-list (1- b) :initial-element base) :initial-value base)))
            (/ (bounds* (inside a) (bounds-of-number (k/ 1 (evaluate b x)) precision))))))))

(defun difference-sign (left right x)
  "The sign of LEFT - RIGHT at X. Two equal sides never come apart in bounds, so they get an exact value."
  (let ((difference (list '- left right)))
    (loop for precision = +bracket-start+ then (* 2 precision)
          while (<= precision +bracket-limit+)
          do (destructuring-bind (low . high) (bracket difference x precision)
               (cond ((plusp low) (return-from difference-sign 1))
                     ((minusp high) (return-from difference-sign -1)))))
    (ksign (k+ (value left x) (kneg (value right x))))))

(defun radical-holds (relation x)
  (destructuring-bind (head left right) relation
    (and (defined-at-p left x)
         (defined-at-p right x)
         (relation-true-p head (difference-sign left right x)))))
