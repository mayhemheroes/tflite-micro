# syntax=docker/dockerfile:1.7
#
# Commit-image Dockerfile for tflite-micro — builds the TFLite flatbuffer fuzz harness.
# Uses the org C/C++ base image (clang/libFuzzer pre-installed). Flatbuffers v25.9.23 headers
# are pre-baked at /opt/flatbuffers/include so build.sh runs air-gapped (--network none).
#
# Build (from repo root):
#   DOCKER_BUILDKIT=1 docker build -f mayhem/Dockerfile \
#       --build-arg COMMIT=$(git rev-parse HEAD) \
#       -t tflite-micro-commit .

FROM ghcr.io/mayhemheroes/base:20260621

ARG COMMIT
ARG REPO_URL
ARG SOURCE_DATE_EPOCH
ARG SANITIZER_FLAGS
ARG COVERAGE_FLAGS=
ARG MAYHEM_JOBS=

# Install flatbuffers v25.9.23 headers (header-only for the flatbuffer core API used by the harness)
# The schema_generated.h in the repo was generated against exactly this version.
USER root
RUN apt-get update && apt-get install -yq --no-install-recommends wget \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/flatbuffers/include \
    && wget -qO /tmp/flatbuffers.tar.gz \
        https://github.com/google/flatbuffers/archive/v25.9.23.tar.gz \
    && tar -xzf /tmp/flatbuffers.tar.gz -C /tmp \
    && cp -r /tmp/flatbuffers-25.9.23/include/flatbuffers /opt/flatbuffers/include/ \
    && rm -rf /tmp/flatbuffers*

USER mayhem
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN bash mayhem/build.sh

RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh — skipping"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
