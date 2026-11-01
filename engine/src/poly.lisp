;;;; Exact polynomials in one variable: lists of rationals, lowest degree first, no trailing zeros,
;;;; so the zero polynomial is NIL and `equal` compares. Real roots are handled by Sturm sequences
;;;; and exact bisection, so an irrational root never needs an approximation.

(in-package :symalgebra.engine)

(defconstant +max-bits+ 4096)
(defconstant +verdict-fuel+ 2000000)

(defvar *fuel* 0)

(defmacro with-fuel (&body body)
  "Work is counted, not timed, so a verdict cannot vary with the machine."
  `(let ((*fuel* +verdict-fuel+)) ,@body))

(defun tick (&optional (n 1))
  (when (minusp (decf *fuel* n))
    (refuse "limit")))

(defun bits (q)
  (max (integer-length (numerator q)) (integer-length (denominator q))))

(defun q* (a b)
  "Multiply, refusing before the product can exceed the size limit."
  (tick)
  (when (> (+ (bits a) (bits b)) +max-bits+)
    (refuse "limit"))
  (* a b))

(defun trim (p)
  (let ((end (position 0 p :test-not #'eql :from-end t)))
    (if end (subseq p 0 (1+ end)) nil)))

(defun degree (p) (1- (length p)))
(defun lead (p) (car (last p)))

(defun p+ (a b)
  (tick (max (length a) (length b)))
  (trim (loop for rest-a = a then (cdr rest-a)
              for rest-b = b then (cdr rest-b)
              while (or rest-a rest-b)
              collect (+ (or (car rest-a) 0) (or (car rest-b) 0)))))

(defun pscale (c p)
  (if (eql c 0) nil (mapcar (lambda (q) (q* c q)) p)))

(defun p- (a b)
  (p+ a (pscale -1 b)))

(defun p* (a b)
  (if (or (null a) (null b))
      nil
      (let ((out (make-list (+ (length a) (length b) -1) :initial-element 0)))
        (loop for x in a
              for i from 0
              do (loop for y in b
                       for cell on (nthcdr i out)
                       do (incf (car cell) (q* x y))))
        (trim out))))

(defun pshift (p n)
  (append (make-list n :initial-element 0) p))

(defun pdivide (a b)
  "Quotient and remainder of A by nonzero B."
  (let ((quotient '()) (remainder a))
    (loop while (and remainder (>= (degree remainder) (degree b)))
          do (let* ((power (- (degree remainder) (degree b)))
                    (c (/ (lead remainder) (lead b)))
                    (term (pshift (list c) power)))
               (setf quotient (p+ quotient term)
                     remainder (p- remainder (p* term b)))))
    (values quotient remainder)))

(defun pquo (a b)
  (values (pdivide a b)))

(defun pclear (p)
  "P scaled by a positive rational to primitive integer coefficients, which keeps its signs."
  (if (null p)
      nil
      (let ((den (reduce #'lcm (mapcar #'denominator p)))
            (num (abs (reduce #'gcd (mapcar #'numerator p)))))
        (mapcar (lambda (q) (* q (/ den num))) p))))

(defun pnormal (p)
  "The primitive integer multiple of P with a positive leading coefficient."
  (let ((cleared (pclear p)))
    (if (and cleared (minusp (lead cleared))) (mapcar #'- cleared) cleared)))

(defun pgcd (a b)
  (loop while b
        do (multiple-value-bind (quotient remainder) (pdivide a b)
             (declare (ignore quotient))
             (setf a b b (pclear remainder))))
  (pnormal a))

(defun plcm (a b)
  (pnormal (pquo (p* a b) (pgcd a b))))

(defun pderivative (p)
  (trim (loop for c in (cdr p)
              for i from 1
              collect (* c i))))

(defun psquarefree (p)
  "The primitive polynomial with the same roots as P, each once."
  (if (< (degree p) 1)
      '(1)
      (pnormal (pquo p (pgcd p (pderivative p))))))

(defun pvalue (p x)
  (let ((total 0))
    (dolist (c (reverse p) total)
      (setf total (+ (q* total x) c)))))

;;; Rational functions: (top . bottom) in lowest terms, with bottom primitive and positive-leading.

(defun rf (top bottom)
  (if (null top)
      (cons nil '(1))
      (let* ((g (pgcd top bottom))
             (reduced (pquo bottom g))
             (normal (pnormal reduced)))
        (cons (pscale (/ (lead normal) (lead reduced)) (pquo top g)) normal))))

(defun rf+ (a b)
  (rf (p+ (p* (car a) (cdr b)) (p* (car b) (cdr a))) (p* (cdr a) (cdr b))))

(defun rf- (a b)
  (rf+ a (cons (pscale -1 (car b)) (cdr b))))

(defun rf* (a b)
  (rf (p* (car a) (car b)) (p* (cdr a) (cdr b))))

(defun rf/ (a b)
  (rf (p* (car a) (cdr b)) (p* (cdr a) (car b))))

;;; Real roots.

(defun sturm-chain (p)
  "p, p', then each negated remainder, cleared without changing any sign."
  (let ((chain (list (pclear (pderivative p)) p)))
    (loop
      (let ((remainder (nth-value 1 (pdivide (second chain) (first chain)))))
        (when (null remainder)
          (return (reverse chain)))
        (push (pclear (pscale -1 remainder)) chain)))))

(defun variations (signs)
  (let ((count 0) (previous nil))
    (dolist (s signs count)
      (unless (zerop s)
        (when (and previous (/= s previous))
          (incf count))
        (setf previous s)))))

(defun sign-at (chain x)
  (variations (mapcar (lambda (p) (signum (pvalue p x))) chain)))

(defun sign-at-infinity (chain direction)
  (variations (mapcar (lambda (p)
                        (let ((s (signum (lead p))))
                          (if (and (minusp direction) (oddp (degree p))) (- s) s)))
                      chain)))

(defun root-count (p)
  "The number of distinct real roots of the squarefree polynomial P."
  (if (< (degree p) 1)
      0
      (let ((chain (sturm-chain p)))
        (- (sign-at-infinity chain -1) (sign-at-infinity chain 1)))))

(defun rational-roots (p)
  "The real roots of squarefree P in order, refusing if any is irrational.
A rational root of an integer polynomial is k/L for L the leading coefficient, so an interval
narrower than 1/L holds at most one, and an exact test on that candidate decides it."
  (when (>= (degree p) 1)
    (let* ((p (pnormal p))
           (chain (sturm-chain p))
           (total (- (sign-at-infinity chain -1) (sign-at-infinity chain 1)))
           (scale (abs (lead p)))
           (bound (1+ (ceiling (reduce #'max (mapcar (lambda (c) (abs (/ c (lead p)))) p)))))
           (found '()))
      (labels ((search-interval (low high low-signs high-signs)
                 (when (> low-signs high-signs)
                   (if (< (* (- high low) scale) 1)
                       (let* ((k (1+ (floor (* low scale))))
                              (candidate (/ k scale)))
                         (when (and (<= candidate high) (zerop (pvalue p candidate)))
                           (push candidate found)))
                       (let* ((middle (/ (+ low high) 2))
                              (middle-signs (sign-at chain middle)))
                         (search-interval low middle low-signs middle-signs)
                         (search-interval middle high middle-signs high-signs))))))
        (search-interval (- bound) bound (sign-at chain (- bound)) (sign-at chain bound)))
      (unless (= (length found) total)
        (refuse "irrational_root"))
      (sort found #'<))))
