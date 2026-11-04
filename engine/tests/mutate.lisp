;;;; Tier F mutation score: sbcl --script engine/tests/mutate.lisp, inside the image.
;;;; Each mutant is one fault in a copy of the source. A mutant survives if every test still passes.
;;;; MUTATION_JOBS copies run at once, each with its own source; a test run stops at its first failure.

(defparameter *names* (mapcar #'pathname-name (directory "engine/src/*.lisp")))
(defparameter *jobs* (parse-integer (or (sb-ext:posix-getenv "MUTATION_JOBS") "4")))
(defparameter *time-limit* "300")

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

(defun copy-dir (job)
  (format nil "mutant-src-~d/" job))

(defun copy-source (dir)
  (ensure-directories-exist dir)
  (dolist (name *names*)
    (spit (source-file dir name) (slurp (source-file "engine/src/" name)))))

(defun start-tests (dir)
  (sb-ext:run-program
   "timeout"
   (list *time-limit* (namestring sb-ext:*runtime-pathname*) "--script" "engine/tests/run.lisp")
   :search t :output nil :error nil :wait nil
   :environment (list* "ENGINE_QUIET=1" "ENGINE_STOP=1" (concatenate 'string "ENGINE_SRC=" dir)
                       (sb-ext:posix-environ))))

(defun passed-p (process)
  (sb-ext:process-wait process)
  (zerop (sb-ext:process-exit-code process)))

(defun read-mutants ()
  (with-open-file (in "engine/tests/mutants.sexp" :external-format :utf-8)
    (loop for form = (read in nil :end)
          until (eq form :end)
          collect form)))

(defun check-applies (mutant)
  (destructuring-bind (name old new) mutant
    (declare (ignore new))
    (let ((found (occurrences old (slurp (source-file "engine/src/" name)))))
      (unless (= found 1)
        (format t "MUTANT DID NOT APPLY (~d matches): ~a~%" found old)
        (sb-ext:exit :code 1 :abort t)))))

(defun start-mutant (mutant dir)
  (destructuring-bind (name old new) mutant
    (spit (source-file dir name) (replaced old new (slurp (source-file "engine/src/" name))))
    (start-tests dir)))

(defun restore (mutant dir)
  (let ((name (first mutant)))
    (spit (source-file dir name) (slurp (source-file "engine/src/" name)))))

(defun survivors (mutants)
  "Each mutant paired with T when every test passed on it. Up to *JOBS* run at once."
  (let ((pending (loop for m in mutants for i from 0 collect (cons i m)))
        (free (loop for job below *jobs* collect (copy-dir job)))
        (running '())
        (results (make-array (length mutants))))
    (loop while (or pending running)
          do (loop while (and pending free)
                   do (destructuring-bind (index . mutant) (pop pending)
                        (let ((dir (pop free)))
                          (push (list (start-mutant mutant dir) dir index mutant) running))))
             (let ((done (find-if-not (lambda (run) (sb-ext:process-alive-p (first run))) running)))
               (if done
                   (destructuring-bind (process dir index mutant) done
                     (setf (aref results index) (passed-p process))
                     (restore mutant dir)
                     (setf running (remove done running))
                     (push dir free))
                   (sleep 1/5))))
    (map 'list #'cons mutants results)))

(let ((mutants (read-mutants)))
  (mapc #'check-applies mutants)
  (dotimes (job *jobs*) (copy-source (copy-dir job)))
  (unless (passed-p (start-tests (copy-dir 0)))
    (format t "BASELINE FAILS: the unmutated copy must pass~%")
    (sb-ext:exit :code 1 :abort t))
  (let ((outcome (survivors mutants)))
    (loop for (mutant . survived) in outcome
          when survived
            do (format t "SURVIVED ~a: ~a~%" (first mutant) (remove #\Newline (second mutant))))
    (format t "COUNT mutation ran=~d passed=~d~%" (length mutants) (count nil outcome :key #'cdr))
    (sb-ext:exit :code 0 :abort t)))
