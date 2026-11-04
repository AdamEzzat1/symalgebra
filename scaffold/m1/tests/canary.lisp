;;;; Log canary: sbcl --script scaffold/m1/tests/canary.lisp [server.lisp]
;;;; Runs the real server and sends a marker in every part of a request. Its output must stay
;;;; the one start line, so nothing a person types can reach the host's logs.

(require :sb-bsd-sockets)

(defconstant +port+ 18181)
(defparameter *marker* "CANARY7Q4Z")
(defparameter *here* (directory-namestring *load-truename*))
(defparameter *server* (or (second sb-ext:*posix-argv*)
                           (concatenate 'string *here* "../server.lisp")))
(defparameter *log* "/tmp/m1-canary.log")
(defvar *ran* 0)
(defvar *passed* 0)

(defun check (name ok)
  (incf *ran*)
  (if ok
      (incf *passed*)
      (format t "FAIL canary ~a~%" name)))

(defun exchange (request)
  "Send REQUEST and return the reply text, or NIL when the server is not up."
  (let ((socket (make-instance 'sb-bsd-sockets:inet-socket :type :stream :protocol :tcp)))
    (handler-case
        (progn
          (sb-bsd-sockets:socket-connect socket #(127 0 0 1) +port+)
          (let ((stream (sb-bsd-sockets:socket-make-stream
                         socket :input t :output t :buffering :full
                                :external-format :latin-1)))
            (write-string request stream)
            (finish-output stream)
            (with-output-to-string (out)
              (loop for c = (read-char stream nil nil)
                    while c do (write-char c out)))))
      (sb-bsd-sockets:socket-error () nil))))

(defun post (path body &optional (headers ""))
  (format nil "POST ~a HTTP/1.1~c~cHost: t~c~c~aContent-Length: ~d~c~c~c~c~a"
          path #\Return #\Newline #\Return #\Newline headers (length body)
          #\Return #\Newline #\Return #\Newline body))

(defun get-request (path headers)
  (format nil "GET ~a HTTP/1.1~c~cHost: t~c~c~a~c~c"
          path #\Return #\Newline #\Return #\Newline headers #\Return #\Newline))

(defun wait-for-server ()
  (loop repeat 100
        do (when (exchange (get-request "/" "")) (return t))
           (sleep 0.1)))

(defun requests ()
  (let ((header (format nil "X-Note: ~a~c~c" *marker* #\Return #\Newline)))
    (list
     (cons "line" (post "/api/check"
                        (format nil "{\"v\":1,\"problem\":\"lin-01\",\"previous\":\"2x + 3 = 11\",\"text\":\"~a\"}"
                                *marker*)))
     (cons "broken json" (post "/api/check" (format nil "{~a" *marker*)))
     (cons "hint" (post "/api/hint" (format nil "{\"v\":1,\"problem\":\"~a\"}" *marker*)))
     (cons "practice line" (post "/api/practice/check"
                                 (format nil "{\"v\":1,\"problem\":\"dist-a\",\"previous\":\"x = 1\",\"text\":\"~a\"}"
                                         *marker*)))
     (cons "practice steps" (post "/api/practice/solution"
                                  (format nil "{\"v\":1,\"problem\":\"~a\"}" *marker*)))
     (cons "path" (get-request (format nil "/~a" *marker*) ""))
     (cons "header" (get-request "/" header))
     (cons "oversized" (post "/api/check" (make-string 2000 :initial-element #\Z) header)))))

(defun file-text (path)
  (with-open-file (in path)
    (let ((text (make-string (file-length in))))
      (subseq text 0 (read-sequence text in)))))

(let ((server (sb-ext:run-program sb-ext:*runtime-pathname* (list "--script" *server*)
                                  :environment (list (format nil "PORT=~d" +port+))
                                  :output *log* :if-output-exists :supersede
                                  :error :output :wait nil)))
  (unwind-protect
       (progn
         (check "server starts" (wait-for-server))
         (loop for (name . request) in (requests)
               do (check name (search "HTTP/1.1" (or (exchange request) "")))))
    (sb-ext:process-kill server 15)
    (sb-ext:process-wait server)))

(let ((log (file-text *log*)))
  (check "no marker in the output" (not (search *marker* log)))
  (check "only the start line"
         (string= (string-right-trim '(#\Newline) log)
                  (format nil "m1 scaffold listening on ~d" +port+))))

(format t "COUNT log-canary ran=~d passed=~d~%" *ran* *passed*)
(sb-ext:exit :code (if (= *ran* *passed*) 0 1) :abort t)
