#!/bin/sh
# Run from lean/. Allows only Lean's three standard axioms, and needs each bad file to fail.
set -u
allowed='propext|Classical.choice|Quot.sound'
ran=0
passed=0

# Reads `#print axioms` output. Fails on sorryAx or anything outside the allowed list.
audit() {
    used=$(lake env lean "$1" 2>&1)
    code=$?
    printf '%s\n' "$used"
    [ "$code" -eq 0 ] || return 1
    printf '%s\n' "$used" | grep -q "axioms" || { echo "NO AXIOM OUTPUT"; return 1; }
    leftover=$(printf '%s\n' "$used" | grep "depends on axioms" \
        | sed 's/.*axioms: \[//; s/\].*//' | tr ',' '\n' | tr -d ' ' \
        | grep -vxE "$allowed" | grep -v '^$' | sort -u)
    [ -z "$leftover" ] || { echo "FORBIDDEN AXIOM: $leftover"; return 1; }
}

expect_rejected() {
    ran=$((ran + 1))
    if out=$(audit "$1" 2>&1); then
        echo "SABOTAGE NOT CAUGHT: $1"
    elif printf '%s\n' "$out" | grep -qF "$2"; then
        passed=$((passed + 1))
    else
        echo "WRONG FAILURE: $1"
    fi
    printf '%s\n' "$out"
}

ran=$((ran + 1))
audit Audit.lean && passed=$((passed + 1))
expect_rejected sabotage/UsesSorry.lean "FORBIDDEN AXIOM: sorryAx"
expect_rejected sabotage/CustomAxiom.lean "FORBIDDEN AXIOM: everything_zero"
expect_rejected sabotage/BadCertificate.lean "ring failed"

echo "COUNT lean ran=$ran passed=$passed"
[ "$ran" = "$passed" ]
