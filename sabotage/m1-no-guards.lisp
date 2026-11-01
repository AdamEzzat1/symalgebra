;;;; Removes the per-node checks, to prove the M1 tests fail without them.

(in-package :symalgebra.m1.reducer)

(defun multiply-forms (l r)
  (if (zerop (car l))
      (scale r (cdr l))
      (scale l (cdr r))))

(defun divide-forms (l r)
  (if (zerop (cdr r))
      l
      (scale l (/ 1 (cdr r)))))
