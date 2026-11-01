# The M1 site only: SBCL plus scaffold/m1, run as an unprivileged user. Build from the repository
# root. The SBCL stage matches ../Dockerfile, so both use the pins in tools.lock.
FROM swipl:10.0.2@sha256:652375a3cbfd2ecbfa4f30b218d22b3c5fb3e60433996093125512fd023ad375 AS sbcl-build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bzip2 ca-certificates curl gcc libc6-dev make sbcl zlib1g-dev \
    && curl -fsSL -o /tmp/sbcl.tar.bz2 \
       https://downloads.sourceforge.net/project/sbcl/sbcl/2.6.9/sbcl-2.6.9-source.tar.bz2 \
    && echo "c6fd1d735570eb4ff34caf9609988ca77ed0bd12b55d09a4fed075be890da513  /tmp/sbcl.tar.bz2" \
       | sha256sum -c - \
    && tar -xjf /tmp/sbcl.tar.bz2 -C /tmp \
    && cd /tmp/sbcl-2.6.9 \
    && sh make.sh --prefix=/usr/local \
    && apt-get purge -y sbcl \
    && sh install.sh

FROM swipl:10.0.2@sha256:652375a3cbfd2ecbfa4f30b218d22b3c5fb3e60433996093125512fd023ad375

COPY --from=sbcl-build /usr/local/bin/sbcl /usr/local/bin/sbcl
COPY --from=sbcl-build /usr/local/lib/sbcl /usr/local/lib/sbcl
COPY scaffold/m1 /site

USER nobody
ENV PORT=8080
EXPOSE 8080
CMD ["sbcl", "--script", "/site/server.lisp"]
