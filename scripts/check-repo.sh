#!/bin/sh
# Pins, executable bits and line endings. Runs on the host, where git is present.
set -eu
. ./tools.lock
fail=0
bad() { echo "PIN CHECK: $1" >&2; fail=1; }

for image in Dockerfile deploy/site.Dockerfile; do
    grep -q "$SWIPL_IMAGE_DIGEST" "$image" || bad "$image swipl digest differs from tools.lock"
    grep -q "swipl:$SWIPL_VERSION@" "$image" || bad "$image swipl version differs from tools.lock"
    grep -q "$SBCL_TARBALL_SHA256" "$image" || bad "$image SBCL checksum differs from tools.lock"
    grep -q "sbcl-$SBCL_VERSION-" "$image" || bad "$image SBCL version differs from tools.lock"
done
[ "$(tr -d '\r\n' < lean/lean-toolchain)" = "$LEAN_TOOLCHAIN" ] || bad "lean-toolchain differs from tools.lock"
grep -q "\"rev\": \"$MATHLIB_COMMIT\"" lean/lake-manifest.json || bad "lake-manifest Mathlib rev differs from tools.lock"

# Every action must be pinned by a full commit SHA.
if grep -hE '^[[:space:]-]*uses:' .github/workflows/*.yml | grep -vE '@[0-9a-f]{40}([[:space:]]|$)'; then
    bad "workflow action not pinned by SHA"
fi

for f in $(git ls-files '*.sh'); do
    mode=$(git ls-files -s "$f" | cut -c1-6)
    [ "$mode" = 100755 ] || bad "$f is not executable in git"
done

for f in $(git ls-files --eol | awk '$2 == "w/crlf" {print $NF}'); do
    bad "$f has CRLF endings"
done

[ "$fail" = 0 ] || exit 1
echo "COUNT repo ran=1 passed=1"
