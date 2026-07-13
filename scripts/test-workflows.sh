#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ACT_BIN="${ACT_BIN:-.tools/bin/act}"
ACTIONLINT_BIN="${ACTIONLINT_BIN:-.tools/bin/actionlint}"

fail() {
  echo "[wf-test] ERROR: $*" >&2
  exit 1
}

echo "[wf-test] linting workflows"
[[ -x "$ACTIONLINT_BIN" ]] || fail "actionlint not found at $ACTIONLINT_BIN"
"$ACTIONLINT_BIN" .github/workflows/*.yml

echo "[wf-test] running project verification"
make verify >/dev/null

echo "[wf-test] checking act availability"
[[ -x "$ACT_BIN" ]] || fail "act not found at $ACT_BIN"

if command -v docker >/dev/null 2>&1; then
  echo "[wf-test] docker detected, running act dry-runs"
  printf '{"inputs":{"tag":"v1.2.3","prerelease":"false","make_latest":"true"}}' > .tools/tmp/release-event.json
  "$ACT_BIN" -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest push -n >/dev/null
  "$ACT_BIN" -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest workflow_dispatch -n -e .tools/tmp/release-event.json >/dev/null
else
  echo "[wf-test] docker not detected, skipping act execution and running shell-level release simulation"
fi

SIM_ROOT=".tools/tmp/release-sim"
SIM_REMOTE=".tools/tmp/release-remote.git"
rm -rf "$SIM_ROOT" "$SIM_REMOTE"
mkdir -p "$SIM_ROOT"

tar --exclude="$SIM_ROOT" --exclude="./.git" -cf - . | tar -C "$SIM_ROOT" -xf -

pushd "$SIM_ROOT" >/dev/null
git init -q
git config user.name "Local Workflow Tester"
git config user.email "local@test.invalid"
git add .
git commit -q -m "test snapshot"

git init -q --bare ../release-remote.git
git remote add origin "$(pwd)/../release-remote.git"
git push -q -u origin HEAD:main

TAG="v1.2.3"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z]+)*$ ]] || fail "tag format check failed"

make verify >/dev/null

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "[wf-test] tag $TAG already exists"
else
  git tag -m "$TAG" "$TAG"
  echo "[wf-test] created local tag $TAG"
fi

git push origin "$TAG" >/dev/null
echo "[wf-test] pushed tag to simulated origin"

ls -lah dist
sha256sum -c dist/SHA256SUMS.txt >/dev/null
popd >/dev/null

echo "[wf-test] workflow tests passed"
