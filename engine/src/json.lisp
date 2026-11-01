;;;; Small JSON reader for corpus files. Objects are (:obj ("key" . value) ...), arrays are vectors.

(in-package :symalgebra.engine)


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
