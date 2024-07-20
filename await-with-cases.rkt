#lang racket/base
(require (except-in esterel/full await)
         (for-syntax racket/base syntax/parse)
         racket/base syntax/parse)

(provide await
         await/proc
         await-n/proc
         await-immediate/proc
         await-cases/proc)

(struct branch (is-immediate test body))

(begin-for-syntax
  (struct branch (is-immediate test body))
  
  (define-splicing-syntax-class maybe-immediate
    (pattern (~seq #:immediate)
      #:attr parsed-boolean (syntax #true))
    (pattern (~seq)
      #:attr parsed-boolean (syntax #false)))

  (define-syntax-class single-branch
    (pattern
      (imm:maybe-immediate
       test:expr)
       #:attr parsed-branch #`(branch imm.parsed-boolean
                                      (λ () test)
                                      (λ () (void))))
    (pattern
      (imm:maybe-immediate
       test:expr
       clause:expr)
       #:attr parsed-branch #`(branch imm.parsed-boolean
                                      (λ () test)
                                      (λ () clause)))))

(define-syntax (await stx)
  (syntax-parse stx
    [(_ e:expr (~optional (~seq #:n n:expr)))
     (if (attribute n)
         #'(await-n/proc (λ () e) n)
         #'(await/proc (λ () e)))]
    [(_ #:immediate e:expr)
     #'(await-immediate/proc (λ () e))]
    [(_ #:cases b:single-branch ...+)
     #'(await-cases/proc (list b.parsed-branch ...))]))

(define (await/proc thunk)
  (with-trap T-await
    (let loop ()
      (pause)
      (when (thunk)
        (exit-trap T-await))
      (loop))))

(define (await-n/proc thunk n)
  (suspend
   (repeat n (λ () (pause)))
   (not (thunk))))

(define (repeat n thunk)
  (with-trap T
    (thunk)
    (let loop ([n (- n 1)])
      (if (> n 0)
          (begin (thunk) (loop (- n 1)))
          (exit-trap T)))))

(define (await-immediate/proc test-thunk)
  (with-trap T-await-immediate
    (let loop ()
      (when (test-thunk)
        (exit-trap T-await-immediate))
      (pause)
      (loop))))

(define (handle-immediate-cases T-await-cases branches)
  (for ([a-branch branches])
    (when (and (branch-is-immediate a-branch) ((branch-test a-branch)))
      ((branch-body a-branch))
      (exit-trap T-await-cases))))

(define (handle-all-cases T-await-cases branches)
  (for ([a-branch branches])
    (when ((branch-test a-branch))
      ((branch-body a-branch))
      (exit-trap T-await-cases))))

(define (await-cases/proc branches)
  (with-trap T-await-cases
    (handle-immediate-cases T-await-cases
                            branches)
    (let loop ()
      (pause)
      (handle-all-cases T-await-cases
                        branches)
      (loop))))
