#!/bin/sh
# Local run of the same image and steps as CI, except Lean.
set -eu
docker build -q -t symalgebra-ci .
sh scripts/check-repo.sh
sh scripts/in-image.sh scripts/run-tests.sh
sh scripts/in-image.sh scripts/sabotage.sh
