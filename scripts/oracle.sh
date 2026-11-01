#!/bin/sh
# M2 evidence: the rule file and corpus against the independent oracle, on the pinned Python image.
set -eu
. ./tools.lock
tar -c oracle rules corpus sabotage lean/SymAlgebra/Rules.lean scripts/oracle-run.sh \
    | docker run --rm -i "python@$PYTHON_IMAGE_DIGEST" sh -c '
set -eu
tar -x
pip install -q --no-cache-dir --disable-pip-version-check --root-user-action=ignore \
    --require-hashes -r oracle/requirements.lock
sh scripts/oracle-run.sh
'
