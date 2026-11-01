#!/bin/sh
# Load the cached image, or build and save it. The cache key is the Dockerfile hash.
set -eu
if [ -f image.tar.gz ]; then
    gunzip -c image.tar.gz | docker load
else
    docker build -t symalgebra-ci .
    docker save symalgebra-ci | gzip -1 > image.tar.gz
fi
