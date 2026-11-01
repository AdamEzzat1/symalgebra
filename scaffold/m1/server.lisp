;;;; M1 scaffold server: sbcl --script scaffold/m1/server.lisp
;;;; Stateless. It keeps nothing between requests and logs only that it started.

(require :sb-bsd-sockets)

(defvar *here* (directory-namestring *load-truename*))
(defun from-here (name) (concatenate 'string *here* name))

(load (from-here "json.lisp"))
(load (from-here "reducer.lisp"))
(load (from-here "api.lisp"))

(defpackage :symalgebra.m1.server
  (:use :cl :sb-bsd-sockets :symalgebra.m1.json :symalgebra.m1.api))

(in-package :symalgebra.m1.server)

(defconstant +body-limit+ 1024)
(defconstant +header-limit+ 8192)
(defconstant +io-timeout+ 5)

(defparameter *security-headers*
  (format nil "Content-Security-Policy: default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'~c~cX-Content-Type-Options: nosniff~c~cReferrer-Policy: no-referrer~c~c"
          #\Return #\Newline #\Return #\Newline #\Return #\Newline))

(defun file-octets (name)
  (with-open-file (in (cl-user::from-here name) :element-type '(unsigned-byte 8))
    (let ((data (make-array (file-length in) :element-type '(unsigned-byte 8))))
      (read-sequence data in)
      data)))

;;; A fixed table, read once at start, so a request path never reaches the filesystem.
(defparameter *static*
  (list (list "/" "text/html; charset=utf-8" (file-octets "static/index.html"))
        (list "/app.js" "text/javascript; charset=utf-8" (file-octets "static/app.js"))
        (list "/style.css" "text/css; charset=utf-8" (file-octets "static/style.css"))))

(defparameter *problems* (load-problems (cl-user::from-here "problems.json")))

(defun utf8 (string) (sb-ext:string-to-octets string :external-format :utf-8))

(defun respond (stream code type body)
  (write-sequence
   (utf8 (format nil "HTTP/1.1 ~d ~a~c~cContent-Type: ~a~c~cContent-Length: ~d~c~cCache-Control: no-store~c~c~aConnection: close~c~c~c~c"
                 code (if (= code 200) "OK" "Error") #\Return #\Newline
                 type #\Return #\Newline
                 (length body) #\Return #\Newline
                 #\Return #\Newline
                 *security-headers*
                 #\Return #\Newline #\Return #\Newline))
   stream)
  (write-sequence body stream)
  (finish-output stream))

(defun respond-json (stream code value)
  (respond stream code "application/json" (utf8 (write-json value))))

(defun refuse (stream code)
  (respond-json stream code (list :obj (cons "v" 1) (cons "status" "bad_request"))))

(defun read-head (stream)
  "Header text up to the blank line, or NIL when it is too long or the peer closes."
  (let ((head (make-array +header-limit+ :element-type '(unsigned-byte 8)))
        (n 0))
    (loop
      (let ((byte (read-byte stream nil nil)))
        (when (or (null byte) (= n +header-limit+)) (return nil))
        (setf (aref head n) byte)
        (incf n)
        (when (and (>= n 4) (equalp (subseq head (- n 4) n) #(13 10 13 10)))
          (return (sb-ext:octets-to-string head :end n :external-format :latin-1)))))))

(defun content-length (head)
  (let* ((lower (string-downcase head))
         (at (search (format nil "~c~ccontent-length:" #\Return #\Newline) lower)))
    (if at
        (parse-integer lower :start (+ at 17) :junk-allowed t)
        0)))

(defun read-body (stream length)
  (let ((body (make-array length :element-type '(unsigned-byte 8))))
    (when (= (read-sequence body stream) length)
      (sb-ext:octets-to-string body :external-format '(:utf-8 :replacement #\?)))))

(defun handle-post (stream head handler)
  (let ((length (content-length head)))
    (if (or (null length) (minusp length) (> length +body-limit+))
        (refuse stream 413)
        (let ((body (read-body stream length)))
          (if body
              (handler-case
                  (respond-json stream 200 (funcall handler *problems* (parse-json body)))
                ((or bad-request json-failure) () (refuse stream 400)))
              (refuse stream 400))))))

(defun handle-connection (stream)
  (let ((head (read-head stream)))
    (when head
      (let* ((first-space (or (position #\Space head) 0))
             (second-space (or (position #\Space head :start (1+ first-space)) first-space))
             (method (subseq head 0 first-space))
             (path (subseq head (min (1+ first-space) second-space) second-space))
             (file (assoc path *static* :test #'string=)))
        (cond ((and (string= method "GET") file)
               (respond stream 200 (second file) (third file)))
              ((and (string= method "GET") (string= path "/api/problems"))
               (respond-json stream 200 (problem-list *problems*)))
              ((and (string= method "POST") (string= path "/api/check"))
               (handle-post stream head #'handle-check))
              ((and (string= method "POST") (string= path "/api/hint"))
               (handle-post stream head #'handle-hint))
              (t (refuse stream 404)))))))

(defun serve-connection (client)
  (let ((stream (socket-make-stream client :input t :output t :buffering :full
                                           :element-type '(unsigned-byte 8)
                                           :timeout +io-timeout+)))
    (unwind-protect
         (handler-case (handle-connection stream)
           (serious-condition ()
             (ignore-errors
              (respond-json stream 500 (list :obj (cons "v" 1) (cons "status" "not_checked"))))))
      (ignore-errors (close stream :abort t)))))

(defun main ()
  (let ((port (parse-integer (or (sb-ext:posix-getenv "PORT") "8080")))
        (socket (make-instance 'inet-socket :type :stream :protocol :tcp)))
    (setf (sockopt-reuse-address socket) t)
    (socket-bind socket #(0 0 0 0) port)
    (socket-listen socket 32)
    (format t "m1 scaffold listening on ~d~%" port)
    (finish-output)
    (loop
      (let ((client (socket-accept socket)))
        (sb-thread:make-thread (lambda () (serve-connection client)))))))

(main)
