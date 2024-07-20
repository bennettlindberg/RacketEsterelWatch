#lang racket

(require esterel/full)

; SIGNALS
(define-signal S)
(define-signal M)
(define-signal H)

(define-signal seconds #:init 0 #:combine +)
(define-signal minutes #:init 0 #:combine +)
(define-signal hours #:init 0 #:combine +)

(define-signal time #:init "0:0:0" #:combine +)
(define-signal 24H-mode #:init #f #:combine (λ (a b) (and a b)))
(define-signal 24H-mode-toggle)

; CONSTANTS
(define seconds-per-minute 60)
(define minutes-per-hour 60)

; THREADS
(define M-loop (λ () (let loop ()
              (if (and (present? S) (= (- seconds-per-minute 1) (signal-value seconds #:pre 1 #:can (set M))))
                  (emit M)
                  (void))
              (pause)
              (loop))))
(define H-loop (λ () (let loop ()
              (if (and (present? M) (= (- minutes-per-hour 1) (signal-value minutes #:pre 1 #:can (set H))))
                  (emit H)
                  (void))
              (pause)
              (loop))))
(define seconds-loop (λ () (let loop ()
              (define prev (signal-value seconds #:pre 1 #:can (set seconds time)))
              (emit seconds (modulo (+ prev
                                       (if (present? S)
                                           1
                                           0)) seconds-per-minute))
              (pause)
              (loop))))
(define minutes-loop (λ () (let loop ()
              (define prev (signal-value minutes #:pre 1 #:can (set minutes time)))
              (emit minutes (modulo (+ prev
                                       (if (present? M)
                                           1
                                           0)) minutes-per-hour))
              (pause)
              (loop))))
(define hours-loop (λ () (let loop ()
              (define prev (signal-value hours #:pre 1 #:can (set hours time)))
              (emit hours (modulo (+ prev
                                     (if (present? H)
                                         1
                                         0)) 24))
              (pause)
              (loop))))
(define time-loop (λ () (let loop ()
              (define cur-hours (signal-value hours #:can (set time)))
              (define cur-minutes (signal-value minutes #:can (set time)))
              (define cur-seconds (signal-value seconds #:can (set time)))
              
              (emit time (if (signal-value 24H-mode #:can (set))
                             ; 24-hour time
                             (format "~a:~a:~a"
                                     cur-hours
                                     cur-minutes
                                     cur-seconds)

                             ; AM-PM time
                             (format "~a:~a:~a ~a"
                                     (if (> cur-hours 12)
                                         (- cur-hours 12)
                                         (if (= 0 cur-hours)
                                             (+ cur-hours 12)
                                             cur-hours))
                                     cur-minutes
                                     cur-seconds
                                     (if (>= cur-hours 12)
                                         "PM"
                                         "AM"))))
              (pause)
              (loop))))
(define 24h-mode-loop (λ () (let loop ()
              (await (present? 24H-mode-toggle))
              (emit 24H-mode (not (signal-value 24H-mode #:pre 1 #:can (set 24H-mode))))
              (loop))))

; MAIN
(define r
  (esterel #:pre 1
           (par
            (M-loop)
            (H-loop)
            (seconds-loop)
            (minutes-loop)
            (hours-loop)
            (time-loop)
            (24h-mode-loop))))