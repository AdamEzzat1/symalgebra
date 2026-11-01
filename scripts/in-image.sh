#!/bin/sh
# Run a repo script inside the image. Files go in on stdin, so no folder sharing is needed.
set -eu
tar -c --exclude=.git --exclude=.lake --exclude=results --exclude=image.tar.gz . \
    | docker run --rm -i symalgebra-ci sh -c "tar -x && sh $1"
