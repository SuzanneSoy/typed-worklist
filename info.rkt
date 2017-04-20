#lang info
(define collection "typed-worklist")
(define deps '("base"
               "rackunit-lib"
               "type-expander"
               "typed-racket-lib"
               "typed-racket-more"))
(define build-deps '("scribble-lib"
                     "racket-doc"))
(define scribblings '(("scribblings/typed-worklist.scrbl" () ("typed-racket"))))
(define pkg-desc "A Typed/Racket implementation of Kildall's worklist algorithm, with multiple worklists of different types.")
(define version "0.1")
(define pkg-authors '("Georges Dupéron"))
