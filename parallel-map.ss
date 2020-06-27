;;; Copyright 2019 Andrei Alpeev
;;;
;;; Licensed under the Apache License, Version 2.0 (the "License");
;;; you may not use this file except in compliance with the License.
;;; You may obtain a copy of the License at
;;;
;;;     http://www.apache.org/licenses/LICENSE-2.0
;;;
;;; Unless required by applicable law or agreed to in writing, software
;;; distributed under the License is distributed on an "AS IS" BASIS,
;;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;; See the License for the specific language governing permissions and
;;; limitations under the License.


(library (parallel-map (0 1))
     (export make-smart-thread
	     make-thread-pool
	     stop-thread-pool
	     kill-thread-pool
	     parallel-map)

     (import (chezscheme))


(define period-ticks 1000)
(define (make-smart-thread)
  (define m (make-mutex))
  (define c (make-condition))
  (define status 'init-waiting)
  (define program '())
  (define die-flag #f)
  (define stop-flag #f)
  (define (dispatcher op . args)
    (case op
      ('die (with-mutex m
	      (set! die-flag #t)
	      (set! stop-flag #t)
	      (condition-signal c)))
      ('run (with-mutex m
			(if (eq? status 'ready)
			    (if (and (= 1 (length args)) (procedure? (car args)))
				(begin 
				  (set! program (car args))
				  (set! status 'program-loaded)
				  (condition-signal c)
				  #t)
				(error "smart-thread dispatcher" "one thunc expected after 'run" args))
			    #f)))
      ('stop (with-mutex m 
			 (set! stop-flag #t)))
      ('ready? (eq? status 'ready))
      (else (error "smart-thread dispatcher" "unknown operation" op))))

  (define (thunc)
    (mutex-acquire m)
    (set! status 'ready)
    (set! stop-flag #f)
    (do () (die-flag) 
      (cond
	[(eq? status 'program-loaded)
	     (mutex-release m)
	     (let loop ([eng (make-engine program)])
	       (if stop-flag
		   (set! stop-flag #f)
		   (eng
		     period-ticks
		     (lambda args '())
		     loop)))
	     (mutex-acquire m)
	     (set! status 'ready)
	     (set! program '())
	     (set! stop-flag #f)]
	[else
	  (condition-wait c m)]))
    (mutex-release m))

  (fork-thread thunc)

  dispatcher)

(define (make-thread-pool number)
  (define res (map (lambda (arg) (make-smart-thread)) (make-list number)))
  (for-each 
    (lambda (smart-thread)
      (do ()
	((smart-thread 'ready?))))
    res)
  res)

(define (kill-thread-pool thread-pool)
  (for-each
    (lambda (smart-thread)
      (smart-thread 'die))
    thread-pool))

(define (stop-thread-pool thread-pool)
  (for-each
    (lambda (smart-thread)
      (smart-thread 'stop))
    thread-pool))

(define (parallel-map tp function . lsts)
  (define threads-number (length tp))
  (define threads-ended 0)
  (define result (make-list (length (car lsts))))
  (define (tmp-get-lists tmp)
    (car tmp))
  (define (tmp-get-res tmp)
    (cdr tmp))
  (define io (box (cons lsts result)))
  (define m (make-mutex))
  (define c (make-condition))
  
  (define (thunc)
    (let loop () 
      (let* ((tmp (unbox io))
	     (tmp-lists (tmp-get-lists tmp))
	     (tmp-res (tmp-get-res tmp)))
	(if (null? tmp-res)
	    (with-mutex m
			(set! threads-ended (+ 1 threads-ended))
			(when (= threads-ended threads-number)
			  (condition-signal c)))
	    (let ((new-tmp (cons (map cdr tmp-lists) (cdr tmp-res))))
	      (when (box-cas! io tmp new-tmp)
		(set-car! tmp-res (apply function (map car tmp-lists))))
	      (loop))))))

  (unless (for-all
	    (lambda (smart-thread)
	      (smart-thread 'run thunc))
	    tp)
    (error "parallel-map" "thread-pool is not ready" '()))
  (with-mutex m
	      (do ()
		((= threads-number threads-ended))
		(condition-wait c m)))
  (for-each 
    (lambda (sm-thread)
      (do ()
	((sm-thread 'ready?))))
    tp)
  result)
)


