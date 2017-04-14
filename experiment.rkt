#lang typed/racket

(provide work)

(require (only-in type-expander unsafe-cast))

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

(: kons (∀ (A B) (→ A B (Pairof A B))))
(define kons cons)

(begin
  ;; Typed version of:
  #;(define (append-inner-inner lll)
      (apply map append lll))

  (: append-inner-inner (∀ (OO A ...)
                           (→ (Pairof (List (Listof (∩ OO A)) ...)
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

(: map-cdr (∀ (A ...) (→ (List (Pairof Any A) ...) (List A ...))))
(define (map-cdr l)
  (map (λ #:∀ (X) ([x : (Pairof Any X)]) (cdr x)) l))

(: map-car (∀ (A ...) (→ (List (Pairof A Any) ...) (List A ...))))
(define (map-car l)
  (map (λ #:∀ (X) ([x : (Pairof X Any)]) (car x)) l))

(: worklist
   (∀ (II OO A ...)
      (→ (List (Listof (∩ A II)) ...)
         (List (→ (∩ A II) (List (∩ A OO) (Listof (∩ A II)) ...)) ...)
         (List (Listof (Pairof (∩ A II) (∩ A OO))) ...))))

(define (worklist roots processors)
  (define nulls (map (λ (_) (ann '() (Listof Nothing))) processors))
  (define empty-sets (map list->set nulls))

  (define wrapped-processors
    : (List (→ (∩ A II) (List (Pairof (∩ A II) (∩ A OO)) (Listof (∩ A II)) ...))
            ...)
    (map (λ #:∀ (In Out More) ([l : (Listof In)] [f : (→ In (Pairof Out More))])
           (λ ([in : In]) : (Pairof (Pairof In Out) More)
             (let ([out (f in)])
               (cons (cons in (car out))
                     (cdr out)))))
         roots
         processors))
  
  (define (loop [queue* : (List (Setof (∩ A II)) ...)]
                [done* : (List (Setof A) ...)])
    : (List (Listof (Pairof (∩ A II) (∩ A OO))) ...)

    (displayln queue*)
    (displayln done*)
    (newline)

    (if (andmap set-empty? queue*)
        (ann nulls (List (Listof (Pairof (∩ A II) (∩ A OO))) ...))
        (let ()
          (define lqueue* (map set->list queue*))
          (define res (map map wrapped-processors lqueue*))
          (define new-done* (map set-union done* queue*))
          (define new-inputs
            ((inst append-inner-inner II A ... A)
             (kons nulls
                   (map (λ ([x : (Listof
                                  (Pairof Any (List (Listof (∩ A II)) ...)))])
                          ((inst append-inner-inner II A ... A)
                           (kons nulls
                                 (map-cdr x))))
                        res))))

          (define outputs (map map-car res))

          (define new-to-do
            (map set-subtract (map list->set new-inputs) new-done*))

          (map append
               outputs
               (loop new-to-do new-done*)))))

  (loop (map list->set roots) empty-sets))

;(:type mapf)
;(define (mapf vs procs)
;  (error "NIY"))

(define-syntax-rule (inst-worklist (In Out) ...)
  (unsafe-cast
   (inst worklist
         (I Any) (O Any)
         (U (I In) (O Out))
         ...)
   ;; cast to its own type, circumventing the fact that TR doesn't seem to apply
   ;; intersections in this case.
   (-> (List (Listof (Pairof 'I In)) ...)
       (List
        (-> (Pairof 'I In)
            (List
             (Pairof 'O Out)
             (Listof (Pairof 'I In))
             ...))
        ...)
       (List (Listof (Pairof (Pairof 'I In)
                             (Pairof 'O Out)))
             ...))))

(: i* (∀ (A) (→ (Listof A) (Listof (I A)))))
(define (i* l) (map (inst i A) l))

(: i** (∀ (A ...) (→ (List (Listof A) ...) (List (Listof (I A)) ...))))
(define (i** ll) (map i* ll))

(: wrap-io (∀ (A B C ...) (→ (→ A (List B (Listof C) ...))
                             (→ (I A) (List (O B) (Listof (I C)) ...)))))
(define (wrap-io f)
  (λ ([arg : (I A)])
    (define result (f (i-v arg)))
    (kons (o (car result)) (map i* (cdr result)))))

(: unwrap-io1 (∀ (A B) (→ (Listof (Pairof (I A) (O B)))
                          (Listof (Pairof A B)))))
(define (unwrap-io1 l)
  (map (λ ([x : (Pairof (I A) (O B))])
         (kons (i-v (car x)) (o-v (cdr x))))
       l))

(define-syntax-rule (unwrap-io first-l (_ proc) ...)
  (let*-values ([(new-l l) (values '() first-l)]
                [(new-l l)
                 (begin proc
                        (values (kons (unwrap-io1 (car l))
                                      new-l)
                                (cdr l)))]
                ...
                [(new-l-reverse new-l-rest) (values '() new-l)]
                [(new-l-reverse new-l-rest)
                 (begin proc
                        (values (kons (car new-l-rest)
                                      new-l-reverse)
                                (cdr new-l-rest)))]
                ...)
    new-l))

(define-syntax-rule (work roots (proc ...) (In Out) ... )
  (unwrap-io ((inst-worklist (In Out) ...)
              (i** roots)
              (list (wrap-io proc) ...))
             (proc 'dummy) ...))
