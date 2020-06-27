# chez-parallel-map
A quickly hacked library for parallel computation in Chez Scheme.

This library provides a set of tools for parallel computaions in Chez Scheme. To get started, copy parallel-map.ss into your project directory. Use 

(import (parallel-map))

to import the library,

Then start a thread pool and specify the number of threads (2 times the number of cores in your CPU should do):

(define tp (make-thread-pool 4))

Now you can start using the "parallel-map" function. It's syntax is the same as that of usual "map", except that the first argument should be a thread pool:

(define (factorial x)
  (if (= x 0)
      1
      (* x (factorial (- x 1)))))

(parallel-map tp factorial '(2 3 4 5 6 7 8 9 10)) 

As parallel-map returns, you can use the thred pool again. To destroy the thread pool, type: 

(kill-thread-pool tp)

If you want to stop a very long execution of map-parallel, type ctrl-c in chez scheme to stop execution of the current command, then type:

(stop-thread-pool tp)

After that the thread pool is ready for operations again.

An idle thread pool should not consume significant resources.



