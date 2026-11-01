;;;; Small JSON reader and writer for the M1 scaffold. Discarded at M3 with the rest of it.
;;;; Objects are (:obj ("key" . value) ...), arrays are vectors, booleans are :true and :false.

(defpackage :symalgebra.m1.json
  (:use :cl)
  (:export #:parse-json #:write-json #:jget #:json-failure))

(in-package :symalgebra.m1.json)

(define-condition json-failure (error) ())

(defun jget (object key)
  (cdr (assoc key (rest object) :test #'string=)))

(defvar *text*)
(defvar *pos*)

(defun peek ()
  (when (< *pos* (length *text*)) (char *text* *pos*)))

(defun next ()
  (let ((c (peek)))
    (unless c (error 'json-failure))
    (incf *pos*)
    c))

(defun skip-space ()
  (loop while (member (peek) '(#\Space #\Tab #\Newline #\Return)) do (incf *pos*)))

(defun expect (c)
  (skip-space)
  (unless (eql (next) c) (error 'json-failure)))

(defun read-string-body ()
  (expect #\")
  (with-output-to-string (out)
    (loop
      (let ((c (next)))
        (case c
          (#\" (return))
          (#\\ (let ((e (next)))
                 (case e
                   (#\n (write-char #\Newline out))
                   (#\t (write-char #\Tab out))
                   (#\r (write-char #\Return out))
                   (#\b (write-char #\Backspace out))
                   (#\f (write-char #\Page out))
                   (#\u (let ((code (or (parse-integer *text* :start *pos*
                                                              :end (min (+ *pos* 4) (length *text*))
                                                              :radix 16 :junk-allowed t)
                                        (error 'json-failure))))
                          (incf *pos* 4)
                          (write-char (code-char code) out)))
                   (t (write-char e out)))))
          (t (write-char c out)))))))

(defun read-number ()
  (let* ((start *pos*)
         (end (or (position-if-not (lambda (c) (digit-char-p c)) *text* :start start)
                  (length *text*))))
    (when (= start end) (error 'json-failure))
    (setf *pos* end)
    (parse-integer *text* :start start :end end)))

(defun read-word (word value)
  (let ((end (+ *pos* (length word))))
    (unless (and (<= end (length *text*)) (string= word *text* :start2 *pos* :end2 end))
      (error 'json-failure))
    (setf *pos* end)
    value))

(defun read-object ()
  (expect #\{)
  (skip-space)
  (if (eql (peek) #\})
      (progn (next) (list :obj))
      (cons :obj
            (loop
              collect (let ((key (progn (skip-space) (read-string-body))))
                        (expect #\:)
                        (cons key (read-value)))
              do (skip-space)
              while (eql (peek) #\,)
              do (next)
              finally (expect #\})))))

(defun read-array ()
  (expect #\[)
  (skip-space)
  (if (eql (peek) #\])
      (progn (next) (vector))
      (coerce (loop
                collect (read-value)
                do (skip-space)
                while (eql (peek) #\,)
                do (next)
                finally (expect #\]))
              'vector)))

(defun read-value ()
  (skip-space)
  (case (peek)
    (#\{ (read-object))
    (#\[ (read-array))
    (#\" (read-string-body))
    (#\t (read-word "true" :true))
    (#\f (read-word "false" :false))
    (#\n (read-word "null" nil))
    (t (read-number))))

(defun parse-json (text)
  (let ((*text* text) (*pos* 0))
    (let ((value (read-value)))
      (skip-space)
      (when (peek) (error 'json-failure))
      value)))

(defun write-string-body (s out)
  (write-char #\" out)
  (loop for c across s do
    (cond ((char= c #\") (write-string "\\\"" out))
          ((char= c #\\) (write-string "\\\\" out))
          ((< (char-code c) 32) (format out "\\u~4,'0x" (char-code c)))
          (t (write-char c out))))
  (write-char #\" out))

(defun emit (value out)
  (cond ((stringp value) (write-string-body value out))
        ((integerp value) (format out "~d" value))
        ((eq value :true) (write-string "true" out))
        ((eq value :false) (write-string "false" out))
        ((null value) (write-string "null" out))
        ((vectorp value)
         (write-char #\[ out)
         (loop for item across value and first = t then nil do
           (unless first (write-char #\, out))
           (emit item out))
         (write-char #\] out))
        (t
         (write-char #\{ out)
         (loop for (key . item) in (rest value) and first = t then nil do
           (unless first (write-char #\, out))
           (write-string-body key out)
           (write-char #\: out)
           (emit item out))
         (write-char #\} out))))

(defun write-json (value)
  (with-output-to-string (out) (emit value out)))
