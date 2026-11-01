#!/bin/sh
# Runs inside the image. Prints COUNT lines that gate compares with ci/manifest.txt.
set -eu
sh scripts/versions.sh
. ./tools.lock
sbcl --version | grep -qx "SBCL $SBCL_VERSION" \
    || { echo "PIN CHECK: sbcl is not $SBCL_VERSION" >&2; exit 1; }
swipl --version | grep -q "version $SWIPL_VERSION " \
    || { echo "PIN CHECK: swipl is not $SWIPL_VERSION" >&2; exit 1; }
sbcl --script engine/tests/smoke.lisp
swipl knowledge/tests/smoke.pl
sbcl --script scaffold/m1/tests/run.lisp
