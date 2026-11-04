;;;; Bounded rule search over flat states, and rperft. Rule matching explains a step. It never
;;;; decides one: the verdict is computed first, in meaning.lisp.

(in-package :symalgebra.engine)

(defconstant +search-budget+ 400)
(defconstant +subset-limit+ 8)
(defconstant +divisor-limit+ 1000)

(defun meta-p (x)
  (and (symbolp x) (not (keywordp x)) x (char= (char (symbol-name x) 0) #\?)))

(defun binding (name b)
  (assoc name b))

;;; Matching. Each function returns every way to match, as a list of binding lists.

(defun match (pattern subject b)
  (cond ((meta-p pattern)
         (let ((found (binding pattern b)))
           (cond ((null found) (list (acons pattern subject b)))
                 ((equal (cdr found) subject) (list b)))))
        ((atom pattern)
         (when (eql pattern subject) (list b)))
        ((eq (first pattern) 'neg)
         (cond ((numberp subject)
                (when (minusp subject) (match (second pattern) (- subject) b)))
               ((and (consp subject) (eq (first subject) 'neg))
                (match (second pattern) (second subject) b))
               ((and (consp subject) (eq (first subject) '*)
                     (some (lambda (item) (and (numberp item) (minusp item))) (rest subject)))
                (match (second pattern) (negated subject) b))))
        ((and (eq (first pattern) '*) (not (and (consp subject) (eq (first subject) '*))))
         ;; A term on its own counts as one of itself: x matches (* ?n ?a) with ?n = 1, -x with
         ;; ?n = -1, and a square as the product it stands for.
         (append (if (and (consp subject) (eq (first subject) 'neg))
                     (match pattern (list '* -1 (second subject)) b)
                     (match pattern (list '* 1 subject) b))
                 (when (and (consp subject) (eq (first subject) '^) (eql (third subject) 2))
                   (match pattern (list '* (second subject) (second subject)) b))))
        ((atom subject) nil)
        ((eq (first pattern) 'rel)
         ;; A rel rule covers < and <=, and every rel in one rule is the same one.
         (let ((head (cdr (binding '%rel b))))
           (when (and (member (first subject) '(< <=)) (member head (list nil (first subject))))
             (match (cons (first subject) (rest pattern)) subject (acons '%rel (first subject) b)))))
        ((not (eq (first pattern) (first subject))) nil)
        ((member (first pattern) '(+ *))
         (loop for (found . rest) in (ac-assign (rest pattern) (node-items subject) b (first pattern))
               unless rest collect found))
        ((= (length pattern) (length subject))
         (let ((results (list b)))
           (loop for p in (rest pattern)
                 for s in (rest subject)
                 do (setf results (loop for r in results append (match p s r))))
           results))))

(defun node-items (subject)
  "The items of a sum or product. In a product, -a counts as the two factors -1 and a."
  (if (eq (first subject) '*)
      (loop for item in (rest subject)
            if (and (consp item) (eq (first item) 'neg))
              append (list -1 (second item))
            else collect item)
      (rest subject)))

(defun free-meta-p (pattern b)
  (and (meta-p pattern) (not (binding pattern b))))

(defun subsets (items)
  "Every nonempty sublist of ITEMS, or only single items when there are too many to try."
  (if (> (length items) +subset-limit+)
      (mapcar #'list items)
      (loop for mask from 1 below (ash 1 (length items))
            collect (loop for item in items
                          for i from 0
                          when (logbitp i mask) collect item))))

(defun without (chosen items)
  (let ((rest (copy-list items)))
    (dolist (item chosen rest)
      (setf rest (remove item rest :count 1 :test #'eql)))))

(defun consume (wanted items)
  "ITEMS without each of WANTED, or :MISSING if one is not there."
  (let ((rest (copy-list items)))
    (dolist (item wanted rest)
      (let ((found (member item rest :test #'equal)))
        (unless found (return :missing))
        (setf rest (remove (car found) rest :count 1 :test #'eql))))))

(defun ac-assign (patterns items b head)
  "Every way to give PATTERNS items from a sum or product, each with the leftover items."
  (tick)
  (if (null patterns)
      (list (cons b items))
      (let ((pattern (or (find-if-not (lambda (p) (free-meta-p p b)) patterns) (first patterns))))
        (when (and (meta-p pattern) (not (free-meta-p pattern b)))
          ;; A bound sum was spliced into this one by flattening, so its items are here separately.
          (let ((value (cdr (binding pattern b))))
            (when (and (consp value) (eq (first value) head))
              (let ((rest (consume (rest value) items)))
                (return-from ac-assign
                  (unless (eq rest :missing)
                    (ac-assign (remove pattern patterns :count 1 :test #'eq) rest b head)))))))
        (if (free-meta-p pattern b)
            (loop for chosen in (subsets items)
                  append (ac-assign (remove pattern patterns :count 1 :test #'eq)
                                    (without chosen items)
                                    (acons pattern (node head chosen) b)
                                    head))
            (loop for item in items
                  append (loop for found in (match pattern item b)
                               append (ac-assign (remove pattern patterns :count 1 :test #'eq)
                                                 (without (list item) items)
                                                 found
                                                 head)))))))

;;; Guards, from the closed list in docs/RULE-FORMAT.md.

(defun has-variable-p (tree)
  (cond ((eq tree :x) t)
        ((atom tree) nil)
        (t (some #'has-variable-p (rest tree)))))

(defun total-p (tree)
  "TREE has a value everywhere: every denominator in it is a nonzero number."
  (cond ((atom tree) t)
        ((eq (first tree) '^) (total-p (second tree)))
        ((and (eq (first tree) '/)
              (or (has-variable-p (third tree))
                  (member (value (third tree) 0) '(nil 0))))
         nil)
        (t (every #'total-p (rest tree)))))

(defun guard-state (rule b)
  ":ok, :type when a type guard fails, so no edge exists, or :failed for a semantic guard."
  (let ((state :ok))
    (dolist (guard (rule-field rule :guards) state)
      (destructuring-bind (name target &rest others) guard
        (let ((bound (cdr (binding target b)))
              (more (mapcar (lambda (other) (cdr (binding other b))) others)))
          (ecase name
            (literal (unless (numberp bound) (return :type)))
            (positive-literal (unless (and (numberp bound) (plusp bound)) (return :type)))
            (positive-number (cond ((not (numberp bound)) (return :type))
                                   ((<= bound 0) (setf state :failed))))
            (negative-number (cond ((not (numberp bound)) (return :type))
                                   ((>= bound 0) (setf state :failed))))
            (real-discriminant (when (minusp (- (* (first more) (first more)) (* 4 bound (second more))))
                                 (return :type)))
            (nonzero-literal (when (eql (if (numberp bound) bound 0) 0) (setf state :failed)))
            (total (unless (total-p bound) (setf state :failed)))
            (factors (unless (and (= (+ bound (first more)) (second more))
                                  (= (* bound (first more)) (third more)))
                       (setf state :failed)))
            (square-of (unless (= (* bound bound) (first more)) (setf state :failed)))
            (cube-of (unless (= (* bound bound bound) (first more)) (setf state :failed)))
            (half-square (unless (= (* (/ bound 2) (/ bound 2)) (first more)) (setf state :failed)))
            (split-root (destructuring-bind (k p) more
                          (unless (and (integerp bound) (plusp bound) (integerp k) (> k 1)
                                       (= (* bound bound k) p))
                            (setf state :failed))))
            (splits (destructuring-bind (q a b c) more
                      (unless (and (plusp bound) (/= q 0) (integerp (/ a bound)) (integerp (/ c q))
                                   (= (+ (* bound (/ c q)) (* q (/ a bound))) b))
                        (setf state :failed))))
            (common-factor (unless (and (integerp bound) (> bound 1)
                                        (every (lambda (m) (integerp (/ m bound))) more))
                             (setf state :failed)))))))))

;;; Building the result of a match.

(defun calculate (tree)
  (cond ((numberp tree) tree)
        ((atom tree) (throw 'no-edge nil))
        (t (let ((args (mapcar #'calculate (rest tree))))
             (ecase (first tree)
               (+ (reduce #'+ args))
               (- (reduce #'- args))
               (* (reduce #'* args))
               (neg (- (first args)))
               (/ (if (zerop (second args)) (throw 'no-edge nil) (/ (first args) (second args)))))))))

(defun literal-node (q)
  (if (integerp q) q (list '/ (numerator q) (denominator q))))

(defun instantiate (tree b)
  (cond ((meta-p tree) (cdr (binding tree b)))
        ((atom tree) tree)
        ((eq (first tree) 'eval) (literal-node (calculate (instantiate (second tree) b))))
        (t (let ((built (cons (if (eq (first tree) 'rel) (cdr (binding '%rel b)) (first tree))
                              (mapcar (lambda (item) (instantiate item b)) (rest tree)))))
             ;; A number worked out here may be 1, and nobody writes 1x.
             (if (find 'eval (remove-if-not #'consp (rest tree)) :key #'first) (tidy built) built)))))

(defun subterms (tree)
  (if (atom tree)
      (list tree)
      (cons tree (loop for item in (rest tree)
                       unless (and (numberp item) (eq (first tree) '^))
                         append (subterms item)))))

(defun denominators-of (tree)
  (remove-if-not #'identity
                 (mapcar (lambda (term) (and (consp term) (eq (first term) '/) (third term)))
                         (subterms tree))))

(defun side-terms (side)
  (mapcar (lambda (term)
            (cond ((numberp term) (abs term))
                  ((and (consp term) (eq (first term) 'neg)) (second term))
                  (t term)))
          (if (and (consp side) (eq (first side) '+)) (rest side) (list side))))

(defun divisors-of (n)
  "Each integer dividing N, with both signs, for the small N a line can hold."
  (when (and (integerp n) (< 0 (abs n) +divisor-limit+))
    (loop for d from 1 to (abs n)
          when (zerop (mod n d)) append (list d (- d)))))

(defun source-values (line target)
  "The closed parameter sources, read from the line and, when explaining a step, its target."
  (let* ((numbers (remove-duplicates (mapcar #'abs (remove-if-not #'numberp (subterms line)))))
         (denominators (remove-duplicates (denominators-of line) :test #'equal))
         (integers (remove-if-not #'integerp denominators))
         (extra (and target (remove-duplicates (subterms target) :test #'equal))))
    (list 'term (remove-duplicates (append (side-terms (second line)) (side-terms (third line)) extra)
                                   :test #'equal)
          'coefficient (remove-duplicates (append numbers extra) :test #'equal)
          'pair (remove-duplicates (mapcan #'divisors-of (copy-list numbers)))
          'lcd (remove-duplicates
                (append (and integers (list (reduce #'lcm (mapcar #'abs (remove 0 integers)) :initial-value 1)))
                        (remove-if #'numberp denominators)
                        extra)
                :test #'equal))))

(defun with-parameters (rule b sources)
  (let ((results (list b)))
    (dolist (param (rule-field rule :params) results)
      (destructuring-bind (name source) param
        (setf results (loop for r in results
                            append (mapcar (lambda (v) (acons name v r)) (getf sources source))))))))

(defun as-fraction (subject)
  "A product holding a fraction, read as one fraction: (x/3) * 6 as (x * 6)/3."
  (let ((fraction (and (consp subject) (eq (first subject) '*)
                       (find-if (lambda (item) (and (consp item) (eq (first item) '/))) (rest subject)))))
    (when fraction
      (list '/ (flat (cons '* (cons (second fraction) (without (list fraction) (rest subject)))))
            (third fraction)))))

(defun literal-factor (side)
  (cond ((integerp side) side)
        ((and (consp side) (eq (first side) '*)) (find-if #'integerp (rest side)))))

(defun divided-factor (side factor common)
  (if (integerp side)
      (list '* (/ side common) common)
      (cons '* (list* (/ factor common) common (without (list factor) (rest side))))))

(defun with-common-factor (fraction)
  "FRACTION with the literals' common factor made visible: 6/4 as (3 * 2)/(2 * 2)."
  (let* ((top (literal-factor (second fraction)))
         (bottom (literal-factor (third fraction)))
         (common (if (and top bottom (/= top 0) (/= bottom 0)) (gcd top bottom) 1)))
    (when (> common 1)
      (list '/ (divided-factor (second fraction) top common)
            (divided-factor (third fraction) bottom common)))))

(defun subject-views (rule subject)
  "The ways a cancelling rule may read SUBJECT. Every other rule reads it as it stands."
  (let ((pattern (rule-pattern rule)))
    (if (and (eq (first pattern) '/) (consp (second pattern)) (eq (first (second pattern)) '*))
        (let ((fractions (remove nil (list (and (consp subject) (eq (first subject) '/) subject)
                                           (as-fraction subject)))))
          (append fractions (remove nil (mapcar #'with-common-factor fractions))))
        (list subject))))

(defun tidy (built)
  "The written form of a result: 1x is x, -1x is -x, a/1 is a."
  (cond ((atom built) built)
        ((and (eq (first built) '*) (eql (second built) 1) (null (cdddr built))) (third built))
        ((and (eq (first built) '*) (eql (second built) -1) (null (cdddr built))) (list 'neg (third built)))
        ((and (eq (first built) '/) (eql (third built) 1)) (second built))
        (t built)))

(defun placed (head built rest)
  "BUILT back among the REST of a sum or product. A 0 in a sum or a 1 in a product disappears."
  (cond ((null rest) built)
        ((eql built (if (eq head '+) 0 1)) (node head rest))
        (t (list* head built rest))))

(defun matches-at (rule subject)
  (let* ((pattern (rule-pattern rule)) (head (first pattern)))
    (cond ((atom subject) nil)
          ((not (member head (list (first subject) 'rel))) nil)
          ((member head '(+ *)) (ac-assign (rest pattern) (node-items subject) nil head))
          (t (mapcar #'list (match pattern subject nil))))))

(defun results-at (rule subject sources failed-guards)
  "Each (new-subject state bindings) the rule gives when applied at SUBJECT."
  (let ((head (first (rule-pattern rule))))
    (loop for view in (subject-views rule subject)
          append (loop for (found . rest) in (matches-at rule view)
                       append (loop for b in (with-parameters rule found sources)
                                    for state = (guard-state rule b)
                                    when (or (eq state :ok) (and failed-guards (eq state :failed)))
                                      append (catch 'no-edge
                                               (let ((built (tidy (instantiate (rule-replacement rule) b))))
                                                 (list (list (placed head built rest) state b)))))))))

(defun results-within (rule subject sources failed-guards)
  "RESULTS-AT for SUBJECT and every position inside it."
  (when (consp subject)
    (append (and (not (eq (first subject) '=)) (results-at rule subject sources failed-guards))
            (loop for tail on (rest subject)
                  for index from 1
                  when (consp (car tail))
                    append (loop for (inner state b) in (results-within rule (car tail) sources failed-guards)
                                 collect (let ((copy (copy-list subject)))
                                           (setf (nth index copy) inner)
                                           (list copy state b)))))))

(defun alternative-edges (line rules target failed-guards)
  "Each edge of one alternative, with the other alternatives kept beside it."
  (loop for item in (rest line)
        for others = (remove item (rest line) :test #'equal)
        append (loop for (rule new state b) in (edges item rules :target target
                                                                 :failed-guards failed-guards)
                     collect (list rule (flat (list* 'or new others)) state b))))

(defun same-parameters-p (rule b c)
  (every (lambda (param) (equal (cdr (binding (first param) b)) (cdr (binding (first param) c))))
         (rule-field rule :params)))

(defun range-edges (line rules target failed-guards)
  "A rule that works on an expression changes one part of a range. A rule with a number to apply, such
as taking 1 from both sides, changes every part at once, by the same number."
  (destructuring-bind (first-part second-part) (rest line)
    (flet ((steps (part)
             (edges part rules :target target :failed-guards failed-guards))
           (range (a b)
             (flat (list 'and a b))))
      (let ((second-steps (steps second-part)))
        (append
         (loop for (rule new state b) in (steps first-part)
               if (eq (rule-field rule :level) 'expr)
                 collect (list rule (range new second-part) state b)
               else if (rule-field rule :params)
                 append (loop for (other other-new nil other-b) in second-steps
                              when (and (eq rule other) (same-parameters-p rule b other-b))
                                collect (list rule (range new other-new) state b)))
         (loop for (rule new state b) in second-steps
               when (eq (rule-field rule :level) 'expr)
                 collect (list rule (range first-part new) state b)))))))

(defun edges (line rules &key target failed-guards)
  "Every (rule new-line state bindings) from the flat LINE, without rules that leave it unmoved."
  (when (eq (first line) 'or)
    (return-from edges (alternative-edges line rules target failed-guards)))
  (when (eq (first line) 'and)
    (return-from edges (range-edges line rules target failed-guards)))
  (let ((sources (source-values line target))
        (seen (make-hash-table :test #'equal))
        (out '()))
    (dolist (rule rules (nreverse out))
      (unless (getf rule :order)
        (loop for (built state b) in (if (eq (rule-field rule :level) 'equation)
                                         (results-at rule line sources failed-guards)
                                         (results-within rule line sources failed-guards))
              do (let* ((new (flat built)) (key (cons (rule-id rule) new)))
                   (unless (or (equal new line) (gethash key seen))
                     (setf (gethash key seen) t)
                     (push (list rule new state b) out))))))))

(defun rule-reaches-p (rule before after &key failed-guards (var #\x))
  (let ((start (flat (parse-line before var))) (goal (flat (parse-line after var))))
    (if (getf rule :order)
        (equal start goal)
        (with-fuel
          (some (lambda (edge) (equal (second edge) goal))
                (edges start (list rule) :target goal :failed-guards failed-guards))))))

;;; Attribution. A truncated search is `unavailable`, never "method unnamed".

(defun changed-part (start goal)
  "The one alternative that differs between two `or` lines, as two values, or the lines themselves."
  (let ((old (and (eq (first start) 'or) (eq (first goal) 'or)
                  (set-difference (rest start) (rest goal) :test #'equal)))
        (new (and (eq (first start) 'or) (eq (first goal) 'or)
                  (set-difference (rest goal) (rest start) :test #'equal))))
    (if (and old new (null (rest old)) (null (rest new)))
        (values (first old) (first new))
        (values start goal))))

(defun attribute (before after &key (depth 2) (rules *rules*) (budget +search-budget+))
  "Breadth-first search from the tree BEFORE to the tree AFTER.
Returns (:state :ok :rules ids :uses ((rule . bindings) ...)), (:state :none) or
(:state :unavailable). A step that changes one alternative searches only that alternative, because
the width of the search grows with every alternative beside it."
  (multiple-value-bind (start goal) (changed-part (flat before) (flat after))
    (search-rules start goal depth rules budget)))

(defun search-rules (start goal depth rules budget)
  (let* ((seen (make-hash-table :test #'equal))
         (frontier (list (cons start nil)))
         (expanded 0))
    (when (equal start goal)
      (return-from search-rules (list :state :ok :rules nil :uses nil)))
    (setf (gethash start seen) t)
    (handler-case
        (with-fuel
          (dotimes (level depth (list :state :none))
            (let ((next '()))
              (dolist (entry frontier)
                (when (>= expanded budget)
                  (return-from search-rules (list :state :unavailable)))
                (incf expanded)
                (dolist (edge (edges (car entry) rules :target goal))
                  (destructuring-bind (rule new state b) edge
                    (declare (ignore state))
                    (let ((path (cons (cons rule b) (cdr entry))))
                      (when (equal new goal)
                        (let ((uses (reverse path)))
                          (return-from search-rules
                            (list :state :ok :rules (mapcar (lambda (use) (rule-id (car use))) uses)
                                  :uses uses))))
                      (unless (gethash new seen)
                        (setf (gethash new seen) t)
                        (push (cons new path) next))))))
              (setf frontier (nreverse next)))))
      (refused () (list :state :unavailable)))))

(defun labels-describe-p (before after names var)
  "Do the corpus's rule NAMES, and only those, carry BEFORE to AFTER?"
  (let* ((a (read-tree before var)) (b (read-tree after var))
         (rules (remove-if (lambda (rule) (getf rule :order))
                           (mapcar #'find-rule names))))
    (eq (getf (attribute a b :depth 6 :rules rules :budget 4000) :state) :ok)))

;;; rperft: path count, distinct states and a digest, for one ruleset and depth.
;;; The counts are versioned regression values, not truth.

(defun state-text (flat-tree)
  (cond ((eq flat-tree :x) "x")
        ((atom flat-tree) (format nil "~a" flat-tree))
        (t (format nil "(~a~{ ~a~})" (string-downcase (symbol-name (first flat-tree)))
                   (mapcar #'state-text (rest flat-tree))))))

(defun fnv-digest (strings)
  (let ((hash #xcbf29ce484222325))
    (dolist (s strings)
      (loop for c across s
            do (setf hash (logand (* (logxor hash (char-code c)) #x100000001b3)
                                  #xffffffffffffffff)))
      (setf hash (logand (* (logxor hash 10) #x100000001b3) #xffffffffffffffff)))
    (format nil "~16,'0x" hash)))

(defun rperft (line rules depth)
  "Paths and distinct states from the tree LINE, and every edge walked."
  (let ((memo (make-hash-table :test #'equal))
        (states (make-hash-table :test #'equal))
        (edge-list (make-hash-table :test #'equal)))
    (labels ((walk (state remaining)
               (setf (gethash (state-text state) states) t)
               (if (zerop remaining)
                   1
                   (let ((key (cons remaining state)))
                     (or (gethash key memo)
                         (setf (gethash key memo)
                               (let ((*fuel* +verdict-fuel+) (total 0))
                                 (dolist (edge (edges state rules) total)
                                   (destructuring-bind (rule new kind b) edge
                                     (declare (ignore kind b))
                                     (setf (gethash (list (rule-id rule) state new) edge-list) rule)
                                     (incf total (walk new (1- remaining))))))))))))
      (let* ((paths (walk (flat line) depth))
             (names (sort (loop for k being the hash-keys of states collect k) #'string<)))
        (list :paths paths :states (length names) :digest (fnv-digest names)
              :edges (loop for k being the hash-keys of edge-list using (hash-value rule)
                           collect (list rule (second k) (third k))))))))
