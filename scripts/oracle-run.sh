#!/bin/sh
# Runs inside the Python image. Each bad fixture must fail with its message before the real files run.
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

expect_failure unsound "RULE UNSOUND: bad-distribute" python oracle/check_rules.py sabotage/m2-unsound.sexp
expect_failure no-guard "RULE UNSOUND: mul-zero-unguarded" python oracle/check_rules.py sabotage/m2-no-guard.sexp
expect_failure open-guard "is not on the closed list" python oracle/check_rules.py sabotage/m2-open-guard.sexp
expect_failure decorative-guard "GUARD NOT NEEDED: transpose-add-overguarded" python oracle/check_rules.py sabotage/m2-decorative-guard.sexp
expect_failure bad-verdict "CORPUS MISMATCH: wrong root called equivalent" python oracle/check_corpus.py rules/rules.sexp corpus/solutions.json sabotage/m2-bad-verdict.json

echo "COUNT oracle-sabotage ran=$ran passed=$passed"
[ "$ran" = "$passed" ] || exit 1
python oracle/check_rules.py rules/rules.sexp
python oracle/check_corpus.py rules/rules.sexp corpus/solutions.json corpus/verdicts.json
