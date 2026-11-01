#!/bin/sh
# Runs inside the image. Step-check latency, with the verdict and explanation reported apart.
set -eu
sbcl --script engine/tests/bench.lisp
