# chez-parallel-map
A library for parallel computation in Chez Scheme

This library provides a set of tools for parallel computaions in Chez Scheme. To get started, copy parallel-map.ss into your project directory. Use 

(import (parallel-map))

to import the library,

Then start a thread pool and specify the number of threads (2 times the number of cores in your CPU should do):

(define tp (make-thread-pool 4))

Now you can start using the "parallel-map" function. It's syntax is the same as that of usual "map", except that the first argument should be a thread pool.

(define (factorial x)
  (if (= x 0)
      1
      (* x (factorial (- x 1)))))

(parallel-map tp factorial '(2 3 4 5 6 7 8 9 10)) 

Let's do something like this:

(parallel-map tp factorial '(500000 500001 500002 500003 500004)) 

