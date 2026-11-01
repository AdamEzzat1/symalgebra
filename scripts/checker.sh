#!/bin/sh
# SymPy and Fraction check of the M1 content, on the pinned Python image.
# A deliberately wrong fixture file must fail first, so a checker that passes everything cannot.
set -eu
. ./tools.lock
tar -c scaffold/m1 sabotage \
    | docker run --rm -i "python@$PYTHON_IMAGE_DIGEST" sh -c '
set -eu
tar -x
pip install -q --no-cache-dir --disable-pip-version-check --root-user-action=ignore \
    --require-hashes -r scaffold/m1/requirements.lock
if python -I scaffold/m1/tests/check_problems.py scaffold/m1/problems.json sabotage/bad-fixtures.json > bad.out; then
    echo "SABOTAGE NOT CAUGHT: bad-fixtures"; exit 1
fi
grep -q "CHECKER MISMATCH: wrong root called equivalent" bad.out
python -I scaffold/m1/tally.py scaffold/m1/tests/sample-session.json     | grep -qxF "SAMPLE: completed 5 of 6, need 5, PASS; input failures 1 of 15 attempts"
python -I scaffold/m1/tests/check_problems.py scaffold/m1/problems.json scaffold/m1/tests/fixtures.json
'
