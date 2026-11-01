#!/bin/sh
# Usage: check-manifest.sh "<COUNT lines>" <manifest>
# Fewer tests than the manifest fails, so a green run cannot be a vacuous one.
set -eu
counts=$1
manifest=$2
required=$(cat ci/lean_required 2>/dev/null || echo true)
[ -f "$manifest" ] || { echo "MANIFEST MISMATCH: no manifest $manifest" >&2; exit 1; }
fail=0
while read -r line; do
    [ -n "$line" ] || continue
    suite=${line%% *}
    [ "$suite" = lean ] && [ "$required" != true ] && continue
    printf '%s\n' "$counts" | grep -qxF "COUNT $line" || {
        echo "MANIFEST MISMATCH: expected $line" >&2
        fail=1
    }
done < "$manifest"
[ "$fail" = 0 ] && echo "manifest ok"
exit "$fail"
