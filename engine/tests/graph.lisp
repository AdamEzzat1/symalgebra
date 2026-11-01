;;;; rperft and Tier E. Loaded by run.lisp. Each edge walked is checked here against the Lisp
;;;; verdict, and corpus/edges.jsonl carries them to SymPy, which re-checks every one by itself.
;;;; REGENERATE=1 rewrites the two pinned files. Their counts are regression values, not truth.

(in-package :symalgebra.engine)

(defparameter *graph-problems*
  '(("2x + 5 = 17" 2) ("3(x - 2) = 6" 2) ("x/2 + 1 = 4" 2) ("5x - 2 = 3x + 8" 2)
    ("2(x + 1) = 2x + 2" 2) ("x/3 = x/6 + 1" 2) ("1/x = 2" 2) ("x/(x - 1) = 1/(x - 1)" 2)
    ("x + 0 = 2" 2) ("(x/2) * (3/5) = 1" 2) ("x/(2/3) = 1" 2) ("(x + 1) * 0 = x" 2)
    ("3x + x = 8" 3) ("x = 1" 3) ("x + 2 = 5" 3) ("2x = 6" 3)))

(defun edge-allowed-p (rule before after)
  "The invariant: a sound edge keeps the solution set, or at most gains a root if an implication."
  (let ((name (verdict-name (verdict (unflat before) (unflat after)))))
    (if (eq (rule-field rule :class) 'equivalence)
        (string= name "EQUIVALENT")
        (or (string= name "EQUIVALENT") (string= name "GAINS")))))

(defun unflat (tree)
  "A flat tree as the binary tree the verdict reads. Meaning is the same."
  (cond ((atom tree) tree)
        ((member (first tree) '(+ *))
         (reduce (lambda (a b) (list (first tree) a b)) (mapcar #'unflat (rest tree))))
        ((eq (first tree) '^) (list '^ (unflat (second tree)) (third tree)))
        (t (cons (first tree) (mapcar #'unflat (rest tree))))))

(defun edge-json (edge)
  (destructuring-bind (rule before after) edge
    (format nil "{\"rule\": \"~a\", \"class\": \"~(~a~)\", \"before\": \"~a\", \"after\": \"~a\"}"
            (rule-id rule) (rule-field rule :class) (state-text before) (state-text after))))

(defun graph-lines (rules)
  (loop for (text depth) in *graph-problems*
        for result = (rperft (parse-line text) rules depth)
        collect (list text depth result)))

(defun summary-line (entry)
  (destructuring-bind (text depth result) entry
    (format nil "~a | depth ~a | paths ~a | states ~a | digest ~a"
            text depth (getf result :paths) (getf result :states) (getf result :digest))))

(defun file-lines (path)
  (with-open-file (in path :external-format :utf-8 :if-does-not-exist nil)
    (and in (loop for line = (read-line in nil) while line collect line))))

(defun write-lines (path lines)
  (with-open-file (out path :direction :output :if-exists :supersede :external-format :utf-8)
    (dolist (line lines) (write-line line out))))

(defun sampled (lines limit)
  "Every LINE when few, otherwise an even sample, so the file and the SymPy run stay small."
  (let ((step (max 1 (ceiling (length lines) limit))))
    (loop for line in lines
          for i from 0
          when (zerop (mod i step)) collect line)))

(tier "rperft"
  (let* ((graphs (graph-lines *rules*))
         (summaries (mapcar #'summary-line graphs))
         (edge-lists (mapcar (lambda (entry) (getf (third entry) :edges)) graphs))
         (dump (loop for edges in edge-lists
                     append (sampled (sort (mapcar #'edge-json edges) #'string<) 300))))
    (when (sb-ext:posix-getenv "REGENERATE")
      (write-lines "corpus/rperft.txt" summaries)
      (write-lines "corpus/edges.jsonl" dump))
    (check "rperft counts are the pinned ones" (equal summaries (file-lines "corpus/rperft.txt")))
    (check "edge file is current" (equal dump (file-lines "corpus/edges.jsonl")))
    (dolist (edges edge-lists)
      (dolist (edge edges)
        (destructuring-bind (rule before after) edge
          (check (format nil "~a keeps meaning: ~a -> ~a" (rule-id rule) (state-text before) (state-text after))
                 (edge-allowed-p rule before after)))))
    (format t "edges checked ~d, dumped ~d~%" (reduce #'+ (mapcar #'length edge-lists)) (length dump)))
  ;; The invariant must be able to fail: a wrong rule is caught on a small graph.
  (let* ((bad (load-rules "sabotage/m3-wrong-rule.sexp"))
         (edges (getf (rperft (parse-line "2(x + 3) = 10") bad 1) :edges)))
    (check "the wrong rule produces edges" edges)
    (check "the invariant catches the wrong rule"
           (notevery (lambda (edge) (edge-allowed-p (first edge) (second edge) (third edge))) edges))))
