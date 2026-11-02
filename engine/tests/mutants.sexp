;;;; Tier F mutants: (file old new). Each plants one fault, and the tests must fail. Each OLD must
;;;; occur in its file exactly once, so a mutant cannot quietly stop applying.

;;; Parsing
("parse" "(if (numberp inner) (- inner) (list 'neg inner))" "(if (numberp inner) inner (list 'neg inner))")
("parse" "(setf left (list op left (parse-term depth)))" "(setf left (list op (parse-term depth) left))")
("parse" "(when (> (length tokens) +max-tokens+)" "(when nil")
("parse" "(<= 1 exponent +max-exponent+)" "(<= 0 exponent +max-exponent+)")
("parse" "(when (member (kind) '(:var #\\())
                   (refuse \"ambiguous_division\"))" "")
("parse" "(/ top (expt 10 (length part)))" "(/ top 10)")
("parse" "(refuse (if (eql (kind) #\\=) \"chain\" \"unparsed\"))" "(refuse \"unparsed\")")
("parse" "(when (> depth +max-depth+)" "(when nil")
("parse" "(when (> (count-if #'ascii-digit-p word) +max-digits+)" "(when nil")

;;; Polynomials and roots. The PNORMAL mutant is equivalent: it flips one sign convention everywhere,
;;; which no caller can see. It stays listed so the score is not flattered by dropping it.
("poly" "(when (> (+ (bits a) (bits b)) +max-bits+)" "(when nil")
("poly" "(num (abs (reduce #'gcd (mapcar #'numerator p))))" "(num (reduce #'gcd (mapcar #'numerator p)))")
("poly" "(if (and cleared (minusp (lead cleared)))" "(if (and cleared (plusp (lead cleared)))")
("poly" "collect (* c i))))" "collect c)))")
("poly" "(pnormal (pquo p (pgcd p (pderivative p))))" "(pnormal p)")
("poly" "(rf (p+ (p* (car a) (cdr b)) (p* (car b) (cdr a))) (p* (cdr a) (cdr b)))"
        "(rf (p+ (car a) (car b)) (p* (cdr a) (cdr b)))")
("poly" "(rf (p* (car a) (cdr b)) (p* (cdr a) (car b)))" "(rf (p* (cdr a) (car b)) (p* (car a) (cdr b)))")
("poly" "(if (and (minusp direction) (oddp (degree p))) (- s) s)" "s")
("poly" "(let* ((k (1+ (floor (* low scale))))" "(let* ((k (floor (* low scale)))")
("poly" "(unless (= (length found) total)" "(unless nil")
("poly" "(sort found #'<)" "found")

;;; Meaning and verdicts
("meaning" "(when (null (car bottom))
                      (refuse \"empty_domain\"))" "")
("meaning" "(setf *zeros* (plcm *zeros* (psquarefree (car bottom))))" "nil")
("meaning" "((> (degree top) +max-degree+) (refuse \"degree_limit\"))" "")
("meaning" "(cons :finite (pnormal (pquo square-free (pgcd square-free zeros))))" "(cons :finite square-free)")
("meaning" "((eq (car a) :finite) (cons :finite (pgcd p q)))" "((eq (car a) :finite) (cons :finite p))")
("meaning" "((eq (car b) :finite) (cons :allexcept (plcm p q)))" "((eq (car b) :finite) (cons :allexcept p))")
("meaning" "(t (cons :finite (pquo q (pgcd p q))))" "(t (cons :finite q))")
("meaning" "(loop for candidate from 0" "(loop for candidate from 1")
("meaning" "(no-loss (payload :gains gained))" "(no-loss (payload :loses gained))")
("meaning" "(t (payload :unrelated lost))" "(t (payload :unrelated gained))")
("meaning" "(unless no-gain (rational-roots (cdr gained)))" "")
("meaning" "(/ (unless (zerop (second values))
         (/ (first values) (second values))))" "(/ (/ (first values) (second values)))")

;;; Using a verdict
("step" ":solved (and (eq (getf from-start :verdict) :equivalent)
                                      (solved-form-p (parse-line text var)))"
        ":solved (solved-form-p (parse-line text var))")
("step" "(string= (getf from-previous :shape) \"Finite\")" "t")
("step" "(variable-denominator-p (parse-line previous var))" "t")
("step" "(and (eq (car set) :finite) (empty-set-p set))" "(eq (car set) :allexcept)")
("step" "(and (literal-p left) (eq right :x))" "nil")

;;; Rule search
("search" "(total (unless (total-p bound) (setf state :failed)))" "(total nil)")
("search" "(nonzero-literal (when (eql (if (numberp bound) bound 0) 0) (setf state :failed)))" "(nonzero-literal nil)")
("search" "(literal (unless (numberp bound) (return :type)))" "(literal nil)")
("search" "((eql built (if (eq head '+) 0 1)) (node head rest))" "")
("search" "((and (eq (first built) '*) (eql (second built) 1) (null (cdddr built))) (third built))" "")
("search" "(as-fraction subject)))))" "nil))))")
("search" "(match pattern (list '* 1 subject) b))" "nil)")
("search" "append (list -1 (second item))" "collect item")
("search" "unless rest collect found))" "collect found))")
("search" "(when (equal start goal)
      (return-from attribute (list :state :ok :rules nil :uses nil)))" "")

;;; The flat view
("rules" "(mapcar #'cdr (sort (mapcar (lambda (term) (cons (term-key term) term)) terms)
                      #'string< :key #'car))" "terms")
("rules" ":order (equal pattern replacement)" ":order nil")

;;; Quadratics
("parse" "(push (parse-equation) equations))" "(setf equations (list (parse-equation))))")
("meaning" "((eq (car a) :finite) (cons :allexcept (pquo q (pgcd p q))))" "((eq (car a) :finite) (cons :allexcept q))")
("meaning" "((eq (car b) :finite) (cons :allexcept (pquo p (pgcd p q))))" "((eq (car b) :finite) (cons :allexcept p))")
("meaning" "(t (cons :allexcept (pgcd p q))))))" "(t (cons :allexcept p)))))")
("meaning" "(some (lambda (equation) (holds equation x)) (rest line))" "(every (lambda (equation) (holds equation x)) (rest line))")
("step" "(every #'solved-form-p (rest line))" "t")
("search" "(= (* bound (first more)) (third more))" "t")
("search" "(square-of (unless (= (* bound bound) (first more)) (setf state :failed)))" "(square-of nil)")
("rules" "(remove-duplicates (mapcan (lambda (arg) (items-of 'or arg)) (rest tree))
                                         :test #'equal)" "(mapcan (lambda (arg) (items-of 'or arg)) (rest tree))")

;;; Practice replies
("tutor" "(if (holds before x)
        (format nil \"~a = ~a solves the line before." "(if (not (holds before x))
        (format nil \"~a = ~a solves the line before.")
("tutor" "(reply \"status\" \"accepted\" \"solved\" (solved-flag result)" "(reply \"status\" \"accepted\" \"solved\" :true")
("tutor" "(reply \"status\" \"caution\" \"solved\" :false" "(reply \"status\" \"caution\" \"solved\" :true")
("tutor" "(unless (and (stringp value) (<= (length value) 256)) (error 'bad-practice))" "")
("show" "(write-string (if found (show (cdr found) var) \"it\") out)" "(write-string \"it\" out)")
