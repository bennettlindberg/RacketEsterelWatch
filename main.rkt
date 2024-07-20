#lang racket

(require (except-in esterel/full await))
(require "./await-with-cases.rkt")

; IMPORTS
(require "./signals.rkt")
(require "./button.rkt")
(require "./watch.rkt")
(provide create-watch)
   
; MAIN
(define (create-watch)
  (esterel #:pre 1
           (par
            (button)
            (watch))))