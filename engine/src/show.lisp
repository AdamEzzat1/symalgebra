;;;; Flat trees as a person writes them, for explanations. Nothing here decides anything.

(in-package :symalgebra.engine)

(defun number-text (q)
  (format nil "~a" q))

(defun bracketed (tree var)
  (if (and (consp tree) (member (first tree) '(+ / neg)))
      (format nil "(~a)" (show tree var))
      (show tree var)))

(defun signed-term (term var)
  "TERM with its sign apart, as (minusp . text)."
  (cond ((and (numberp term) (minusp term)) (cons t (number-text (- term))))
        ((and (consp term) (eq (first term) 'neg)) (cons t (bracketed (second term) var)))
        ((and (consp term) (eq (first term) '*) (numberp (second term)) (minusp (second term)))
         (cons t (show (list* '* (- (second term)) (cddr term)) var)))
        (t (cons nil (show term var)))))

(defun show-sum (terms var)
  (with-output-to-string (out)
    (loop for term in terms
          for first-p = t then nil
          do (destructuring-bind (minus . text) (signed-term term var)
               (format out "~a~a" (cond ((and first-p minus) "-") (first-p "") (minus " - ") (t " + "))
                       text)))))

(defun show-product (items var)
  (let ((literal (find-if #'numberp items)))
    (if literal
        (format nil "~a~{~a~^ * ~}" (number-text literal)
                (mapcar (lambda (item) (bracketed item var)) (remove literal items :count 1)))
        (format nil "~{~a~^ * ~}" (mapcar (lambda (item) (bracketed item var)) items)))))

(defun show (tree &optional (var #\x))
  (cond ((eq tree :x) (string var))
        ((numberp tree) (number-text tree))
        (t (destructuring-bind (head &rest args) tree
             (ecase head
               (+ (show-sum args var))
               (* (show-product args var))
               (/ (format nil "~a/~a" (bracketed (first args) var) (bracketed (second args) var)))
               (^ (format nil "~a^~a" (bracketed (first args) var) (second args)))
               (neg (format nil "-~a" (bracketed (first args) var)))
               (= (format nil "~a = ~a" (show (first args) var) (show (second args) var)))
               (or (format nil "~{~a~^ or ~}" (mapcar (lambda (arg) (show arg var)) args))))))))

(defun fill-template (template b var)
  "TEMPLATE with each {?name} replaced by what that metavariable matched."
  (with-output-to-string (out)
    (let ((i 0) (n (length template)))
      (loop while (< i n)
            do (let ((end (and (char= (char template i) #\{) (position #\} template :start i))))
                 (if end
                     (let* ((name (intern (string-upcase (subseq template (1+ i) end))
                                          :symalgebra.engine))
                            (found (binding name b)))
                       (write-string (if found (show (cdr found) var) "it") out)
                       (setf i (1+ end)))
                     (progn (write-char (char template i) out) (incf i))))))))

(defun use-text (use var)
  (fill-template (rule-field (car use) :explanation) (cdr use) var))
