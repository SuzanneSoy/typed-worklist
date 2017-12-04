#lang scribble/manual
@(require scriblib/footnote
          (for-label typed-worklist
                     racket/base))

@title{Typed worklist}
@author[@author+email["Georges Dupéron" "georges.duperon@gmail.com"]]

@defmodule[typed-worklist]

This package is mainly intended to be used by the
@racketmodname[phc-graph #:indirect] package@note{the development of
 @racketmodname[phc-graph #:indirect] is currently stalled, as I'm
 investigating solutions based on @racketmodname[turnstile #:indirect].}.

The goal of @racketmodname[phc-graph #:indirect] is to implement generalised
folds (catamorphisms) over heterogeneous graphs. Heterogeneous graphs can be
conceptualised as a trees where nodes can have different types (e.g. nodes of
type @racketid[A] have children of type @racketid[B], which have children of
type @racketid[C], which have children of type @racketid[A], and each node
type can hold different metadata), generalised to allow backward arcs (so that
the trees become true graphs).

A simple technique for traversing and processing such a data structure is to
have a worklist, which remembers the already-visited nodes, as well as a queue
of nodes that still need to be visited. A polymorphic
@racketid[example-worklist1] function which can be used to handle two sets of
processed/to-process nodes from a @emph{homogeneous} graph would have the
following signature:

@nested[
 #:style 'inset
 @defproc[#:link-target? #f
 (example-worklist1 [roots (Listof In)]
                    [proc (→ In (Values Out (Listof In)))])
 (Listof Out)]{
  Signature for a hypothetical function which takes an initial list of tasks of
  type @racketid[In], and a processing function which consumes one task,
  returning a result of type @racket[Out], and a list of new tasks.

  The hypothetical function would return the results obtained after processing
  each task, making sure that each task is processed only once (i.e. if a task
  is returned multiple times by processing functions, it is only added once to
  the queue).}]

However, when the tasks to handle have heterogeneous types @racket[In₁ … Inₙ],
the type of the @racketid[worklist] function is not simple to express. Using
Typed Racket's variadic polymorphic types, also sometimes mentioned as
"polydots" (of the form @racket[(∀ (A B X ...) τ)]) along with intersection
types, it is possible to encode the type of @racket[worklist].

Typed Racket is not (yet?) able to reliably enfoce the fact that two variadic
polymorphic type variables must have the same length. The trick is to wrap the
@racket[Inᵢ] and @racket[Outᵢ] types with structs @racket[I] and @racket[O],
which serve as type-level tags. Then, a single variadic type variable ranges
over the union types @racket[(U (I Inᵢ) (O Outᵢ)) ...]. Finally, intersection
types are used to project the @racket[I] or @racket[O] parts of the type
variable.

The implementation of the worklist function is not trivial, and calling it
requires some amount of boilerplate to correctly instantiate its type, wrap
the inputs with @racket[I], and extract the results out of the @racket[O]. The
@racket[worklist] macro takes care of this boilerplate.

It is worth noting that the core of the @racket[worklist] implementation is a
function. The macro does not generate the whole implementation, instead it
merely generates a lightweight wrapper and takes care of the instantiation of
the function's polymorphic type. When worklists with a large number of task
types are used, this function-based implementation can (hopefully) reduce the
typechecking time, compared to a macro-based implementation which would
generate a large chunk of code needing to be typechecked. Also, the guarantees
on the correctness of the code are better, since the function-based
implementation is typechecked once and for all (the macro-generated wrapper
could still fail to typecheck, but it is a smaller and simpler piece of code).

Finally, it is a remarkable feat that Typed Racket is able to express the type
of such a function (and is also able to typecheck its implementation!), as
this problem would require at first look some flavor of type-level
computation, dependent types or similar advanced typing features.
Comparatively, the mechanisms used here (variadic polymorphic variables and
intersection types) are refreshingly simple.

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