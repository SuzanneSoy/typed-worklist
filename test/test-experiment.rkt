#lang typed/racket
(require "../experiment.rkt")

(work (list (list 7)
            (list))
      [(λ ([x : Integer])
         (list (number->string x)
               (list (if (> x 0) (sub1 x) 0))
               (list (string->symbol
                      (string-append "v" (number->string x))))))
       (λ ([x : Symbol])
         (list (eq? 'v5 x)
               (list 10)
               (list 'xyz)))]
      (Integer String)
      (Symbol Boolean))