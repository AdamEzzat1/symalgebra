;;;; Exact rational helpers. Floats are banned from the core.

(defpackage #:symalgebra.exact
  (:use #:cl)
  (:export #:rat-string))

(in-package #:symalgebra.exact)

(defun rat-string (q)
  "Serialise the rational Q as ASCII n/d, the only form compared across tools."
  (check-type q rational)
  (format nil "~D/~D" (numerator q) (denominator q)))
