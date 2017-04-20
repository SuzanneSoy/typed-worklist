#lang typed/racket

(provide worklist)

(require (only-in type-expander unsafe-cast))

;; TODO: write a macro wrapper which does the unsafe-cast (until the bug in TR
;; is fixed), and (un)wraps the inputs and outputs.
(provide worklist-function)

(struct (A) I ([v : A]) #:transparent)
(struct (A) O ([v : A]) #:transparent)

(: kons (∀ (A B) (→ A B (Pairof A B))))
(define kons cons)

(begin
  ;; Typed version of:
  #;(define (append-inner-inner lll)
      (apply map append lll))

  (: append-inner-inner (∀ (A ...)
                           (→ (Pairof (List (Listof (∩ I* A)) ...)
                                      (Listof (List (Listof (∩ I* A)) ...)))
                              (List (Listof (∩ I* A)) ... A))))
  (define (append-inner-inner lll)
    (if (null? lll)
        '()
        ;; Could also just use recursion here.
        ((inst foldl
               (List (Listof (∩ I* A)) ...)
               (List (Listof (∩ I* A)) ...)
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

(define-type I* (I Any))
(define-type O* (O Any))

(: worklist-function
   (∀ (A ...)
      (case→ (→ (List (Listof (∩ A I*)) ...)
                (List (→ (∩ A I*) (List (∩ A O*) (Listof (∩ A I*)) ...)) ...)
                (List (Listof (Pairof (∩ A I*) (∩ A O*))) ...)))))

(define (worklist-function roots processors)
  (define nulls (map (λ (_) (ann '() (Listof Nothing))) processors))
  (define empty-sets (map list->set nulls))

  (define wrapped-processors
    : (List (→ (∩ A I*) (List (Pairof (∩ A I*) (∩ A O*)) (Listof (∩ A I*)) ...))
            ...)
    (map (λ #:∀ (In Out More) ([l : (Listof In)] [f : (→ In (Pairof Out More))])
           (λ ([in : In]) : (Pairof (Pairof In Out) More)
             (let ([out (f in)])
               (cons (cons in (car out))
                     (cdr out)))))
         roots
         processors))
  
  (define (loop [queue* : (List (Setof (∩ A I*)) ...)]
                [done* : (List (Setof A) ...)])
    : (List (Listof (Pairof (∩ A I*) (∩ A O*))) ...)

    (if (andmap set-empty? queue*)
        (ann nulls (List (Listof (Pairof (∩ A I*) (∩ A O*))) ...))
        (let ()
          (define lqueue* (map set->list queue*))
          (define res (map map wrapped-processors lqueue*))
          (define new-done* (map set-union done* queue*))
          (define new-inputs
            ((inst append-inner-inner A ... A)
             (kons nulls
                   (map (λ ([x : (Listof
                                  (Pairof Any (List (Listof (∩ A I*)) ...)))])
                          ((inst append-inner-inner A ... A)
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
   (inst worklist-function
         (U (I In) (O Out))
         ...)
   ;; cast to its own type, circumventing the fact that TR doesn't seem to apply
   ;; intersections in this case.
   (-> (List (Listof (I In)) ...)
       (List
        (-> (I In)
            (List
             (O Out)
             (Listof (I In))
             ...))
        ...)
       (List (Listof (Pairof (I In)
                             (O Out)))
             ...))))

(: i* (∀ (A) (→ (Listof A) (Listof (I A)))))
(define (i* l) (map (inst I A) l))

(: i** (∀ (A ...) (→ (List (Listof A) ...) (List (Listof (I A)) ...))))
(define (i** ll) (map i* ll))

(: wrap-io (∀ (A B C ...) (→ (→ A (List B (Listof C) ...))
                             (→ (I A) (List (O B) (Listof (I C)) ...)))))
(define (wrap-io f)
  (λ ([arg : (I A)])
    (define result (f (I-v arg)))
    (kons (O (car result)) (map i* (cdr result)))))

(: unwrap-io1 (∀ (A B) (→ (Listof (Pairof (I A) (O B)))
                          (HashTable A B))))
(define (unwrap-io1 l)
  (make-immutable-hash
   (map (λ ([x : (Pairof (I A) (O B))])
          (kons (I-v (car x)) (O-v (cdr x))))
        l)))

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

(define-syntax-rule (worklist roots (proc ...) (In Out) ... )
  (unwrap-io ((inst-worklist (In Out) ...)
              (i** roots)
              (list (wrap-io proc) ...))
             (proc 'dummy) ...))
