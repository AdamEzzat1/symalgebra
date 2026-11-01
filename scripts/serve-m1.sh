#!/bin/sh
# Run the M1 scaffold from the pinned image on port 8080, reachable from the LAN.
set -eu
tar -c --exclude=.git --exclude=.lake --exclude=results --exclude=image.tar.gz . \
    | docker run --rm -i -p 8080:8080 symalgebra-ci sh -c "tar -x && exec sbcl --script scaffold/m1/server.lisp"
