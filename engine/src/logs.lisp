;;;; Exponents and logarithms. A line is reduced to the ordinary algebra it stands for, with the
;;;; conditions a logarithm carries: log2(x) + log2(x - 2) = 3 is x > 0, x - 2 > 0 and x(x - 2) = 8. The
;;;; sign charts then decide it as they decide any line.
;;;;
;;;; A number such as log2(5) has no exact form among the surds, so it is kept as a ratio of two
;;;; vectors of prime powers, [5]/[2]. Logarithms of primes are independent over the rationals, so two
;;;; such numbers with the same bottom are equal exactly when their tops are. A number here is a
;;;; rational, (:log top bottom), or (:epow c r) for c times e^r.

(in-package :symalgebra.engine)

(defconstant +max-factored+ 10000000000)

(defun key-rank (key)
  (if (eq key :e) 0 key))

(defun vplus (a b)
  (let ((out (copy-alist a)))
    (dolist (item b)
      (let ((found (assoc (car item) out)))
        (if found
            (setf out (substitute (cons (car item) (+ (cdr found) (cdr item))) found out))
            (push item out))))
    (sort (remove 0 out :key #'cdr) #'< :key (lambda (item) (key-rank (car item))))))

(defun vscale (c a)
  (if (zerop c) nil (mapcar (lambda (item) (cons (car item) (* c (cdr item)))) a)))

(defun integer-factors (n)
  "N as a vector of prime powers."
  (when (> n +max-factored+)
    (refuse "limit"))
  (let ((found '()) (p 2))
    (loop while (<= (* p p) n)
          do (loop while (zerop (mod n p))
                   do (setf found (vplus found (list (cons p 1))) n (/ n p)))
             (incf p))
    (if (> n 1) (vplus found (list (cons n 1))) found)))

(defun prime-vector (q)
  (vplus (integer-factors (numerator q)) (vscale -1 (integer-factors (denominator q)))))

(defun base-vector (b)
  (if (eq b :e) (list (cons :e 1)) (prime-vector b)))

(defun proportion (u v)
  "The number c with U = c V, or NIL. V is not empty."
  (let ((c (let ((item (assoc (car (first v)) u))) (if item (/ (cdr item) (cdr (first v))) 0))))
    (and (equal u (vscale c v)) c)))

(defun primitive-factor (v)
  "What to multiply V by to get whole numbers with no common factor and a first entry above zero."
  (let* ((parts (mapcar #'cdr v))
         (size (/ (apply #'lcm (mapcar #'denominator parts))
                  (apply #'gcd (mapcar #'numerator parts)))))
    (if (minusp (first parts)) (- size) size)))

(defun make-log (top bottom)
  "The number TOP/BOTTOM, which is rational when the two are in proportion."
  (let* ((f (primitive-factor bottom)) (u (vscale f top)) (v (vscale f bottom)))
    (cond ((null u) 0)
          ((proportion u v))
          (t (list :log u v)))))

(defun log-number-p (a) (and (consp a) (eq (first a) :log)))
(defun epow-number-p (a) (and (consp a) (eq (first a) :epow)))

(defun make-epow (c r)
  (if (or (zerop r) (zerop c)) c (list :epow c r)))

(defun lv+ (a b)
  (cond ((and (rationalp a) (rationalp b)) (+ a b))
        ((eql a 0) b)
        ((eql b 0) a)
        ((and (log-number-p a) (rationalp b))
         (make-log (vplus (second a) (vscale b (third a))) (third a)))
        ((and (rationalp a) (log-number-p b)) (lv+ b a))
        ((and (log-number-p a) (log-number-p b))
         (unless (equal (third a) (third b))
           (refuse "log_bases"))
         (make-log (vplus (second a) (second b)) (third a)))
        (t (refuse "log_constant"))))

(defun lv* (a b)
  (cond ((and (rationalp a) (rationalp b)) (* a b))
        ((and (rationalp a) (log-number-p b)) (make-log (vscale a (second b)) (third b)))
        ((and (log-number-p a) (rationalp b)) (lv* b a))
        ((and (rationalp a) (epow-number-p b)) (make-epow (* a (second b)) (third b)))
        ((and (epow-number-p a) (rationalp b)) (lv* b a))
        ((and (epow-number-p a) (epow-number-p b))
         (make-epow (* (second a) (second b)) (+ (third a) (third b))))
        (t (refuse "log_constant"))))

(defun lneg (a) (lv* -1 a))

(defun lv/ (a b)
  (cond ((eql b 0) (refuse "empty_domain"))
        ((rationalp b) (lv* (/ b) a))
        ((and (log-number-p a) (log-number-p b))
         (unless (equal (third a) (third b))
           (refuse "log_bases"))
         (make-log (second a) (second b)))
        ((and (epow-number-p a) (epow-number-p b))
         (make-epow (/ (second a) (second b)) (- (third a) (third b))))
        (t (refuse "log_constant"))))

(defun exact-root (a n)
  (reduce #'* (mapcar (lambda (item)
                        (let ((power (/ (cdr item) n)))
                          (unless (integerp power) (refuse "log_constant"))
                          (expt (car item) power)))
                      (prime-vector a))
          :initial-value 1))

(defun rational-power (a e)
  (cond ((integerp e)
         (when (and (zerop a) (<= e 0))
           (refuse "empty_domain"))
         (expt a e))
        ((<= a 0) (refuse "log_domain"))
        (t (expt (exact-root a (denominator e)) (numerator e)))))

(defun lv-power (a e)
  (unless (rationalp e)
    (refuse "log_constant"))
  (cond ((rationalp a)
         (when (> (abs e) 64) (refuse "limit"))
         (rational-power a e))
        ((and (epow-number-p a) (eql (second a) 1)) (make-epow 1 (* (third a) e)))
        (t (refuse "log_constant"))))

(defun check-base (b)
  (unless (or (eq b :e) (and (rationalp b) (plusp b) (/= b 1)))
    (refuse "log_base"))
  b)

(defun lv-vector (a)
  "A positive number as a vector, with e as one of its primes."
  (cond ((eql a 0) (refuse "log_domain"))
        ((rationalp a) (if (minusp a) (refuse "log_domain") (prime-vector a)))
        ((and (epow-number-p a) (plusp (second a)))
         (vplus (prime-vector (second a)) (list (cons :e (third a)))))
        (t (refuse "log_constant"))))

(defun lv-log (b a)
  (make-log (lv-vector a) (base-vector b)))

(defun has-x-p (tree)
  (mentions-p :x tree))

(defun lconst (tree)
  "The value of TREE, which has no x."
  (cond ((numberp tree) tree)
        ((eq tree :e) (make-epow 1 1))
        ((eq (first tree) :const) (second tree))
        (t (destructuring-bind (head a &optional b) tree
             (ecase head
               (+ (lv+ (lconst a) (lconst b)))
               (- (lv+ (lconst a) (lneg (lconst b))))
               (* (lv* (lconst a) (lconst b)))
               (/ (lv/ (lconst a) (lconst b)))
               (neg (lneg (lconst a)))
               ((^ exp) (lv-power (lconst a) (lconst b)))
               (log (lv-log (check-base a) (lconst b)))
               (sqrt (lv-power (lconst a) 1/2))
               (abs (let ((inner (lconst a)))
                      (if (rationalp inner) (abs inner) (refuse "log_constant")))))))))

(defun vector-sign (v)
  "The sign of the sum of each power times the logarithm of its prime."
  (cond ((null v) 0)
        ((assoc :e v) (if (rest v) (refuse "log_constant") (signum (cdr (first v)))))
        (t (let* ((d (reduce #'lcm (mapcar (lambda (item) (denominator (cdr item))) v)))
                  (n (reduce #'* (mapcar (lambda (item) (expt (car item) (* d (cdr item)))) v))))
             (signum (- n 1))))))

(defun lsign (a)
  (cond ((rationalp a) (signum a))
        ((epow-number-p a) (signum (second a)))
        (t (* (vector-sign (second a)) (vector-sign (third a))))))

;;; From a typed tree to one with its constants worked out.

(defun folded-power (base exponent)
  "BASE to a number, with BASE over x."
  (let ((n (lconst exponent)))
    (cond ((not (integerp n)) (refuse "exponent_range"))
          ((> (abs n) +max-exponent+) (refuse "exponent_range"))
          ((plusp n) (list '^ base n))
          ((zerop n) (list '/ base base))
          (t (list '/ 1 (list '^ base (- n)))))))

(defun fold (tree)
  "TREE with each part free of x worked out, kept as (:const n) when it is not rational."
  (cond ((eq tree :x) tree)
        ((not (has-x-p tree))
         (let ((n (lconst tree))) (if (rationalp n) n (list :const n))))
        ((eq (first tree) '^) (list '^ (fold (second tree)) (third tree)))
        ((eq (first tree) 'log) (list 'log (check-base (second tree)) (fold (third tree))))
        ((and (eq (first tree) 'exp) (has-x-p (second tree)))
         (folded-power (fold (second tree)) (third tree)))
        ((eq (first tree) 'exp) (list 'exp (fold (second tree)) (fold (third tree))))
        (t (cons (first tree) (mapcar #'fold (rest tree))))))

(defun holds-constant-p (tree)
  (and (consp tree)
       (or (eq (first tree) :const)
           (some #'holds-constant-p (rest tree)))))

(defun transcendental-p (tree)
  (and (consp tree)
       (not (eq (first tree) :const))
       (or (member (first tree) '(log exp))
           (some #'transcendental-p (rest tree)))))

(defun linear-of (tree)
  "TREE as (slope . constant) in x, numbers of either kind."
  (cond ((eq tree :x) (cons 1 0))
        ((or (numberp tree) (eq (first tree) :const)) (cons 0 (lconst tree)))
        (t (destructuring-bind (head a &optional b) tree
             (let ((p (linear-of a)) (q (and b (linear-of b))))
               (flet ((scaled (c line) (cons (lv* c (car line)) (lv* c (cdr line)))))
                 (case head
                   (+ (cons (lv+ (car p) (car q)) (lv+ (cdr p) (cdr q))))
                   (- (cons (lv+ (car p) (lneg (car q))) (lv+ (cdr p) (lneg (cdr q)))))
                   (neg (scaled -1 p))
                   (* (cond ((eql (car p) 0) (scaled (cdr p) q))
                            ((eql (car q) 0) (scaled (cdr q) p))
                            (t (refuse "log_form"))))
                   (/ (unless (eql (car q) 0) (refuse "log_form"))
                    (cons (lv/ (car p) (cdr q)) (lv/ (cdr p) (cdr q))))
                   (t (refuse "log_form")))))))))

(defun flipped (head)
  (ecase head (= '=) (< '>) (<= '>=) (> '<) (>= '<=)))

(defun solved-line (head left right)
  "(:solved head value): x stands against a number of either kind."
  (let* ((a (linear-of left)) (b (linear-of right))
         (m (lv+ (car a) (lneg (car b))))
         (k (lv+ (cdr b) (lneg (cdr a)))))
    (when (eql m 0)
      (refuse "log_form"))
    (list :solved (if (minusp (lsign m)) (flipped head) head) (lv/ k m))))

(defun signed-terms (tree sign)
  "TREE as a list of (c . term), with c rational."
  (flet ((scaled (c part) (signed-terms part (* sign c))))
    (cond ((atom tree) (list (cons sign tree)))
          (t (case (first tree)
               (+ (append (scaled 1 (second tree)) (scaled 1 (third tree))))
               (- (append (scaled 1 (second tree)) (scaled -1 (third tree))))
               (neg (scaled -1 (second tree)))
               (* (cond ((numberp (second tree)) (scaled (second tree) (third tree)))
                        ((numberp (third tree)) (scaled (third tree) (second tree)))
                        (t (list (cons sign tree)))))
               (/ (cond ((eql (third tree) 0) (refuse "empty_domain"))
                        ((numberp (third tree)) (scaled (/ (third tree)) (second tree)))
                        (t (list (cons sign tree)))))
               (t (list (cons sign tree))))))))

(defun constant-term-p (term)
  (or (numberp term) (and (consp term) (eq (first term) :const))))

(defun log-term-p (term)
  (and (consp term) (eq (first term) 'log)))

(defun exp-term-p (term)
  (and (consp term) (eq (first term) 'exp)))

(defun term-sum (terms)
  "The sum of constant TERMS."
  (reduce #'lv+ (mapcar (lambda (item) (lv* (car item) (lconst (cdr item)))) terms) :initial-value 0))

(defun base-power (b k)
  "B to the number K."
  (cond ((eq b :e)
         (cond ((rationalp k) (make-epow 1 k))
               ((and (log-number-p k) (equal (third k) (base-vector :e))) (vector-number (second k)))
               (t (refuse "log_constant"))))
        ((rationalp k) (lv-power b k))
        ((log-number-p k)
         (let ((a (proportion (base-vector b) (third k))))
           (unless a (refuse "log_bases"))
           (vector-number (vscale a (second k)))))
        (t (refuse "log_constant"))))

(defun vector-number (v)
  "The rational a vector of whole powers stands for."
  (reduce #'* (mapcar (lambda (item)
                        (unless (and (integerp (cdr item)) (integerp (car item)))
                          (refuse "log_constant"))
                        (expt (car item) (cdr item)))
                      v)
          :initial-value 1))

(defun product-tree (parts)
  (reduce (lambda (a b) (list '* a b)) parts))

(defun powered-parts (terms)
  "Each log argument repeated as often as its whole coefficient says."
  (loop for (c . term) in terms
        append (make-list (abs c) :initial-element (third term))))

(defun split-logs (terms)
  "The base of TERMS, and the top and bottom of the one fraction their sum is the log of."
  (let ((base (second (cdr (first terms)))))
    (dolist (item terms)
      (unless (equal (second (cdr item)) base) (refuse "log_bases"))
      (unless (integerp (car item)) (refuse "log_form")))
    (let ((tops (powered-parts (remove-if-not (lambda (item) (plusp (car item))) terms)))
          (bottoms (powered-parts (remove-if-not (lambda (item) (minusp (car item))) terms))))
      (values base (if tops (product-tree tops) 1) (and bottoms (product-tree bottoms))))))

(defun log-conditions (terms)
  (mapcar (lambda (item) (list '< 0 (third (cdr item)))) terms))

(defun reduce-logs (head terms k)
  "The relation: TERMS, each c log(P), plus the number K, against 0."
  (multiple-value-bind (base top bottom) (split-logs terms)
    (let* ((side (if bottom (list '/ top bottom) top))
           (value (base-power base (lneg k)))
           (head (if (and (rationalp base) (< base 1)) (flipped head) head)))
      (if (rationalp value)
          (cons 'and (append (log-conditions terms) (list (list head side value))))
          (progn
            (unless (eq head '=) (refuse "log_constant"))
            (solved-line head side (list :const value)))))))

(defun exp-base (term)
  "The base of an exponential term, as a rational or :E."
  (let ((b (second term)))
    (cond ((rationalp b) (check-base b))
          ((and (consp b) (eq (first b) :const) (equal (second b) (make-epow 1 1))) :e)
          (t (refuse "log_base")))))

(defun rising-vector (b)
  "A vector for the base of B that grows with its exponent: a base above 1."
  (let* ((v (base-vector b))
         (rising (if (and (rationalp b) (< b 1)) (vscale -1 v) v)))
    (vscale (abs (primitive-factor rising)) rising)))

(defun scaled-exponent (term)
  "The exponent of TERM over the rising base, with that base's vector."
  (let* ((v (base-vector (exp-base term)))
         (rising (rising-vector (exp-base term))))
    (values (list '* (proportion v rising) (third term)) rising)))

(defun answer-line (head left right)
  "An ordinary line, or a solved one when RIGHT is not rational."
  (if (holds-constant-p (list head left right))
      (solved-line head left right)
      (list head left right)))

(defun reduce-one-exp (head c term k)
  "The relation c b^E + k against 0."
  (let* ((head (if (minusp c) (flipped head) head))
         (q (lv/ (lneg k) c)))
    (if (and (rationalp q) (<= q 0))
        (list '= 0 (if (member head '(> >=)) 0 1))
        (multiple-value-bind (exponent rising) (scaled-exponent term)
          (let ((m (make-log (lv-vector q) rising)))
            (answer-line head exponent (if (rationalp m) m (list :const m))))))))

(defun reduce-two-exps (head a b)
  "The relation c b1^E1 - c b2^E2 against 0."
  (unless (= (car a) (- (car b)))
    (refuse "log_form"))
  (multiple-value-bind (left left-rising) (scaled-exponent (cdr a))
    (multiple-value-bind (right right-rising) (scaled-exponent (cdr b))
      (unless (equal left-rising right-rising)
        (refuse "log_bases"))
      (list (if (minusp (car a)) (flipped head) head) left right))))

(defun reduce-relation (relation)
  (destructuring-bind (head left right) relation
    (let* ((l (fold left)) (r (fold right))
           (terms (append (signed-terms l 1) (signed-terms r -1)))
           (constants (remove-if-not (lambda (item) (constant-term-p (cdr item))) terms))
           (logs (remove-if-not (lambda (item) (log-term-p (cdr item))) terms))
           (exps (remove-if-not (lambda (item) (exp-term-p (cdr item))) terms))
           (others (set-difference terms (append constants logs exps))))
      (cond ((and (null logs) (null exps))
             (when (transcendental-p (list l r)) (refuse "log_form"))
             (answer-line head l r))
            ((and logs (null exps) (null others))
             (reduce-logs head logs (term-sum constants)))
            ((and exps (null logs) (null others))
             (cond ((null (rest exps))
                    (reduce-one-exp head (car (first exps)) (cdr (first exps)) (term-sum constants)))
                   ((and (null (cddr exps)) (eql (term-sum constants) 0))
                    (reduce-two-exps head (first exps) (second exps)))
                   (t (refuse "log_form"))))
            (t (refuse "log_form"))))))

(defun reduce-line (line)
  "LINE as ordinary algebra, or (:solved head value) when its number is not rational."
  (if (member (first line) '(or and))
      (let ((parts (mapcar #'reduce-line (rest line))))
        (when (find :solved parts :key #'first) (refuse "log_form"))
        (cons (first line) parts))
      (reduce-relation line)))

(defun as-solved (line)
  (cond ((eq (first line) :solved) line)
        ((member (first line) '(or and)) (refuse "log_constant"))
        (t (solved-line (first line) (second line) (third line)))))

(defun lines-verdict (a b)
  "The verdict between two reduced lines."
  (if (or (eq (first a) :solved) (eq (first b) :solved))
      (let ((p (as-solved a)) (q (as-solved b)))
        (if (equal p q)
            (list :verdict :equivalent)
            (list :verdict :unrelated :shape "Log" :set nil :witness (third q))))
      (verdict a b)))

(defun log-line (text var)
  (let ((*logs* t))
    (parse-line text var)))

(defun check-log-lines (before after &key (var #\x))
  (handler-case
      (with-fuel (lines-verdict (reduce-line (log-line before var)) (reduce-line (log-line after var))))
    (refused (r) (list :verdict :out-of-fragment :reason (refused-reason r)))))

;;; Lines that are a value: a number, an expression, or a sum of logs over x.

(defun log-value-line (text var)
  (let ((*logs* t))
    (parse-expression-line text var)))

(defun log-form (tree)
  "A sum of logs over x as (base side conditions), every number folded into SIDE."
  (let* ((terms (signed-terms tree 1))
         (logs (remove-if-not (lambda (item) (log-term-p (cdr item))) terms))
         (constants (remove-if-not (lambda (item) (constant-term-p (cdr item))) terms)))
    (unless (and logs (= (length terms) (+ (length logs) (length constants))))
      (refuse "log_form"))
    (multiple-value-bind (base top bottom) (split-logs logs)
      (let* ((scale (base-power base (term-sum constants)))
             (side (if bottom (list '/ top bottom) top)))
        (unless (rationalp scale) (refuse "log_constant"))
        (list base (list '* scale side) (log-conditions logs))))))

(defun forms-verdict (a b)
  (destructuring-bind (base-a side-a conditions-a) a
    (destructuring-bind (base-b side-b conditions-b) b
      (let ((same (and (equal base-a base-b)
                       (same-as-start-p (expression-verdict side-a side-b))
                       (eq (getf (verdict (cons 'and conditions-a) (cons 'and conditions-b)) :verdict)
                           :equivalent))))
        (if same
            (list :verdict :equivalent)
            (list :verdict :unrelated :shape "Log" :set nil :witness 0))))))

(defun check-log-values (before after &key (var #\x))
  (handler-case
      (with-fuel
        (let ((a (fold (log-value-line before var))) (b (fold (log-value-line after var))))
          (cond ((and (not (has-x-p a)) (not (has-x-p b)))
                 (let ((p (lconst a)) (q (lconst b)))
                   (if (equal p q)
                       (list :verdict :equivalent)
                       (list :verdict :unrelated :shape "Log" :set nil :witness q))))
                ((or (exp-holds-p a) (exp-holds-p b)) (refuse "log_form"))
                ((or (transcendental-p a) (transcendental-p b)) (forms-verdict (log-form a) (log-form b)))
                ((or (holds-constant-p a) (holds-constant-p b)) (refuse "log_form"))
                (t (expression-verdict a b)))))
    (refused (r) (list :verdict :out-of-fragment :reason (refused-reason r)))))

(defun exp-holds-p (tree)
  (and (consp tree)
       (not (eq (first tree) :const))
       (or (eq (first tree) 'exp)
           (some #'exp-holds-p (rest tree)))))

;;; Writing a number down.

(defun vector-text (v)
  (format nil "~{~a~^ + ~}"
          (mapcar (lambda (item)
                    (destructuring-bind (key . power) item
                      (cond ((eq key :e) (format nil "~a" power))
                            ((= power 1) (format nil "ln(~a)" key))
                            (t (format nil "~a ln(~a)" power key)))))
                  v)))

(defun lv-text (a)
  "Text for a person. It is not compared with anything."
  (cond ((rationalp a) (rational-text a))
        ((epow-number-p a)
         (format nil "~:[~a ~;~*~]e^~a" (eql (second a) 1) (second a) (third a)))
        ((equal (third a) (base-vector :e)) (vector-text (second a)))
        (t (format nil "(~a)/(~a)" (vector-text (second a)) (vector-text (third a))))))

(defun witness-text (witness)
  (if (or (log-number-p witness) (epow-number-p witness))
      (lv-text witness)
      (rational-text witness)))

(defun log-verdict-text (v)
  "The verdict alone, or the refusal. The oracle judges these lines by evaluating them."
  (case (getf v :verdict)
    (:out-of-fragment (format nil "OUT_OF_FRAGMENT ~a" (getf v :reason)))
    (t (verdict-name v))))

;;; Using a verdict.

(defun log-term-answer-p (tree)
  (and (consp tree)
       (case (first tree)
         (log (numberp (third tree)))
         (exp (and (eq (second tree) :e) (numberp (third tree))))
         (^ (eq (second tree) :e))
         (neg (log-term-answer-p (second tree)))
         (* (and (numberp (second tree)) (log-term-answer-p (third tree))))
         (/ (and (log-term-answer-p (second tree))
                 (or (numberp (third tree)) (log-term-answer-p (third tree))))))))

(defun log-answer-p (tree)
  (or (answer-p tree) (log-term-answer-p tree)))

(defun log-solved-p (line)
  (if (member (first line) '(or and))
      (every #'log-solved-p (rest line))
      (or (and (eq (second line) :x) (log-answer-p (third line)))
          (and (eq (third line) :x) (log-answer-p (second line))))))

(defun log-claim (line0 text var)
  (let* ((line (reduce-line (log-line line0 var)))
         (right (and (not (eq (first line) :solved))
                     (eq (getf (verdict line (if (string= text "no solution") '(= 0 1) '(= 0 0))) :verdict)
                         :equivalent))))
    (list :status (if right :accepted :rejected) :solved right)))

(defun check-log-step (line0 text &key (var #\x))
  "Judge the equation TEXT in a task that began at LINE0."
  (if (claim-p text)
      (handler-case (with-fuel (log-claim line0 text var))
        (refused (r) (list :status :out-of-fragment :verdict (list :reason (refused-reason r)) :solved nil)))
      (let* ((verdict (check-log-lines line0 text :var var)) (kind (getf verdict :verdict)))
        (cond ((eq kind :equivalent)
               (list :status :accepted :verdict verdict :solved (log-solved-p (log-line text var))))
              ((eq kind :gains) (list :status :caution :verdict verdict :solved nil))
              ((eq kind :out-of-fragment) (list :status :out-of-fragment :verdict verdict :solved nil))
              (t (list :status :rejected :verdict verdict :solved nil))))))

(defun check-log-value-step (line0 text finished &key (var #\x))
  "Judge the value TEXT in a task that began at LINE0."
  (let* ((verdict (check-log-values line0 text :var var)) (kind (getf verdict :verdict)))
    (cond ((eq kind :out-of-fragment) (list :status :out-of-fragment :verdict verdict :solved nil))
          ((same-as-start-p verdict)
           (list :status :accepted :verdict verdict
                 :solved (and (member (log-value-line text var) finished :test #'equal
                                      :key (lambda (form) (log-value-line form var)))
                              t)))
          (t (list :status :rejected :verdict verdict :solved nil)))))
