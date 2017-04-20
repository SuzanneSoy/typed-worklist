#lang scribble/manual
@(require (for-label typed-worklist
                     racket/base))

@title{Typed worklist}
@author[@author+email["Georges Dupéron" "georges.duperon@gmail.com"]]

@defmodule[typed-worklist]

@defform[(worklist roots [procᵢ …ₙ] [Inᵢ Outᵢ] …ₙ)
         #:contracts
         ([roots (List (Listof Inᵢ) …ₙ)]
          [procᵢ (→ Inᵢ (List Outᵢ (Listof Inᵢ) …ₙ))]
          [Inᵢ Type]
          [Outᵢ Type])]{
                        
 Executes the corresponding @racket[procᵢ] on each element of each worklist.
 The @racket[procᵢ] takes a value of type @racket[Inᵢ] and returns an output of
 type @racket[Outᵢ], as well as @racket[n] lists of new inputs which are added
 to the worklists.

 The worklists are initialised with the given @racket[roots].

 The whole expression has the following result type:

 @racketblock[(List (HashTable Inᵢ Outᵢ) …ₙ)]

 Within a worklist, duplicate elements are only processed once.}