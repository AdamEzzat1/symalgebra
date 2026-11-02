;;;; Tier F mutation score: sbcl --script engine/tests/mutate.lisp, inside the image.
;;;; Each mutant is one fault in a copy of the source. A mutant survives if every test still passes.

(defparameter *names* '("exact" "json" "load" "parse" "poly" "meaning" "rules" "search" "step" "show" "tutor"))
(defparameter *copy* "mutant-src/")
(defparameter *time-limit* "120")

(defun slurp (path)
  (with-open-file (in path :external-format :utf-8)
    (let ((text (make-string (file-length in))))
      (subseq text 0 (read-sequence text in)))))

(defun spit (path text)
  (with-open-file (out path :direction :output :if-exists :supersede :external-format :utf-8)
    (write-string text out)))

(defun occurrences (old text)
  (loop with start = 0
        for at = (search old text :start2 start)
        while at
        count t
        do (setf start (1+ at))))

(defun replaced (old new text)
  (let ((at (search old text)))
    (concatenate 'string (subseq text 0 at) new (subseq text (+ at (length old))))))

(defun source-file (dir name)
  (concatenate 'string dir name ".lisp"))

(defun copy-source ()
  (ensure-directories-exist *copy*)
  (dolist (name *names*)
    (spit (source-file *copy* name) (slurp (source-file "engine/src/" name)))))

(defun tests-pass-p ()
  (let ((process (sb-ext:run-program
                  "timeout"
                  (list *time-limit* (namestring sb-ext:*runtime-pathname*) "--script" "engine/tests/run.lisp")
                  :search t :output nil :error nil
                  :environment (list* "ENGINE_QUIET=1" (concatenate 'string "ENGINE_SRC=" *copy*)
                                      (sb-ext:posix-environ)))))
    (zerop (sb-ext:process-exit-code process))))

(defun read-mutants ()
  (with-open-file (in "engine/tests/mutants.sexp" :external-format :utf-8)
    (loop for form = (read in nil :end)
          until (eq form :end)
          collect form)))

(defun run-mutant (mutant)
  (destructuring-bind (name old new) mutant
    (let* ((original (slurp (source-file "engine/src/" name)))
           (found (occurrences old original)))
      (unless (= found 1)
        (format t "MUTANT DID NOT APPLY (~d matches): ~a~%" found old)
        (sb-ext:exit :code 1 :abort t))
      (spit (source-file *copy* name) (replaced old new original))
      (prog1 (not (tests-pass-p))
        (spit (source-file *copy* name) original)))))

(let ((mutants (read-mutants)) (killed 0))
  (copy-source)
  (unless (tests-pass-p)
    (format t "BASELINE FAILS: the unmutated copy must pass~%")
    (sb-ext:exit :code 1 :abort t))
  (dolist (mutant mutants)
    (if (run-mutant mutant)
        (incf killed)
        (format t "SURVIVED ~a: ~a~%" (first mutant) (remove #\Newline (second mutant)))))
  (format t "COUNT mutation ran=~d passed=~d~%" (length mutants) killed)
  (sb-ext:exit :code 0 :abort t))
