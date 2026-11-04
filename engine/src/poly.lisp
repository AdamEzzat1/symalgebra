;;;; Exact polynomials in one variable: lists of numbers, lowest degree first, no trailing zeros,
;;;; so the zero polynomial is NIL and `equal` compares. A number is a rational or a surd, a list
;;;; (surd a b d) meaning a + b*sqrt(d), with b nonzero and d a squarefree integer above 1. Real roots
;;;; are handled by Sturm sequences and exact bisection, so no root ever needs an approximation.

(in-package :symalgebra.engine)

(defconstant +max-bits+ 4096)
(defconstant +verdict-fuel+ 2000000)
(defconstant +factor-limit+ 10000)

(defvar *fuel* 0)

(defmacro with-fuel (&body body)
  "Work is counted, not timed, so a verdict cannot vary with the machine."
  `(let ((*fuel* +verdict-fuel+)) ,@body))

(defun tick (&optional (n 1))
  (when (minusp (decf *fuel* n))
    (refuse "limit")))

(defun bits (q)
  (max (integer-length (numerator q)) (integer-length (denominator q))))

(defun r* (a b)
  "Multiply rationals, refusing before the product can exceed the size limit."
  (tick)
  (when (> (+ (bits a) (bits b)) +max-bits+)
    (refuse "limit"))
  (* a b))

;;; Surds. Two with different d have no common form here, which is `many_radicals`.

(defun surd (a b d)
  (if (eql b 0) a (list 'surd a b d)))

(defun part-a (x) (if (consp x) (second x) x))
(defun part-b (x) (if (consp x) (third x) 0))
(defun part-d (x) (and (consp x) (fourth x)))

(defun common-radicand (x y)
  (let ((d (part-d x)) (e (part-d y)))
    (when (and d e (/= d e))
      (refuse "many_radicals"))
    (or d e)))

(defun k+ (x y)
  (if (and (rationalp x) (rationalp y))
      (+ x y)
      (surd (+ (part-a x) (part-a y)) (+ (part-b x) (part-b y)) (common-radicand x y))))

(defun kneg (x)
  (if (rationalp x) (- x) (surd (- (part-a x)) (- (part-b x)) (part-d x))))

(defun q* (x y)
  (if (and (rationalp x) (rationalp y))
      (r* x y)
      (let ((d (common-radicand x y))
            (a (part-a x)) (b (part-b x)) (u (part-a y)) (v (part-b y)))
        (surd (+ (r* a u) (r* (r* b v) d)) (+ (r* a v) (r* b u)) d))))

(defun kconjugate (x)
  (if (rationalp x) x (surd (part-a x) (- (part-b x)) (part-d x))))

(defun k/ (x y)
  (if (and (rationalp x) (rationalp y))
      (/ x y)
      (let ((norm (part-a (q* y (kconjugate y)))))
        (q* x (q* (kconjugate y) (/ norm))))))

(defun ksign (x)
  (if (rationalp x)
      (signum x)
      (let* ((a (part-a x)) (b (part-b x)) (sa (signum a)) (sb (signum b)))
        (cond ((or (zerop sa) (= sa sb)) sb)
              ((> (r* a a) (r* (r* b b) (part-d x))) sa)
              (t sb)))))

(defun k< (x y)
  (minusp (ksign (k+ x (kneg y)))))

(defun kabs (x)
  (if (minusp (ksign x)) (kneg x) x))

(defun split-square (n)
  "S and D with N = S^2 * D for the positive integer N, and D squarefree."
  (let ((s 1) (d 1))
    (loop for p from 2 to +factor-limit+
          while (<= (* p p) n)
          do (tick)
             (let ((power 0))
               (loop while (zerop (mod n p))
                     do (setf n (/ n p))
                        (incf power))
               (setf s (* s (expt p (floor power 2))))
               (when (oddp power) (setf d (* d p)))))
    ;; What is left has no factor up to the limit, so it is a prime, a square, or too big to tell.
    (let ((root (isqrt n)))
      (cond ((<= (* (1+ +factor-limit+) (1+ +factor-limit+)) n)
             (if (= (* root root) n)
                 (values (* s root) d)
                 (if (< n (expt +factor-limit+ 3))
                     (values s (* d n))
                     (refuse "limit"))))
            (t (values s (* d n)))))))

(defun rational-root (q)
  "The square root of the nonnegative rational Q, exactly."
  (if (zerop q)
      0
      (multiple-value-bind (s d) (split-square (* (numerator q) (denominator q)))
        (let ((b (/ s (denominator q))))
          (if (= d 1) b (surd 0 b d))))))

(defun ksquare-root (x)
  "The square root of X among the surds with X's own d, or NIL. X is not negative."
  (if (rationalp x)
      (rational-root x)
      (let* ((a (part-a x)) (b (part-b x)) (d (part-d x))
             (norm (- (* a a) (* d b b)))
             (root (and (>= norm 0) (rational-root norm))))
        (when (rationalp root)
          (dolist (half (list (/ (+ a root) 2) (/ (- a root) 2)))
            (let ((u (and (plusp half) (rational-root half))))
              (when (rationalp u)
                (return (surd u (/ b (* 2 u)) d)))))))))

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
              collect (k+ (or (car rest-a) 0) (or (car rest-b) 0)))))

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
                       do (setf (car cell) (k+ (car cell) (q* x y)))))
        (trim out))))

(defun pshift (p n)
  (append (make-list n :initial-element 0) p))

(defun pdivide (a b)
  "Quotient and remainder of A by nonzero B."
  (let ((quotient '()) (remainder a))
    (loop while (and remainder (>= (degree remainder) (degree b)))
          do (let* ((power (- (degree remainder) (degree b)))
                    (c (k/ (lead remainder) (lead b)))
                    (term (pshift (list c) power)))
               (setf quotient (p+ quotient term)
                     remainder (p- remainder (p* term b)))))
    (values quotient remainder)))

(defun pquo (a b)
  (values (pdivide a b)))

(defun rational-p-p (p)
  (every #'rationalp p))

(defun pclear (p)
  "P scaled by a positive number to primitive integer coefficients, or with surds in it to leading
coefficient 1 or -1. Either way its signs stay."
  (cond ((null p) nil)
        ((rational-p-p p)
         (let ((den (reduce #'lcm (mapcar #'denominator p)))
               (num (abs (reduce #'gcd (mapcar #'numerator p)))))
           (mapcar (lambda (q) (* q (/ den num))) p)))
        (t (let ((scaled (pscale (k/ 1 (kabs (lead p))) p)))
             (if (rational-p-p scaled) (pclear scaled) scaled)))))

(defun pnormal (p)
  "The primitive multiple of P with a positive leading coefficient."
  (let ((cleared (pclear p)))
    (if (and cleared (minusp (ksign (lead cleared)))) (mapcar #'kneg cleared) cleared)))

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
              collect (q* c i))))

(defun psquarefree (p)
  "The primitive polynomial with the same roots as P, each once."
  (if (< (degree p) 1)
      '(1)
      (pnormal (pquo p (pgcd p (pderivative p))))))

(defun pvalue (p x)
  (let ((total 0))
    (dolist (c (reverse p) total)
      (setf total (k+ (q* total x) c)))))

;;; Rational functions: (top . bottom) in lowest terms, with bottom primitive and positive-leading.

(defun rf (top bottom)
  (if (null top)
      (cons nil '(1))
      (let* ((g (pgcd top bottom))
             (reduced (pquo bottom g))
             (normal (pnormal reduced)))
        (cons (pscale (k/ (lead normal) (lead reduced)) (pquo top g)) normal))))

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
                        (let ((s (ksign (lead p))))
                          (if (and (minusp direction) (oddp (degree p))) (- s) s)))
                      chain)))

(defun root-count (p)
  "The number of distinct real roots of the squarefree polynomial P."
  (if (< (degree p) 1)
      0
      (let ((chain (sturm-chain p)))
        (- (sign-at-infinity chain -1) (sign-at-infinity chain 1)))))

(defun rational-members (p)
  "The rational roots of squarefree P with rational coefficients.
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
      (when (plusp total)
        found))))

(defun rational-part (p)
  "The factor of P with rational coefficients that holds every rational root of P."
  (if (rational-p-p p) p (pgcd p (mapcar #'kconjugate p))))

(defun without-root (p q)
  (pquo p (list (- q) 1)))

(defun small-roots (p)
  "The real roots of P, of degree 1 or 2, refusing if they are not surds of one d."
  (let* ((p (pscale (k/ 1 (lead p)) p))
         (b (second p)))
    (if (= (degree p) 1)
        (list (kneg (first p)))
        (let* ((disc (k+ (q* b b) (q* -4 (first p))))
               (root (ksquare-root disc))
               (half (k/ (kneg b) 2)))
          (when (or (null root)
                    (and (part-d root) (part-d b) (/= (part-d root) (part-d b))))
            (refuse "irrational_root"))
          (list (k+ half (k/ root 2)) (k+ half (k/ (kneg root) 2)))))))

(defun exact-roots (p)
  "The real roots of squarefree P in order, each rational or a surd. With the rational roots taken
out, what is left may have degree 2 at most if it has any real root; otherwise this refuses."
  (when (>= (degree p) 1)
    (let* ((found (rational-members (rational-part p)))
           (left (reduce #'without-root found :initial-value p)))
      (when (plusp (root-count left))
        (when (> (degree left) 2)
          (refuse "irrational_root"))
        (setf found (append found (small-roots left))))
      (sort found #'k<))))
