#!/bin/sh
# Print the versions used in this run. A missing tool stops the run at once.
set -eu
for tool in sbcl swipl; do
    command -v "$tool" >/dev/null || { echo "MISSING TOOL: $tool" >&2; exit 2; }
done
sbcl --version
swipl --version
