;;;; M0 smoke test: run with sbcl --script from the repository root.

(load "engine/src/exact.lisp")

(defvar *ran* 0)
(defvar *passed* 0)

(defun check (name passed)
  (incf *ran*)
  (cond (passed (incf *passed*))
        (t (format t "FAIL ~A~%" name))))

(check "reduces" (string= (symalgebra.exact:rat-string 2/4) "1/2"))
(check "negative" (string= (symalgebra.exact:rat-string -1/2) "-1/2"))
(check "integer" (string= (symalgebra.exact:rat-string 3) "3/1"))
(check "rejects-float"
       (handler-case (progn (symalgebra.exact:rat-string 0.5) nil)
         (type-error () t)))

(format t "COUNT lisp ran=~D passed=~D~%" *ran* *passed*)
(sb-ext:exit :code (if (= *ran* *passed*) 0 1))
