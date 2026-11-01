;;;; Step-check latency on the corpus: sbcl --script engine/tests/bench.lisp
;;;; Verdict and explanation are reported apart, and the verdict alone answers the 100 ms target.
;;;; Times are integer microseconds, so no float enters even here.

(handler-bind ((warning #'muffle-warning))
  (load "engine/src/load.lisp"))

(in-package :symalgebra.engine)

(defun read-json (path)
  (with-open-file (in path :external-format :utf-8)
    (let ((text (make-string (file-length in))))
      (parse-json (subseq text 0 (read-sequence text in))))))

(defun now ()
  (multiple-value-bind (seconds microseconds) (sb-ext:get-time-of-day)
    (+ (* seconds 1000000) microseconds)))

(defun microseconds (thunk)
  (let ((start (now)))
    (funcall thunk)
    (- (now) start)))

(defun percentile (sorted share)
  (nth (min (1- (length sorted)) (floor (* share (length sorted)) 100)) sorted))

(defun report (name times)
  (let ((sorted (sort (copy-list times) #'<)))
    (format t "~a: n=~d p50=~dus p95=~dus p99=~dus max=~dus~%" name (length sorted)
            (percentile sorted 50) (percentile sorted 95) (percentile sorted 99) (first (last sorted)))))

(defun corpus-steps ()
  (loop for solution across (read-json "corpus/solutions.json")
        for start = (jget solution "start")
        for var = (or (find-if #'alpha-char-p start) #\x)
        for lines = (cons start (map 'list (lambda (s) (jget s "line")) (jget solution "steps")))
        append (loop for previous in lines
                     for line in (rest lines)
                     collect (list start previous line var))))

(defun explain (step)
  (destructuring-bind (start previous line var) step
    (declare (ignore start))
    (getf (attribute (parse-line previous var) (parse-line line var)) :state)))

(let* ((steps (corpus-steps))
       (cold (destructuring-bind (start previous line var) (first steps)
               (microseconds (lambda () (check-step start previous line :var var)))))
       (verdicts '())
       (explanations '())
       (states '()))
  (format t "cold first step: ~dus~%" cold)
  (dotimes (round 20)
    (dolist (step steps)
      (destructuring-bind (start previous line var) step
        (push (microseconds (lambda () (check-step start previous line :var var))) verdicts))))
  (report "verdict, warm" verdicts)
  (dolist (step steps)
    (let ((state nil))
      (push (microseconds (lambda () (setf state (explain step)))) explanations)
      (push state states)))
  (report "explanation, warm" explanations)
  (format t "explanation states at depth 2: ok ~d, none ~d, unavailable ~d~%"
          (count :ok states) (count :none states) (count :unavailable states))
  (let ((worst "((((x^6)^6)^6)^6)^6 = ((((x^6)^6)^6)^6)^6 + 1"))
    (report "worst refusal found" (list (microseconds (lambda () (check-lines worst "x = 1")))))))
