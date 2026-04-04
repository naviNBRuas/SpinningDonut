#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "[validate] ERROR: $*" >&2
  exit 1
}

echo "[validate] starting full validation"

[[ -f "src/main.asm" ]] || fail "missing src/main.asm"
[[ -f "Makefile" ]] || fail "missing Makefile"

echo "[validate] rebuilding from clean state"
make clean >/dev/null
make build >/dev/null

echo "[validate] checking binary type"
FILE_OUT="$(file donut)"
echo "$FILE_OUT"
[[ "$FILE_OUT" == *"ELF 64-bit"* ]] || fail "binary is not ELF 64-bit"
[[ "$FILE_OUT" == *"statically linked"* ]] || fail "binary is not statically linked"

echo "[validate] running smoke test"
make smoke-test >/dev/null

echo "[validate] running non-interactive output sanity check"
set +e
timeout 1s ./donut >/tmp/donut_validate_preview.txt 2>/tmp/donut_validate_err.txt
STATUS=$?
set -e
if [[ $STATUS -ne 0 && $STATUS -ne 124 && $STATUS -ne 1 ]]; then
  fail "donut execution returned unexpected code: $STATUS"
fi

PREVIEW_SIZE="$(wc -c </tmp/donut_validate_preview.txt)"
ERR_SIZE="$(wc -c </tmp/donut_validate_err.txt)"

if [[ "$STATUS" -eq 124 ]]; then
  [[ "$ERR_SIZE" -eq 0 ]] || fail "donut produced stderr output during timeout run"
else
  if [[ "$PREVIEW_SIZE" -gt 0 ]]; then
    [[ "$ERR_SIZE" -eq 0 ]] || fail "donut produced stderr output in nominal run"
  elif [[ "$STATUS" -eq 1 ]]; then
    grep -q "\[donut\] fatal runtime error" /tmp/donut_validate_err.txt \
      || fail "expected graceful fatal error message not found"
  else
    fail "unexpected output/status combination: status=$STATUS stdout=$PREVIEW_SIZE stderr=$ERR_SIZE"
  fi
fi

echo "[validate] stdout bytes: $PREVIEW_SIZE"
echo "[validate] stderr bytes: $ERR_SIZE"

echo "[validate] generating package and checksum verification"
make package >/dev/null
sha256sum -c dist/SHA256SUMS.txt >/dev/null

echo "[validate] all checks passed"
