;;;; M1 scaffold tests: sbcl --script scaffold/m1/tests/run.lisp
;;;; Every fixture and authored line runs here and again in the SymPy checker.

(defvar *here* (directory-namestring *load-truename*))
(defun from-here (name) (concatenate 'string *here* name))

(load (from-here "../json.lisp"))
(load (from-here "../reducer.lisp"))
(load (from-here "../api.lisp"))
(let ((patch (sb-ext:posix-getenv "M1_SABOTAGE")))
  (when patch (handler-bind ((warning #'muffle-warning)) (load patch))))

(defpackage :symalgebra.m1.tests
  (:use :cl :symalgebra.m1.json :symalgebra.m1.reducer :symalgebra.m1.api))

(in-package :symalgebra.m1.tests)

(defvar *ran* 0)
(defvar *passed* 0)

(defun check (name ok)
  (incf *ran*)
  (if ok
      (incf *passed*)
      (format t "FAIL ~a~%" name)))

(defun safely (name thunk)
  (handler-case (funcall thunk)
    (error (e) (format t "ERROR ~a: ~a~%" name e) nil)))

(defvar *problems* (load-problems (cl-user::from-here "../problems.json")))

(defun read-json-file (path) (load-problems path))

(defun check-request (fixture)
  (list :obj (cons "v" 1)
        (cons "problem" (jget fixture "problem"))
        (cons "previous" (jget fixture "previous"))
        (cons "text" (jget fixture "text"))))

(defun fixture-holds (fixture)
  (let* ((answer (handle-check *problems* (check-request fixture)))
         (expect (jget fixture "expect"))
         (status (jget answer "status")))
    (cond ((member expect '("equivalent" "different") :test #'string=)
           (and (string= status "checked")
                (string= (jget answer "verdict") expect)
                (or (null (jget fixture "witness"))
                    (string= (jget answer "witness") (jget fixture "witness")))))
          ((string= expect "unparsed")
           (and (string= status "unparsed")
                (eql (jget answer "column") (jget fixture "column"))))
          (t (string= status expect)))))

(defun run-fixtures ()
  (loop for fixture across (read-json-file (cl-user::from-here "fixtures.json")) do
    (let ((fixture fixture))
      (check (jget fixture "name")
             (safely (jget fixture "name") (lambda () (fixture-holds fixture)))))))

(defun lines-of (problem)
  (cons (jget problem "start") (map 'list (lambda (s) (jget s "line")) (jget problem "steps"))))

(defun authored-chain-holds (problem)
  (let ((var (char (jget problem "var") 0))
        (lines (lines-of problem)))
    (and (loop for line in lines
               always (solution-set (parse-line line var)))
         (loop for (a b) on lines
               while b
               always (equal (solution-set (parse-line a var))
                             (solution-set (parse-line b var)))))))

(defun finish-holds (problem)
  (let* ((lines (lines-of problem))
         (final (first (last lines)))
         (previous (first (last lines 2)))
         (request (list :obj (cons "v" 1) (cons "problem" (jget problem "id"))
                        (cons "previous" previous)))
         (claim (jget problem "claim")))
    (string= "true"
             (write-json
              (jget (handle-check *problems*
                                  (append request
                                          (if claim
                                              (list (cons "claim" claim))
                                              (list (cons "text" final)))))
                    "done")))))

(defun run-problems ()
  (check "24 problems" (= 24 (length *problems*)))
  (check "15 multi-operation"
         (= 15 (count "multi" *problems* :test #'string= :key (lambda (p) (jget p "kind")))))
  (loop for problem across *problems* do
    (let ((problem problem) (id (jget problem "id")))
      (check (format nil "~a chain" id)
             (safely id (lambda () (authored-chain-holds problem))))
      (check (format nil "~a finishes" id)
             (safely id (lambda () (finish-holds problem)))))))

(defun hint-is (id previous level expected)
  (string= expected
           (jget (handle-hint *problems*
                              (list :obj (cons "v" 1) (cons "problem" id)
                                    (cons "previous" previous) (cons "level" level)))
                 "text")))

(defun rejects (thunk)
  (handler-case (progn (funcall thunk) nil)
    (bad-request () t)))

;;; The echo becomes the next `previous` line, so it has to mean what was typed.
(defun echo-keeps-meaning (line)
  (let* ((typed (parse-line line #\x))
         (echoed (parse-line (render-line typed #\x) #\x)))
    (equal (difference-form typed) (difference-form echoed))))

(defun run-echo ()
  (dolist (line '("1/(2*3) = x" "x/0.5 = 1" "x/(2/3) = 1" "x/(-2) = 1" "1/(2+3) = x" "6/(4-2)/3 = x"
                  "5 - (x - 2) = 1" "5 - (2 - (x - 1)) = 1" "-(x + 1) = 2" "-(-x) = 2" "2(x + 1) = 4"
                  "(x + 1)/2 = 4" "2*x/3 = 1" "2/3x = 1" "0.5x = 1" "-0.5x = 1"
                  "(1/2)(x + 1) = 3" "x*2*3 = 6" "2*(3*x) = 6" "(x/2)/3 = 1" "-2x = 4" "3 + -2 = x"))
    (let ((line line))
      (check (format nil "echo keeps ~a" line)
             (safely line (lambda () (echo-keeps-meaning line))))))
  (loop for fixture across (read-json-file (cl-user::from-here "fixtures.json"))
        when (member (jget fixture "expect") '("equivalent" "different") :test #'string=)
          do (let ((text (jget fixture "text")))
               (check (format nil "echo keeps ~a" text)
                      (safely text (lambda () (echo-keeps-meaning text)))))))

(defun run-api ()
  (check "next line from the start" (hint-is "lin-10" "2x + 5 = 17" 3 "2x = 12"))
  (check "reordered line stays on the path" (hint-is "lin-10" "5 + 2x = 17" 2 "Subtract 5 from both sides."))
  (check "off-path line gets general wording"
         (hint-is "lin-10" "4x + 10 = 34" 2 "Undo one operation at a time, and do it to both sides."))
  (check "off-path bottom-out is the final line" (hint-is "lin-10" "4x + 10 = 34" 3 "x = 6"))
  (check "unknown problem" (rejects (lambda () (handle-check *problems* (list :obj (cons "v" 1) (cons "problem" "nope") (cons "previous" "") (cons "text" ""))))))
  (check "unknown version" (rejects (lambda () (handle-check *problems* (list :obj (cons "v" 2))))))
  (check "line over the limit"
         (let ((answer (handle-check *problems*
                                     (list :obj (cons "v" 1) (cons "problem" "lin-10")
                                           (cons "previous" "x = 1")
                                           (cons "text" (make-string 257 :initial-element #\1))))))
           (string= (jget answer "status") "unparsed")))
  (check "out-of-fragment previous line is not judged"
         (let ((answer (handle-check *problems*
                                     (list :obj (cons "v" 1) (cons "problem" "lin-10")
                                           (cons "previous" "1/x = 1") (cons "text" "x = 1")))))
           (string= (jget answer "status") "not_checked")))
  (check "echo shows how 2/3x was read"
         (string= (render-line (parse-line "2/3x = 1" #\x) #\x) "(2 / 3) * x = 1"))
  (check "wrong claim gives no verdict of done"
         (null (jget (handle-check *problems*
                                   (list :obj (cons "v" 1) (cons "problem" "lin-10")
                                         (cons "claim" "none")))
                     "done"))))

(run-fixtures)
(run-problems)
(run-echo)
(run-api)
(format t "COUNT m1 ran=~d passed=~d~%" *ran* *passed*)
(sb-ext:exit :code (if (= *ran* *passed*) 0 1) :abort t)
