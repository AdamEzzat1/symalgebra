;;;; M1 scaffold, discarded at M3. This is not the engine: it exists to test step entry.
;;;; Parses one linear equation and reduces each side to a*x+b with exact rationals.

(defpackage :symalgebra.m1.reducer
  (:use :cl)
  (:export #:parse-failure #:failure-column #:out-of-fragment
           #:parse-line #:equation-left #:equation-right #:reduce-form
           #:difference-form #:solution-set #:value-at #:render-side #:render-line
           #:solved-form-p #:rat))

(in-package :symalgebra.m1.reducer)

(define-condition parse-failure (error)
  ((column :initarg :column :reader failure-column)))

(define-condition out-of-fragment (error) ())

(defun rat (q)
  (if (integerp q)
      (format nil "~d" q)
      (format nil "~d/~d" (numerator q) (denominator q))))

;;; Tokens: (kind value column), columns counted from 1.

(defun read-number-token (line start)
  (let* ((end (or (position-if-not (lambda (c) (or (digit-char-p c) (char= c #\.))) line
                                   :start start)
                  (length line)))
         (word (subseq line start end))
         (dot (position #\. word)))
    (when (or (> (count #\. word) 1) (string= word "."))
      (error 'parse-failure :column (1+ start)))
    (values
     (if dot
         (let ((whole (subseq word 0 dot))
               (part (subseq word (1+ dot))))
           (when (string= part "") (error 'parse-failure :column (+ 1 start dot)))
           (+ (if (string= whole "") 0 (parse-integer whole))
              (/ (parse-integer part) (expt 10 (length part)))))
         (parse-integer word))
     end)))

(defun tokenize (line var)
  (let ((tokens '()) (i 0))
    (loop while (< i (length line)) do
      (let ((c (char line i)))
        (cond ((char= c #\Space) (incf i))
              ((or (digit-char-p c) (char= c #\.))
               (multiple-value-bind (value end) (read-number-token line i)
                 (push (list :num value (1+ i)) tokens)
                 (setf i end)))
              ((char= c var) (push (list :var nil (1+ i)) tokens) (incf i))
              ((find c "+-*/=()") (push (list c nil (1+ i)) tokens) (incf i))
              (t (error 'parse-failure :column (1+ i))))))
    (coerce (nreverse tokens) 'vector)))

;;; expr := term (('+' | '-') term)*
;;; term := unary (('*' | '/') unary | juxtaposed atom)*, left associative
;;; unary := '-' unary | atom
;;; atom := number | variable | '(' expr ')'

(defvar *tokens*)
(defvar *at*)
(defvar *end-column*)

(defun token-kind ()
  (when (< *at* (length *tokens*)) (first (aref *tokens* *at*))))

(defun stuck ()
  (error 'parse-failure
         :column (if (< *at* (length *tokens*))
                     (third (aref *tokens* *at*))
                     *end-column*)))

(defun parse-atom ()
  (case (token-kind)
    (:num (prog1 (list :num (second (aref *tokens* *at*))) (incf *at*)))
    (:var (incf *at*) (list :var))
    (#\( (incf *at*)
     (let ((inner (parse-expr)))
       (unless (eql (token-kind) #\)) (stuck))
       (incf *at*)
       inner))
    (t (stuck))))

(defun parse-unary ()
  (if (eql (token-kind) #\-)
      (progn
        (incf *at*)
        (let ((inner (parse-unary)))
          (if (eq (first inner) :num)
              (list :num (- (second inner)))
              (list :neg inner))))
      (parse-atom)))

(defun parse-term ()
  (let ((left (parse-unary)))
    (loop
      (case (token-kind)
        (#\* (incf *at*) (setf left (list :mul left (parse-unary))))
        (#\/ (incf *at*) (setf left (list :div left (parse-unary))))
        ((:var #\() (setf left (list :mul left (parse-atom))))
        (t (return left))))))

(defun parse-expr ()
  (let ((left (parse-term)))
    (loop
      (case (token-kind)
        (#\+ (incf *at*) (setf left (list :add left (parse-term))))
        (#\- (incf *at*) (setf left (list :sub left (parse-term))))
        (t (return left))))))

(defun parse-line (line var)
  "An equation as (left right), or PARSE-FAILURE with a column."
  (let ((*tokens* (tokenize line var))
        (*at* 0)
        (*end-column* (1+ (length (string-right-trim " " line)))))
    (let ((left (parse-expr)))
      (unless (eql (token-kind) #\=) (stuck))
      (incf *at*)
      (let ((right (parse-expr)))
        (when (token-kind) (stuck))
        (list left right)))))

(defun equation-left (equation) (first equation))
(defun equation-right (equation) (second equation))

;;; Forms: (a . b) means a*x + b.

(defun scale (form k)
  (cons (* k (car form)) (* k (cdr form))))

;;; These two run at each node, before the result can hide what was typed: x*x-x*x and
;;; (2x+2)/(x+1) would otherwise reduce to something linear with the wrong domain.

(defun multiply-forms (l r)
  (unless (or (zerop (car l)) (zerop (car r)))
    (error 'out-of-fragment))
  (if (zerop (car l))
      (scale r (cdr l))
      (scale l (cdr r))))

(defun divide-forms (l r)
  (unless (and (zerop (car r)) (not (zerop (cdr r))))
    (error 'out-of-fragment))
  (scale l (/ 1 (cdr r))))

(defun reduce-form (tree)
  (ecase (first tree)
    (:num (cons 0 (second tree)))
    (:var (cons 1 0))
    (:neg (scale (reduce-form (second tree)) -1))
    (:add (let ((l (reduce-form (second tree))) (r (reduce-form (third tree))))
            (cons (+ (car l) (car r)) (+ (cdr l) (cdr r)))))
    (:sub (let ((l (reduce-form (second tree))) (r (reduce-form (third tree))))
            (cons (- (car l) (car r)) (- (cdr l) (cdr r)))))
    (:mul (multiply-forms (reduce-form (second tree)) (reduce-form (third tree))))
    (:div (divide-forms (reduce-form (second tree)) (reduce-form (third tree))))))

(defun difference-form (equation)
  (let ((l (reduce-form (equation-left equation)))
        (r (reduce-form (equation-right equation))))
    (cons (- (car l) (car r)) (- (cdr l) (cdr r)))))

(defun solution-set (equation)
  "(:one r), (:all) or (:none)."
  (destructuring-bind (a . b) (difference-form equation)
    (cond ((not (zerop a)) (list :one (- (/ b a))))
          ((zerop b) (list :all))
          (t (list :none)))))

(defun value-at (tree x)
  (let ((form (reduce-form tree)))
    (+ (* (car form) x) (cdr form))))

(defun solved-form-p (equation)
  (let ((l (first (equation-left equation)))
        (r (first (equation-right equation))))
    (or (and (eq l :var) (eq r :num))
        (and (eq l :num) (eq r :var)))))

;;; Echo: the structure the parser read, written back as plain text.

(defun atomic-p (tree)
  (or (eq (first tree) :var)
      (and (eq (first tree) :num) (integerp (second tree)))))

(defun bracketed (tree var)
  (if (atomic-p tree)
      (render-side tree var)
      (format nil "(~a)" (render-side tree var))))

(defun render-side (tree var)
  (ecase (first tree)
    (:num (rat (second tree)))
    (:var (string var))
    (:neg (format nil "-~a" (bracketed (second tree) var)))
    (:add (format nil "~a + ~a" (render-side (second tree) var) (render-side (third tree) var)))
    (:sub (let ((r (third tree)))
            (format nil "~a - ~a" (render-side (second tree) var)
                    (if (member (first r) '(:add :sub))
                        (bracketed r var)
                        (render-side r var)))))
    (:mul (let ((l (second tree)) (r (third tree)))
            (if (and (eq (first l) :num) (integerp (second l)) (eq (first r) :var))
                (format nil "~a~a" (rat (second l)) (string var))
                ;; A quotient stays bracketed here so the echo shows how 2/3x was grouped.
                (format nil "~a * ~a"
                        (if (eq (first l) :mul) (render-side l var) (bracketed l var))
                        (bracketed r var)))))
    (:div (let ((l (second tree)))
            (format nil "~a / ~a"
                    (if (member (first l) '(:mul :div)) (render-side l var) (bracketed l var))
                    (bracketed (third tree) var))))))

(defun render-line (equation var)
  (format nil "~a = ~a"
          (render-side (equation-left equation) var)
          (render-side (equation-right equation) var)))
