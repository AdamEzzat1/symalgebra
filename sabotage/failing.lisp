;;;; Must fail. Proves a failing Lisp check reddens the run.
(format t "FAIL deliberate~%")
(sb-ext:exit :code 1)
