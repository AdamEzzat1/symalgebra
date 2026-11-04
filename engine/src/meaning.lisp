;;;; The meaning of a line and the verdict on a step, as defined in docs/SEMANTICS.md.
;;;; Domains come from the typed tree. A solution set is (:finite . p), the real roots of p, or
;;;; (:allexcept . p), every real number but those roots. p is squarefree, so sets compare by gcd.
;;;; A polynomial's numbers may be surds, because a line can hold sqrt of a number.

(in-package :symalgebra.engine)

(defconstant +max-degree+ 8)

(defvar *zeros*)

(defun rf-power (base n)
  (let ((out base))
    (dotimes (i (1- n) out)
      (setf out (rf* out base)))))

(defun variable-radical-p (tree)
  (and (consp tree) (eq (first tree) 'sqrt) (has-variable-p (second tree))))

(defun holds-variable-radical-p (tree)
  (and (consp tree)
       (or (variable-radical-p tree)
           (some #'holds-variable-radical-p (rest tree)))))

(defun radical-value (inner)
  "The square root of the expression INNER, which has to be a nonnegative rational number."
  (when (has-variable-p inner)
    (refuse "radical_variable"))
  (let ((n (value inner 0)))
    (cond ((null n) (refuse "empty_domain"))
          ((consp n) (refuse "nested_radical"))
          ((minusp n) (refuse "negative_radicand"))
          (t (rational-root n)))))

(defun typed-radicands (tree)
  "The d of each surd written in TREE."
  (cond ((atom tree) nil)
        ((variable-radical-p tree) nil)
        ((eq (first tree) 'sqrt)
         (let ((d (part-d (radical-value (second tree))))) (and d (list d))))
        (t (mapcan #'typed-radicands (rest tree)))))

(defun check-radicals (&rest lines)
  (when (rest (remove-duplicates (mapcan #'typed-radicands lines)))
    (refuse "many_radicals")))

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
               (sqrt (cons (trim (list (radical-value a))) '(1)))
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
  (let ((members (exact-roots (cdr difference))))
    (list :verdict name
          :shape (if (eq (car difference) :finite) "Finite" "AllExcept")
          :set members
          :witness (witness-of (car difference) members))))

(defun verdict (previous line)
  "The verdict on a step from one line tree to the next, with an exact witness."
  (handler-case
      (with-fuel
        (let* ((before (progn (check-radicals previous line)
                              (when (or (chart-line-p previous) (chart-line-p line))
                                (return-from verdict (chart-verdict previous line)))
                              (solution-set previous)))
               (after (solution-set line))
               (lost (subtract before after))
               (gained (subtract after before))
               (no-loss (empty-set-p lost))
               (no-gain (empty-set-p gained)))
          ;; An inexact gain must refuse even where the payload would only show the loss.
          (unless no-gain (exact-roots (cdr gained)))
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

(defun surd-core (u v d)
  "u + v*sqrt(d), as a person writes it."
  (let ((size (if (= (abs v) 1) "" (format nil "~a" (abs v)))))
    (cond ((zerop u) (format nil "~:[~;-~]~asqrt(~a)" (minusp v) size d))
          (t (format nil "~a ~:[+~;-~] ~asqrt(~a)" u (minusp v) size d)))))

(defun rational-text (q)
  "Exact text for a number: 3/2, sqrt(2), -2sqrt(3), 1 - sqrt(5), (1 + 3sqrt(5))/2."
  (if (rationalp q)
      (format nil "~a" q)
      (let* ((a (part-a q)) (b (part-b q))
             (bottom (lcm (denominator a) (denominator b)))
             (core (surd-core (* a bottom) (* b bottom) (part-d q))))
        (cond ((= bottom 1) core)
              ((zerop a) (format nil "~a/~a" core bottom))
              (t (format nil "(~a)/~a" core bottom))))))

(defun verdict-text (v)
  "The exact text compared byte for byte with the oracle."
  (case (getf v :verdict)
    (:equivalent "EQUIVALENT")
    (:out-of-fragment (format nil "OUT_OF_FRAGMENT ~a" (getf v :reason)))
    (t (format nil "~a ~a{~{~a~^,~}} witness=~a" (verdict-name v) (getf v :shape)
               (if (string= (getf v :shape) "Ranges")
                   (mapcar #'piece-text (getf v :pieces))
                   (mapcar #'rational-text (getf v :set)))
               (rational-text (getf v :witness))))))

;;; Sign charts: the breakpoints of a line, and whether it holds at each and in each gap.

(defconstant +max-abs+ 3)

(defun chart-line-p (tree)
  "Does TREE hold an inequality, an absolute value, or a root over the variable?"
  (and (consp tree)
       (or (member (first tree) '(< <= > >= abs))
           (variable-radical-p tree)
           (some #'chart-line-p (rest tree)))))

(defun abs-count (tree)
  (if (atom tree)
      0
      (+ (if (eq (first tree) 'abs) 1 0) (reduce #'+ (mapcar #'abs-count (rest tree))))))

(defun opened (tree)
  "Each way to read TREE with its absolute values opened, one sign each."
  (cond ((atom tree) (list tree))
        ((eq (first tree) 'abs)
         (let ((inner (opened (second tree))))
           (append inner (mapcar (lambda (item) (list 'neg item)) inner))))
        (t (let ((choices (list (list (first tree)))))
             (dolist (arg (rest tree) choices)
               (let ((options (opened arg)))
                 (setf choices (loop for choice in choices
                                     append (mapcar (lambda (option) (append choice (list option)))
                                                    options)))))))))

(defun relations (line)
  (if (member (first line) '(or and))
      (mapcan #'relations (copy-list (rest line)))
      (list line)))

(defun difference-bounds (left right)
  "The roots and removed values of LEFT = RIGHT, sides with no absolute value left in them."
  (if (or (holds-variable-radical-p left) (holds-variable-radical-p right))
      (radical-bounds left right)
      (multiple-value-bind (difference zeros) (line-parts (list '= left right))
        (polynomial-bounds (car difference) zeros))))

(defun polynomial-bounds (top zeros)
  (when (and top (> (degree top) +max-degree+))
    (refuse "degree_limit"))
  (append (and top (exact-roots (psquarefree top))) (exact-roots zeros)))

(defun line-bounds (line)
  (when (> (abs-count line) +max-abs+)
    (refuse "abs_limit"))
  (let ((found '()))
    (dolist (relation (relations line) found)
      (dolist (left (opened (second relation)))
        (dolist (right (opened (third relation)))
          (setf found (append (difference-bounds left right) found)))))))

(defun chart-bounds (&rest lines)
  (let ((all (remove-duplicates (reduce #'append (mapcar #'line-bounds lines)) :test #'equal)))
    (when (rest (remove-duplicates (remove nil (mapcar #'part-d all))))
      (refuse "many_radicals"))
    (sort all #'k<)))

(defun midpoint (a b)
  (k/ (k+ a b) 2))

(defun chart-slots (bounds)
  "A point for each gap and each breakpoint, in order, starting and ending with an outer gap."
  (if (null bounds)
      (list 0)
      (append (list (k+ (first bounds) -1))
              (loop for (bound next) on bounds
                    collect bound
                    collect (if next (midpoint bound next) (k+ bound 1))))))

(defun chart-marks (line slots)
  (mapcar (lambda (x) (holds line x)) slots))

(defun chart-pieces (bounds marks)
  "The true slots as pieces, (low low-closed high high-closed), with NIL for an open end."
  (let ((pieces '()) (open nil) (at (coerce bounds 'vector)))
    (loop for mark in marks
          for slot from 0
          do (let* ((point (oddp slot))
                    (k (floor slot 2))
                    (low (if point (aref at k) (and (plusp k) (aref at (1- k)))))
                    (high (if point (aref at k) (and (< k (length at)) (aref at k)))))
               (cond ((not mark)
                      (when open (push open pieces))
                      (setf open nil))
                     (open (setf (third open) high (fourth open) point))
                     (t (setf open (list low point high point))))))
    (when open (push open pieces))
    (reverse pieces)))

(defun point-piece-p (piece)
  (destructuring-bind (low closed high) (subseq piece 0 3)
    (and closed low (equal low high))))

(defun piece-witness (piece)
  (destructuring-bind (low high) (list (first piece) (third piece))
    (cond ((point-piece-p piece) low)
          ((and low high) (midpoint low high))
          (low (k+ low 1))
          (high (k+ high -1))
          (t 0))))

(defun piece-text (piece)
  (destructuring-bind (low low-closed high high-closed) piece
    (if (point-piece-p piece)
        (format nil "{~a}" (rational-text low))
        (format nil "~:[(~;[~]~a,~a~:[)~;]~]" low-closed
                (if low (rational-text low) "-inf") (if high (rational-text high) "inf")
                high-closed))))

(defun chart-payload (name bounds marks)
  (let* ((pieces (chart-pieces bounds marks))
         (finite (every #'point-piece-p pieces)))
    (list :verdict name
          :shape (if finite "Finite" "Ranges")
          :set (and finite (mapcar #'first pieces))
          :pieces pieces
          :witness (piece-witness (first pieces)))))

(defun chart-verdict (previous line)
  (let* ((bounds (chart-bounds previous line))
         (slots (chart-slots bounds))
         (before (chart-marks previous slots))
         (after (chart-marks line slots))
         (lost (mapcar (lambda (b a) (and b (not a))) before after))
         (gained (mapcar (lambda (b a) (and a (not b))) before after)))
    (cond ((and (notany #'identity lost) (notany #'identity gained)) (list :verdict :equivalent))
          ((notany #'identity lost) (chart-payload :gains bounds gained))
          ((notany #'identity gained) (chart-payload :loses bounds lost))
          (t (chart-payload :unrelated bounds lost)))))

(defun chart-empty-p (line)
  (notany #'identity (chart-marks line (chart-slots (chart-bounds line)))))

(defun chart-cofinite-p (line)
  "Does LINE hold in every gap of its chart, so at all but a few values?"
  (loop for mark in (chart-marks line (chart-slots (chart-bounds line)))
        for slot from 0
        always (or mark (oddp slot))))

;;; Strict evaluation: a zero divisor has no value, and NIL spreads upward.

(defun combine (head values)
  (ecase head
    (+ (reduce #'k+ values))
    (- (k+ (first values) (kneg (second values))))
    (* (reduce #'q* values))
    (/ (unless (eql (second values) 0)
         (k/ (first values) (second values))))))

(defun kpower (base n)
  (let ((out 1))
    (dotimes (i n out)
      (setf out (q* out base)))))

(defun value (tree x)
  (with-fuel (evaluate tree x)))

(defun evaluate (tree x)
  (cond ((eq tree :x) x)
        ((numberp tree) tree)
        ((eq (first tree) '^)
         (let ((base (evaluate (second tree) x)))
           (and base (kpower base (third tree)))))
        ((variable-radical-p tree)
         (let ((inner (evaluate (second tree) x)))
           (cond ((or (null inner) (minusp (ksign inner))) nil)
                 ((ksquare-root inner))
                 (t (refuse "irrational_root")))))
        ((eq (first tree) 'sqrt) (radical-value (second tree)))
        ((eq (first tree) 'abs)
         (let ((inner (evaluate (second tree) x)))
           (and inner (kabs inner))))
        ((eq (first tree) 'neg)
         (let ((inner (evaluate (second tree) x)))
           (and inner (kneg inner))))
        (t (let ((values (mapcar (lambda (arg) (evaluate arg x)) (rest tree))))
             (and (notany #'null values)
                  (combine (first tree) values))))))

(defun holds (line x)
  (case (first line)
    (or (some (lambda (item) (holds item x)) (rest line)))
    (and (every (lambda (item) (holds item x)) (rest line)))
    (t (with-fuel
         (if (holds-variable-radical-p line)
             (radical-holds line x)
             (let ((left (value (second line) x)) (right (value (third line) x)))
               (and left right
                    (relation-true-p (first line) (ksign (k+ left (kneg right)))))))))))

(defun relation-true-p (head sign)
  "Is the relation HEAD true of two sides whose difference has SIGN?"
  (ecase head
    (= (zerop sign))
    (< (minusp sign))
    (<= (not (plusp sign)))
    (> (plusp sign))
    (>= (not (minusp sign)))))

(defun solution-members (line)
  (solution-set line))

(defun solution-member-p (set x)
  (let ((root (eql (pvalue (cdr set) x) 0)))
    (if (eq (car set) :finite) root (not root))))
