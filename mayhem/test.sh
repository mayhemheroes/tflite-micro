#!/usr/bin/env bash
#
# mayhem/test.sh — run the TFLite flatbuffer round-trip behavioral test and emit CTRF.
# Exercises unpack + repack on a real .tflite seed and asserts 5 specific output markers.
# A neutered binary (exit 0, no output) or one that skips any step fails: 0 markers ≠ 5.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

EXPECTED_MARKERS=5
BINARY=/mayhem/tflite-test
SEED=/mayhem/mayhem/tflite-flatbuffer-align/testsuite/hello_world_float.tflite

if [ ! -x "$BINARY" ]; then
  echo "tflite-test binary not found at $BINARY — build.sh did not produce it" >&2
  emit_ctrf "tflite-micro" 0 "$EXPECTED_MARKERS"
  exit 1
fi

if [ ! -f "$SEED" ]; then
  echo "Seed file not found at $SEED" >&2
  emit_ctrf "tflite-micro" 0 "$EXPECTED_MARKERS"
  exit 1
fi

# Run the test binary; capture output for marker counting
out="$("$BINARY" "$SEED" 2>&1)"; rc=$?
printf '%s\n' "$out"

# Count behavioral output markers (a neutered binary produces 0 of the 5)
# Required: magic, parse, subgraphs (>=1), operators (>=1), repack
got_magic=$(printf '%s\n' "$out" | grep -c '^magic: OK' || true)
got_parse=$(printf '%s\n' "$out" | grep -c '^parse: OK' || true)
got_subgraphs=$(printf '%s\n' "$out" | grep -cE '^subgraphs: [1-9]' || true)
got_operators=$(printf '%s\n' "$out" | grep -cE '^operators: [1-9]' || true)
got_repack=$(printf '%s\n' "$out" | grep -c '^repack: OK' || true)
got_pass=$(printf '%s\n' "$out" | grep -c '^PASS:' || true)

passed=$(( got_magic + got_parse + got_subgraphs + got_operators + got_repack ))

if [ "$rc" -eq 0 ] && [ "$passed" -eq "$EXPECTED_MARKERS" ] && [ "$got_pass" -eq 1 ]; then
  emit_ctrf "tflite-flatbuffer-roundtrip" "$EXPECTED_MARKERS" 0
else
  failed=$(( EXPECTED_MARKERS - passed ))
  [ "$failed" -lt 1 ] && failed=1
  emit_ctrf "tflite-flatbuffer-roundtrip" "$passed" "$failed"
fi
