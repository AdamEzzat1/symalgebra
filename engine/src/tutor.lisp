;;;; The practice page's replies. Stateless: every reply depends only on the request and the
;;;; problem file. The verdict comes from check-step, and attribution only adds words afterwards.

(in-package :symalgebra.engine)

(define-condition bad-practice (error) ())

(defparameter *practice-areas* '("distribution" "fractions"))

(defun read-json-file (path)
  (with-open-file (in path :external-format :utf-8)
    (let ((text (make-string (file-length in))))
      (parse-json (subseq text 0 (read-sequence text in))))))

(defun load-practice (&optional (path "corpus/solutions.json"))
  (remove-if-not (lambda (p) (member (jget p "area") *practice-areas* :test #'string=))
                 (coerce (read-json-file path) 'list)))

(defun line-variable (line)
  (or (find-if #'alpha-char-p line) #\x))

(defun reply (&rest fields)
  (list* :obj (cons "v" 1)
         (loop for (key value) on fields by #'cddr collect (cons key value))))

(defun practice-list (problems)
  (reply "problems"
         (map 'vector
              (lambda (p)
                (list :obj (cons "id" (jget p "id")) (cons "area" (jget p "area"))
                      (cons "start" (jget p "start"))
                      (cons "var" (string (line-variable (jget p "start"))))))
              problems)))

(defun find-practice (problems id)
  (or (and (stringp id) (find id problems :key (lambda (p) (jget p "id")) :test #'string=))
      (error 'bad-practice)))

(defun request-text (request key)
  (let ((value (jget request key)))
    (unless (and (stringp value) (<= (length value) 256)) (error 'bad-practice))
    value))

(defun says (line x)
  "What LINE, a tree, comes to at X."
  (if (eq (first line) 'or)
      "no part of it holds"
      (let ((left (value (second line) x)) (right (value (third line) x)))
        (if (and left right)
            (format nil "it says ~a = ~a" (rational-text left) (rational-text right))
            "it has no value there"))))

(defun why-text (previous text verdict var)
  "The witness in words, tested against the two lines as typed."
  (let* ((before (parse-line previous var)) (after (parse-line text var))
         (x (getf verdict :witness)) (shown (rational-text x)))
    (if (holds before x)
        (format nil "~a = ~a solves the line before. Put it into this line and ~a." var shown (says after x))
        (format nil "~a = ~a solves this line. Put it into the line before and ~a." var shown (says before x)))))

(defun explanations (previous text var)
  "Words for an accepted step, or an empty vector when no rule names it."
  (handler-case
      (let ((found (attribute (parse-line previous var) (parse-line text var))))
        (coerce (mapcar (lambda (use) (use-text use var)) (getf found :uses)) 'vector))
    (error () #())))

(defun refusal-text (reason)
  (cond ((string= reason "ambiguous_division")
         "Please add brackets: this could be read two ways, such as (1/2)x or 1/(2x).")
        ((string= reason "unparsed") "I could not read this line. Check it for a missing number or bracket.")
        (t "Not checked. This line is outside what this page covers.")))

(defun claim-text (text var)
  (if (string= text "no solution")
      (format nil "Some value of ~a does work here. Keep going." var)
      (format nil "Not every value of ~a works here. Keep going." var)))

(defun solved-flag (result)
  (if (getf result :solved) :true :false))

(defun claim-p (text)
  (member text '("no solution" "all real numbers") :test #'string=))

(defun practice-check (problems request)
  (let* ((problem (find-practice problems (jget request "problem")))
         (start (jget problem "start"))
         (var (line-variable start))
         (previous (request-text request "previous"))
         (text (request-text request "text"))
         (result (check-step start previous text :var var))
         (verdict (getf result :verdict)))
    (ecase (getf result :status)
      (:accepted
       (reply "status" "accepted" "solved" (solved-flag result)
              "explanations" (if (claim-p text) #() (explanations previous text var))))
      (:caution
       (reply "status" "caution" "solved" :false
              "explanations" (explanations previous text var)
              "message" "That can follow, but it may have added a value that fails the first line. Check it there."))
      (:rejected
       (if (claim-p text)
           (reply "status" "rejected" "solved" :false "message" (claim-text text var) "why" "")
           (reply "status" "rejected" "solved" :false
                  "message" "These two lines do not have the same solutions."
                  "why" (why-text previous text verdict var))))
      (:out-of-fragment
       (reply "status" "not_checked" "solved" :false
              "message" (refusal-text (or (getf result :reason) (getf verdict :reason) "")))))))

;;; Hints follow the authored solution. A line off that path gets general wording.

(defun path-position (problem previous var)
  (handler-case
      (let ((target (flat (parse-line previous var)))
            (lines (cons (jget problem "start")
                         (map 'list (lambda (s) (jget s "line")) (jget problem "steps")))))
        (position target lines :test #'equal :key (lambda (line) (flat (parse-line line var)))))
    (refused () nil)))

(defun step-hint (before after var)
  (let ((words (explanations before after var)))
    (if (plusp (length words))
        (format nil "~{~a~^ ~}" (coerce words 'list))
        "Work out the next simpler line.")))

(defun practice-hint (problems request)
  (let* ((problem (find-practice problems (jget request "problem")))
         (var (line-variable (jget problem "start")))
         (previous (request-text request "previous"))
         (level (jget request "level"))
         (steps (jget problem "steps"))
         (index (path-position problem previous var)))
    (unless (member level '(1 2)) (error 'bad-practice))
    (reply "text"
           (cond ((null index)
                  (if (= level 1)
                      (format nil "Look at what is still on the same side as ~a." var)
                      "Undo one operation at a time, and do it to both sides."))
                 ((= index (length steps))
                  (if (member (jget problem "answer") '("none" "all") :test #'string=)
                      "Is this ever true? Use the buttons below."
                      "This line already gives the answer."))
                 ((= level 2) (jget (aref steps index) "line"))
                 (t (step-hint previous (jget (aref steps index) "line") var))))))
