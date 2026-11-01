#!/bin/sh
# Runs inside the image. Each bad fixture must fail with its expected message, not merely nonzero.
set -u
ran=0
passed=0

expect_failure() {
    name=$1; message=$2; shift 2
    ran=$((ran + 1))
    output=$("$@" 2>&1)
    code=$?
    if [ "$code" -ne 0 ] && printf '%s\n' "$output" | grep -qF "$message"; then
        passed=$((passed + 1))
    else
        echo "SABOTAGE NOT CAUGHT: $name (exit $code)"
        printf '%s\n' "$output"
    fi
}

expect_failure failing-lisp "FAIL deliberate" sbcl --script sabotage/failing.lisp
expect_failure failing-prolog "deliberate" swipl sabotage/failing.pl
mkdir -p /tmp/only-sbcl
ln -sf "$(command -v sbcl)" /tmp/only-sbcl/sbcl
expect_failure missing-tool "MISSING TOOL: swipl" env PATH=/tmp/only-sbcl /bin/sh scripts/versions.sh
expect_failure short-manifest "MANIFEST MISMATCH" sh ci/check-manifest.sh "COUNT lisp ran=0 passed=0" ci/manifest.txt

echo "COUNT sabotage ran=$ran passed=$passed"
[ "$ran" = "$passed" ]
