Heroku Buildpack for Common Lisp
================================

My edition of the SBCL buildpack for Heroku by [Mike Travers](https://github.com/mtravers/heroku-buildpack-cl), reworked by [Anton Vodonosov](https://github.com/avodonosov/heroku-buildpack-cl2).

Differences from Anton's buildpack:
* Cache Quicklisp archives between rebuilds.
* Streamline [slug](https://devcenter.heroku.com/articles/slug-compiler) layout.
* Simplify Procfile.
* Provide test-run to simulate remote environment locally.

## Usage

You provide _heroku-compile.lisp_ in the root of your source tree, which
downloads all external dependencies and ensures that all .lisp files are
compiled to speed up deployment.  The buildpack loads it with SBCL installed in
the checkout of your source tree (in _bin/_ and _lib/sbcl/_) in the environment
where (1) ASDF is loaded, (2) ASDF registry is empty except for the root
directory of your source tree (with no recursion into subdirectories), (3) ASDF
places .fasl files alongside corresponding source files, (4)
`(require-quicklisp)` is defined to install Quicklisp in the cache directory and
load it, (5) `*build-dir*` contains the pathname of your source tree checkout
and `*cache-dir*` - the pathname of the cache which persists across builds.
Then _quicklisp/_ is copied from the cache dir to the build dir.

A simple _heroku-compile.lisp_ for _my-system.asd_:

```lisp
(require-quicklisp)
(ql:quickload :my-system)
```

You provide a [Procfile](https://devcenter.heroku.com/articles/procfile) in the
root of your source tree, which may launch SBCL from PATH.

```
web: sbcl --script my-launcher.lisp
```

The script develops its environment for itself:

```lisp
(load "quicklisp/setup.lisp")
(push #p"./" asdf:*central-registry*)
(require :my-system)
(my-package:start-web-server)
(my-package:join-web-server-thread)

```

You [create an app with this buildpack](https://devcenter.heroku.com/articles/buildpacks#using-a-custom-buildpack).

## Suggestions

### SIGTERM

Heroku sends all your processes SIGTERM when it wants to terminate their dyno.  Handle it with
```lisp
(sb-sys:enable-interrupt sb-posix:sigterm (lambda (sig info context) ...))
```

### SWANK

Compile SWANK (silently):

```lisp
(require-quicklisp)
(ql-dist:install (ql-dist:find-system "swank"))
(ql-impl-util:call-with-quiet-compilation
 (lambda ()
   (load (compile-file (asdf:system-relative-pathname "swank" "swank-loader.lisp")))))
(defun swank-loader::load-user-init-file ())
(setf swank-loader:*fasl-directory* swank-loader:*source-directory*)
(ql-impl-util:call-with-quiet-compilation
 (lambda ()
   (swank-loader:init :setup nil :quiet t)
   (swank-loader::compile-contribs :load nil :quiet t)))
```

Load and start SWANK (silently, ignoring ~/.swank in the development environment):

```lisp
(load (asdf:system-relative-pathname "swank" "swank-loader.fasl"))
(defun swank-loader::load-user-init-file ())
(setf swank-loader:*fasl-directory* swank-loader:*source-directory*)
(ql-impl-util:call-with-quiet-compilation
 (lambda ()
   (swank-loader:init)))
(swank:create-server :port 4005 :dont-close t)
```

### Simulating remote environment locally

Checkout the buildpack and from the root of your source tree, after commiting all changes, run `.../heroku-buildpack-cl/bin/test-compile` and then `env PORT=8080 .../heroku-buildpack-cl/bin/test-run --script my-launcher.lisp`
