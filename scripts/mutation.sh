#!/bin/sh
# Runs inside the image. Tier F: each planted fault must make the engine tests fail.
set -eu
sbcl --script engine/tests/mutate.lisp
