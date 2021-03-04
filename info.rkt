#lang info
(define collection "typed-worklist")
(define deps '(("base" "6.6.0.900")
               "rackunit-lib"
               "type-expander"
               "typed-racket-lib"
               "typed-racket-more"))
(define build-deps '("scribble-lib"
                     "racket-doc"))
(define scribblings '(("scribblings/typed-worklist.scrbl" () ("typed-racket"))))
(define pkg-desc "A Typed Racket implementation of a general-purpose worklist, with multiple worklists of different types.")
(define version "0.1")
(define pkg-authors '("Suzanne Soy"))
