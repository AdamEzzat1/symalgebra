;;;; Complex numbers, in tasks that allow the letter i. A number is (re . im), and each part may hold a
;;;; surd, so i sqrt(3) is a number here. A line is either a number, or equations in x whose sets are
;;;; compared over the complex numbers. Elsewhere in the engine a negative under a root stays refused.

(in-package :symalgebra.engine)

(defun cx (a &optional (b 0)) (cons a b))
(defun czero-p (a) (and (eql (car a) 0) (eql (cdr a) 0)))
(defun c= (a b) (and (equal (car a) (car b)) (equal (cdr a) (cdr b))))
(defun c+ (a b) (cx (k+ (car a) (car b)) (k+ (cdr a) (cdr b))))
(defun cneg (a) (cx (kneg (car a)) (kneg (cdr a))))
(defun cscale (c a) (cx (q* c (car a)) (q* c (cdr a))))

(defun c* (a b)
  (cx (k+ (q* (car a) (car b)) (kneg (q* (cdr a) (cdr b))))
      (k+ (q* (car a) (cdr b)) (q* (cdr a) (car b)))))

(defun cnorm (a)
  (k+ (q* (car a) (car a)) (q* (cdr a) (cdr a))))

(defun c/ (a b)
  (let ((top (c* a (cx (car b) (kneg (cdr b))))) (bottom (cnorm b)))
    (cx (k/ (car top) bottom) (k/ (cdr top) bottom))))

;;; Polynomials over these numbers, lowest power first, with no zero at the top.

(defun cptrim (p)
  (let ((end (position-if-not #'czero-p p :from-end t)))
    (and end (subseq p 0 (1+ end)))))

(defun cp+ (a b)
  (cptrim (loop for i from 0 below (max (length a) (length b))
                collect (c+ (or (nth i a) (cx 0)) (or (nth i b) (cx 0))))))

(defun cp* (a b)
  (let ((out (make-list (max 0 (+ (length a) (length b) -1)) :initial-element (cx 0))))
    (loop for x in a
          for i from 0
          do (loop for y in b
                   for j from 0
                   do (setf (nth (+ i j) out) (c+ (nth (+ i j) out) (c* x y)))))
    (cptrim out)))

(defun cp-number (p)
  "The number P stands for, if it has no x."
  (cond ((null p) (cx 0))
        ((null (rest p)) (first p))))

(defun real-root-of (a)
  (let ((inner (cond ((eql (cdr a) 0) (car a)) (t (refuse "complex_root")))))
    (when (consp inner)
      (refuse "nested_radical"))
    (if (minusp inner)
        (cx 0 (rational-root (- inner)))
        (cx (rational-root inner)))))

(defun cp-of (tree)
  "TREE as a polynomial in x over the complex numbers."
  (cond ((eq tree :x) (list (cx 0) (cx 1)))
        ((eq tree :i) (list (cx 0 1)))
        ((numberp tree) (cptrim (list (cx tree))))
        (t (destructuring-bind (head a &optional b) tree
             (ecase head
               (+ (cp+ (cp-of a) (cp-of b)))
               (- (cp+ (cp-of a) (cp* (list (cx -1)) (cp-of b))))
               (neg (cp* (list (cx -1)) (cp-of a)))
               (* (cp* (cp-of a) (cp-of b)))
               (^ (let ((base (cp-of a)) (out (list (cx 1))))
                    (dotimes (n b out)
                      (setf out (cp* out base)))))
               (/ (let ((bottom (cp-number (cp-of b))))
                    (cond ((null bottom) (refuse "complex_degree"))
                          ((czero-p bottom) (refuse "empty_domain"))
                          (t (cp* (cp-of a) (list (c/ (cx 1) bottom)))))))
               (sqrt (let ((inner (cp-number (cp-of a))))
                       (unless inner (refuse "complex_root"))
                       (list (real-root-of inner))))
               (abs (let ((inner (cp-number (cp-of a))))
                      (unless inner (refuse "complex_root"))
                      (let ((size (ksquare-root (cnorm inner))))
                        (unless size (refuse "complex_root"))
                        (cptrim (list (cx size)))))))))))

(defun real-square-root (a)
  "A square root of A, which has to be a real number."
  (unless (eql (cdr a) 0)
    (refuse "complex_degree"))
  (let ((size (ksquare-root (kabs (car a)))))
    (unless size (refuse "complex_degree"))
    (if (minusp (ksign (car a))) (cx 0 size) (cx size))))

(defun quadratic-roots (c b a)
  (let* ((disc (c+ (c* b b) (cscale -4 (c* a c))))
         (root (real-square-root disc))
         (two (cscale 2 a)))
    (list (c/ (c+ (cneg b) root) two) (c/ (c+ (cneg b) (cneg root)) two))))

(defun rational-coefficients (p)
  (and (every (lambda (a) (and (rationalp (car a)) (eql (cdr a) 0))) p)
       (mapcar #'car p)))

(defun deflate (p root)
  "P divided by x - ROOT, when ROOT is a root of P."
  (let ((carry (cx 0)) (out '()))
    (dolist (a (reverse (rest p)) (nreverse (nreverse out)))
      (setf carry (c+ a (c* carry (cx root))))
      (push carry out))))

(defun complex-roots (p)
  "The roots of P, a polynomial that is not zero."
  (when (> (1- (length p)) +max-degree+)
    (refuse "degree_limit"))
  (case (length p)
    (1 nil)
    (2 (list (c/ (cneg (first p)) (second p))))
    (3 (quadratic-roots (first p) (second p) (third p)))
    (t (let* ((real (rational-coefficients p))
              (root (and real (first (rational-members (pnormal real))))))
         (unless root (refuse "complex_degree"))
         (cons (cx root) (complex-roots (deflate p root)))))))

(defun complex-before-p (a b)
  (cond ((k< (car a) (car b)) t)
        ((k< (car b) (car a)) nil)
        (t (k< (cdr a) (cdr b)))))

(defun distinct-numbers (numbers)
  (sort (remove-duplicates numbers :test #'c=) #'complex-before-p))

(defun relation-roots (relation)
  "The roots of one equation, or :ALL."
  (unless (eq (first relation) '=)
    (refuse "complex_relation"))
  (let ((p (cp+ (cp-of (second relation)) (cp* (list (cx -1)) (cp-of (third relation))))))
    (if p (complex-roots p) :all)))

(defun complex-set (line)
  (if (eq (first line) 'or)
      (let ((sets (mapcar #'relation-roots (rest line))))
        (if (member :all sets) :all (distinct-numbers (reduce #'append sets))))
      (let ((roots (relation-roots line)))
        (if (eq roots :all) :all (distinct-numbers roots)))))

(defun first-whole-beyond (set)
  (loop for n from 0
        unless (member (cx n) set :test #'c=) return (cx n)))

(defun complex-payload (name members witness)
  (list :verdict name :shape "Complex" :set members :witness witness))

(defun complex-verdict (a b)
  "The verdict on going from set A to set B. The whole plane is :ALL."
  (cond ((and (eq a :all) (eq b :all)) (list :verdict :equivalent))
        ((eq a :all) (complex-payload :loses nil (first-whole-beyond b)))
        ((eq b :all) (complex-payload :gains nil (first-whole-beyond a)))
        (t (let ((lost (set-difference a b :test #'c=)) (gained (set-difference b a :test #'c=)))
             (let ((lost (distinct-numbers lost)) (gained (distinct-numbers gained)))
               (cond ((and (null lost) (null gained)) (list :verdict :equivalent))
                     ((null lost) (complex-payload :gains gained (first gained)))
                     ((null gained) (complex-payload :loses lost (first lost)))
                     (t (complex-payload :unrelated lost (first lost)))))))))

(defun complex-line (text var)
  (let ((*imaginary* t))
    (parse-line text var)))

(defun check-complex-lines (before after &key (var #\x))
  (handler-case
      (with-fuel (complex-verdict (complex-set (complex-line before var)) (complex-set (complex-line after var))))
    (refused (r) (list :verdict :out-of-fragment :reason (refused-reason r)))))

(defun number-of (tree)
  (let ((p (cp-of tree)))
    (or (cp-number p) (refuse "complex_degree"))))

(defun number-line (text)
  (let ((*imaginary* t))
    (parse-expression-line text #\x)))

(defun check-complex-numbers (before after)
  "Two lines that are each one number: the same number, or a witness that is what the second one is."
  (handler-case
      (with-fuel
        (let ((a (number-of (number-line before))) (b (number-of (number-line after))))
          (if (c= a b)
              (list :verdict :equivalent)
              (complex-payload :unrelated nil b))))
    (refused (r) (list :verdict :out-of-fragment :reason (refused-reason r)))))

;;; Writing a number down.

(defun leading-minus-p (k)
  (if (consp k) (and (zerop (part-a k)) (minusp (part-b k))) (minusp k)))

(defun imaginary-text (im)
  (cond ((eql im 1) "i")
        ((eql im -1) "-i")
        ((and (consp im) (not (zerop (part-a im)))) (format nil "(~a)i" (rational-text im)))
        (t (format nil "~ai" (rational-text im)))))

(defun complex-text (a)
  "Exact text for a number: 3, 2i, -i, 1 + 2i, 1/2 - sqrt(3)i."
  (let ((re (car a)) (im (cdr a)))
    (cond ((eql im 0) (rational-text re))
          ((eql re 0) (imaginary-text im))
          ((leading-minus-p im) (format nil "~a - ~a" (rational-text re) (imaginary-text (kneg im))))
          (t (format nil "~a + ~a" (rational-text re) (imaginary-text im))))))

(defun complex-verdict-text (v)
  "The exact text compared byte for byte with the oracle."
  (case (getf v :verdict)
    (:equivalent "EQUIVALENT")
    (:out-of-fragment (format nil "OUT_OF_FRAGMENT ~a" (getf v :reason)))
    (t (format nil "~a Complex{~{~a~^,~}} witness=~a" (verdict-name v)
               (mapcar #'complex-text (getf v :set)) (complex-text (getf v :witness))))))

;;; Using a verdict.

(defun real-answer-p (tree)
  (answer-p tree))

(defun imaginary-term-p (tree)
  (or (eq tree :i)
      (and (consp tree)
           (case (first tree)
             (neg (imaginary-term-p (second tree)))
             (* (or (and (real-answer-p (second tree)) (eq (third tree) :i))
                    (and (imaginary-term-p (second tree)) (real-answer-p (third tree)))))
             (/ (and (imaginary-term-p (second tree)) (numberp (third tree))))))))

(defun standard-form-p (tree)
  "Is TREE written as a + bi, over one number if need be?"
  (or (real-answer-p tree)
      (imaginary-term-p tree)
      (and (consp tree)
           (case (first tree)
             ((+ -) (and (real-answer-p (second tree)) (imaginary-term-p (third tree))))
             (/ (and (standard-form-p (second tree)) (numberp (third tree))))))))

(defun complex-answer-line-p (line)
  (if (eq (first line) 'or)
      (every #'complex-answer-line-p (rest line))
      (and (eq (first line) '=)
           (or (and (eq (second line) :x) (standard-form-p (third line)))
               (and (eq (third line) :x) (standard-form-p (second line)))))))

(defun check-complex-step (line0 text number-task &key (var #\x))
  "Judge TEXT in a task that began at LINE0. A line has to keep the first line's meaning exactly."
  (let* ((verdict (if number-task
                      (check-complex-numbers line0 text)
                      (check-complex-lines line0 text :var var)))
         (kind (getf verdict :verdict)))
    (cond ((eq kind :equivalent)
           (list :status :accepted :verdict verdict
                 :solved (if number-task
                             (standard-form-p (number-line text))
                             (complex-answer-line-p (complex-line text var)))))
          ((eq kind :out-of-fragment) (list :status :out-of-fragment :verdict verdict :solved nil))
          (t (list :status :rejected :verdict verdict :solved nil)))))
