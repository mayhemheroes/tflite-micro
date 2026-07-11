#!/usr/bin/env bash
#
# mayhem/build.sh — build the tflite-micro fuzz harness (+ standalone reproducer) and test suite.
# TFLite schema is header-only (schema_generated.h + flatbuffers headers, both pre-baked in image).
# No Bazel needed: we compile the harness directly with clang using the installed headers.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
# SanitizerCoverage on the schema + flatbuffers parsing paths so libFuzzer gets real coverage signal.
: "${FUZZ_COV:=-fsanitize=fuzzer-no-link}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE STANDALONE_FUZZ_MAIN \
       FUZZ_COV MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

FLATBUFFERS_INC=/opt/flatbuffers/include

# Verify the pre-baked flatbuffers headers are present (Dockerfile step failed if missing)
if [ ! -f "$FLATBUFFERS_INC/flatbuffers/flatbuffers.h" ]; then
  echo "ERROR: flatbuffers headers not found at $FLATBUFFERS_INC" >&2
  exit 1
fi

# 1) Compile the libFuzzer harness (with ASan+UBSan+sancov instrumentation for coverage)
#    -fsanitize=fuzzer-no-link instruments the TFLite/flatbuffers header code for coverage
#    $LIB_FUZZING_ENGINE=-fsanitize=fuzzer links the libFuzzer main
$CXX $SANITIZER_FLAGS $FUZZ_COV $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
    -std=c++17 \
    -I"$FLATBUFFERS_INC" \
    -I"$SRC" \
    "$SRC/mayhem/tflite_flatbuffer_align_fuzz.cc" \
    -o /mayhem/tflite-flatbuffer-align

# 2) Compile standalone reproducer (takes a file, runs LLVMFuzzerTestOneInput once, exits)
$CC $SANITIZER_FLAGS $DEBUG_FLAGS \
    -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main.o

$CXX $SANITIZER_FLAGS $DEBUG_FLAGS \
    -std=c++17 \
    -I"$FLATBUFFERS_INC" \
    -I"$SRC" \
    /tmp/standalone_main.o \
    "$SRC/mayhem/tflite_flatbuffer_align_fuzz.cc" \
    -o /mayhem/tflite-flatbuffer-align-standalone

# 3) Build the behavioral test binary with NORMAL flags (Debug, no sanitizers, no fuzzer engine)
#    Built Debug so any assert()s are live; COVERAGE_FLAGS empty by default (no effect).
$CXX -O0 -g -DDEBUG $COVERAGE_FLAGS \
    -std=c++17 \
    -I"$FLATBUFFERS_INC" \
    -I"$SRC" \
    "$SRC/mayhem/test_tflite.cpp" \
    -o /mayhem/tflite-test

echo "Build complete: tflite-flatbuffer-align, tflite-flatbuffer-align-standalone, tflite-test"
