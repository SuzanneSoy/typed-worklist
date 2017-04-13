#lang type-expander

;; TODO: write a macro wrapper which does the unsafe-cast (until the bug in TR
;; is fixed), and (un)wraps the inputs and outputs.
(provide worklist)

#;(struct (A) I ([v : A]) #:transparent)
#;(struct (A) O ([v : A]) #:transparent)

(define-type (I A) (Pairof 'I A))
(define-type (O A) (Pairof 'O A))

(define #:∀ (A) (i [a : A]) : (I A) (cons 'I a))
(define #:∀ (A) (o [a : A]) : (O A) (cons 'O a))

(define #:∀ (A) (i-v [w : (I A)]) : A (cdr w))
(define #:∀ (A) (o-v [w : (O A)]) : A (cdr w))

(: worklist
   (∀ (II OO A ...)
      (→ (List (Listof (∩ A II)) ...)
         (List (→ (∩ A II) (List (∩ A OO) (Listof (∩ A II)) ...)) ...)
         (List (Listof (∩ A OO)) ...))))

(: kons (∀ (A B) (→ A B (Pairof A B))))
(define kons cons)

(begin
  ;; Typed version of:
  #;(define (append-inner-inner lll)
      (apply map append lll))

  (: append-inner-inner (∀ (OO A ...) (→ (Pairof (List (Listof (∩ OO A)) ...)
                                                 (Listof (List (Listof (∩ OO A)) ...)))
                                         (List (Listof (∩ OO A)) ... A))))
  (define (append-inner-inner lll)
    (if (null? lll)
        '()
        ;; Could also just use recursion here.
        ((inst foldl
               (List (Listof (∩ OO A)) ...)
               (List (Listof (∩ OO A)) ...)
               Nothing
               Nothing)
         map-append2
         (car lll)
         (cdr lll))))

  (: map-append2 (∀ (A ...) (→ (List (Listof A) ...)
                               (List (Listof A) ...)
                               (List (Listof A) ...))))
  (define (map-append2 la lb)
    (map
     (ann append (∀ (X) (→ (Listof X) (Listof X) (Listof X)))) la lb)))

(define (worklist roots processors)
  (define res
    (map (λ #:∀ (Input Output) ([x : (Listof Input)]
                                [f : (→ Input
                                        (List Output (Listof (∩ A II)) ...))])
           (map (λ ([x : (List Output (Listof (∩ A II)) ...)])
                  ;; TODO: enqueue these instead of making a recursive call,
                  ;; and discard the already-processed elements as well as those
                  ;; already present in the queue.
                  (kons (car x)
                        ((inst worklist II OO A ... A) (cdr x) processors)))
                (map f x)))
         roots processors))

  (define nulls
    (map (λ #:∀ (Input Output) ([f : (→ Input
                                        (List Output (Listof (∩ A II)) ...))])
           (ann '() (Listof Output)))
         processors))

  ((inst append-inner-inner OO A ... A)
   (kons nulls
         (map (λ #:∀ (Output) ([x : (Listof (Pairof Output
                                                    (List (Listof (∩ A OO))
                                                          ...)))])
                ;; (Pairof _ (Listof (List (Listof (∩ A OO)) ... A)))
                ((inst append-inner-inner OO A ... A)
                 (kons nulls
                       (map (λ ([xᵢ : (Pairof Output
                                              (List (Listof (∩ A OO)) ... A))])
                              (cdr xᵢ))
                            x))))
              res))))

;(:type mapf)
;(define (mapf vs procs)
;  (error "NIY"))

(define w1
  (unsafe-cast
   (inst worklist
         (I Any) (O Any)
         (U (I Number) (O String))
         (U (I Float) (O Boolean)))
   ;; cast to its own type, circumventing the fact that TR doesn't seem to apply
   ;; intersections in this case.
   (-> (List (Listof (Pairof 'I Number)) (Listof (Pairof 'I Flonum)))
       (List
        (-> (Pairof 'I Number)
            (List
             (Pairof 'O String)
             (Listof (Pairof 'I Number))
             (Listof (Pairof 'I Flonum))))
        (-> (Pairof 'I Flonum)
            (List
             (Pairof 'O Boolean)
             (Listof (Pairof 'I Number))
             (Listof (Pairof 'I Flonum)))))
       (List (Listof (Pairof 'O String)) (Listof (Pairof 'O Boolean))))))


(λ ()
  (w1
   '(() ())
   (list (λ ([x : (I Number)])
           (list (o (number->string (i-v x))) '() '()))
         (λ ([x : (I Float)])
           (list (o (positive? (i-v x))) '() '())))))
