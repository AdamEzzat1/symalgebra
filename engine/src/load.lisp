;;;; Loads the engine in dependency order. Rules are read from rules/rules.sexp, relative to the
;;;; working directory, so a rule is never copied into this source.

(defpackage :symalgebra.engine
  (:use :cl)
  (:export #:load-practice #:practice-list #:practice-check #:practice-hint #:bad-practice))

(dolist (name '("exact" "json" "parse" "poly" "meaning" "rules" "search" "step" "show" "tutor"))
  (load (merge-pathnames (concatenate 'string name ".lisp") *load-truename*)))
