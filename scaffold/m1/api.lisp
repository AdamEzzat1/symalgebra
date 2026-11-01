;;;; Request handling for the M1 scaffold, free of sockets so the tests can call it directly.
;;;; Stateless: every reply depends only on the request and the committed problem file.

(defpackage :symalgebra.m1.api
  (:use :cl :symalgebra.m1.json :symalgebra.m1.reducer)
  (:export #:load-problems #:find-problem #:problem-list #:handle-check #:handle-hint
           #:bad-request #:+line-limit+))

(in-package :symalgebra.m1.api)

(defconstant +line-limit+ 256)

(define-condition bad-request (error) ())

(defun load-problems (path)
  (with-open-file (in path :external-format :utf-8)
    (let ((text (make-string (file-length in))))
      (parse-json (subseq text 0 (read-sequence text in))))))

(defun find-problem (problems id)
  (or (find id problems :test #'equal :key (lambda (p) (jget p "id")))
      (error 'bad-request)))

(defun problem-var (problem)
  (char (jget problem "var") 0))

(defun problem-list (problems)
  (list :obj
        (cons "v" 1)
        (cons "problems"
              (map 'vector
                   (lambda (p)
                     (list :obj
                           (cons "id" (jget p "id"))
                           (cons "var" (jget p "var"))
                           (cons "kind" (jget p "kind"))
                           (cons "start" (jget p "start"))))
                   problems))))

(defun field (request key)
  (let ((value (jget request key)))
    (unless (stringp value) (error 'bad-request))
    value))

(defun check-version (request)
  (unless (eql (jget request "v") 1) (error 'bad-request)))

(defun reply (status &rest fields)
  (list* :obj (cons "v" 1) (cons "status" status)
         (loop for (key value) on fields by #'cddr collect (cons key value))))

(defun read-line-checked (text var)
  "An equation, or a reply saying why there is none."
  (handler-case
      (if (> (length text) +line-limit+)
          (reply "unparsed" "column" (1+ +line-limit+))
          (let ((equation (parse-line text var)))
            (solution-set equation)
            equation))
    (parse-failure (e) (reply "unparsed" "column" (failure-column e)))
    (out-of-fragment () (reply "out_of_fragment"))))

(defun reply-p (value)
  (eq (first value) :obj))

(defun sides-at (equation x)
  (values (rat (value-at (equation-left equation) x))
          (rat (value-at (equation-right equation) x))))

(defun states (var x equation label)
  (multiple-value-bind (l r) (sides-at equation x)
    (format nil "If ~a = ~a, ~a says ~a = ~a." var (rat x) label l r)))

(defun witness (from to)
  "A value separating the two sets, following the table in ARCHITECTURE section 6."
  (let ((f (first from)) (g (first to)))
    (cond ((eq g :one) (if (eq f :all) (1+ (second to)) (second to)))
          ((eq f :one) (if (eq g :all) (1+ (second from)) (second from)))
          (t 0))))

(defun feedback (var previous line from to x)
  (let ((f (first from)) (g (first to)))
    (cond ((and (eq f :one) (eq g :one))
           (multiple-value-bind (l r) (sides-at previous x)
             (values (format nil "If ~a = ~a, the line before says ~a = ~a." var (rat x) l r)
                     (format nil "So ~a = ~a does not fit the line before." var (rat x)))))
          ((and (eq f :one) (eq g :none))
           (values "This line has no solution; the one before it does."
                   (states var x previous "the line before")))
          ((and (eq f :one) (eq g :all))
           (values (format nil "Every ~a works here; the one before it has one solution." var)
                   (format nil "~a ~a" (states var x line "this line")
                           (states var x previous "the line before"))))
          (t
           (values (format nil "These two lines do not agree at ~a = ~a." var (rat x))
                   (format nil "~a ~a" (states var x previous "the line before")
                           (states var x line "this line")))))))

(defun verdict (problem var previous line)
  (let ((from (solution-set previous))
        (to (solution-set line)))
    (if (equal from to)
        (let* ((start (parse-line (jget problem "start") var))
               (done (and (solved-form-p line)
                          (null (jget problem "claim"))
                          (equal to (solution-set start)))))
          (reply "checked" "verdict" "equivalent"
                 "done" (if done :true :false)
                 "echo" (render-line line var)))
        (let ((x (witness from to)))
          (multiple-value-bind (message why) (feedback var previous line from to x)
            (reply "checked" "verdict" "different"
                   "echo" (render-line line var)
                   "witness" (rat x)
                   "message" message
                   "why" why))))))

(defun check-claim (problem var claim)
  (let* ((start (parse-line (jget problem "start") var))
         (actual (first (solution-set start)))
         (name (string-downcase (symbol-name actual))))
    (unless (member claim '("none" "all") :test #'string=) (error 'bad-request))
    (if (string= claim name)
        (reply "checked" "verdict" "equivalent" "done" :true "echo" "")
        (reply "checked" "verdict" "different" "echo" ""
               "message" (if (string= claim "none")
                             (format nil "Some value of ~a does work here. Keep going." var)
                             (format nil "Not every value of ~a works here. Keep going." var))
               "why" ""))))

(defun handle-check (problems request)
  (check-version request)
  (let* ((problem (find-problem problems (field request "problem")))
         (var (problem-var problem)))
    (if (jget request "claim")
        (check-claim problem var (field request "claim"))
        (let ((previous (read-line-checked (field request "previous") var))
              (line (read-line-checked (field request "text") var)))
          (cond ((reply-p line) line)
                ((reply-p previous) (reply "not_checked"))
                (t (verdict problem var previous line)))))))

;;; Hints follow the authored path. A line off the path gets general wording, and its last
;;; level is the final line, which counts as a bottom-out like any other.

(defun side-forms (equation)
  (list (reduce-form (equation-left equation)) (reduce-form (equation-right equation))))

(defun path-index (problem var previous)
  (let ((target (side-forms previous))
        (lines (cons (jget problem "start")
                     (map 'list (lambda (s) (jget s "line")) (jget problem "steps")))))
    (position target lines :test #'equal
                           :key (lambda (line) (side-forms (parse-line line var))))))

(defun hint-text (problem index level)
  (let* ((steps (jget problem "steps"))
         (last-line (jget (aref steps (1- (length steps))) "line")))
    (cond ((and index (= index (length steps)))
           (if (jget problem "claim")
               "This line no longer has the letter. Is it ever true? Use the buttons below."
               "This line already gives the answer."))
          (index
           (let ((step (aref steps index)))
             (ecase level
               (1 (jget step "nudge"))
               (2 (jget step "op"))
               (3 (jget step "line")))))
          (t (ecase level
               (1 "Look at what is still on the same side as the letter.")
               (2 "Undo one operation at a time, and do it to both sides.")
               (3 last-line))))))

(defun handle-hint (problems request)
  (check-version request)
  (let* ((problem (find-problem problems (field request "problem")))
         (var (problem-var problem))
         (level (jget request "level")))
    (unless (member level '(1 2 3)) (error 'bad-request))
    (let ((previous (read-line-checked (field request "previous") var)))
      (reply "hint" "text"
             (hint-text problem
                        (unless (reply-p previous) (path-index problem var previous))
                        level)))))
