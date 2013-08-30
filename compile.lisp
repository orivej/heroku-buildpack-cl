(in-package :cl-user)

(unless (nthcdr 2 sb-ext:*posix-argv*)
  (write-line "Required arguments: BUILD-DIR/ CACHE-DIR/")
  (sb-ext:exit 1))

(defvar *build-dir* (pathname (nth 1 sb-ext:*posix-argv*)))
(defvar *cache-dir* (pathname (nth 2 sb-ext:*posix-argv*)))

(require :asdf)
(asdf:initialize-source-registry `(:source-registry :ignore-inherited-configuration (:directory ,*build-dir*)))
(asdf:disable-output-translations)

(defmacro fncall (funname &rest args)
  `(funcall (read-from-string ,funname) ,@args))

(defun require-quicklisp (&key version)
  "VERSION if specified must be in format YYYY-MM-DD"
  (let ((ql-setup (merge-pathnames "quicklisp/setup.lisp" *cache-dir*)))
    (if (probe-file ql-setup)
        (load ql-setup)
        (progn
          (load (merge-pathnames "quicklisp.lisp" #.*load-pathname*))
          (fncall "quicklisp-quickstart:install"
                  :path (make-pathname :directory (pathname-directory ql-setup)))))
    (when version
      (fncall "ql-dist:install-dist"
              (format nil "http://beta.quicklisp.org/dist/quicklisp/~A/distinfo.txt"
                      version)
              :replace t :prompt nil))))

(load (merge-pathnames "heroku-compile.lisp" *build-dir*))
