#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d /tmp/asobi-tests.XXXXXX)
export PATH="$repo/tests/mock-bin:$PATH"
export ASOBI_TEST_LOG="$scratch/aws.log"
export ASOBI_CONFIG="$repo/config.example.json"

for scenario in wrong-account missing ambiguous; do
  export ASOBI_TEST_SCENARIO="$scenario"
  : > "$ASOBI_TEST_LOG"
  if "$repo/scripts/asobi" stop > "$scratch/output" 2>&1; then
    printf 'FAIL: stop accepted %s\n' "$scenario" >&2
    exit 1
  fi
  if grep -q 'stop-instances' "$ASOBI_TEST_LOG"; then
    printf 'FAIL: attempted a mutation for %s\n' "$scenario" >&2
    exit 1
  fi
  printf 'PASS: stop rejects %s without mutation\n' "$scenario"
done

export ASOBI_TEST_SCENARIO=running
: > "$ASOBI_TEST_LOG"
if "$repo/scripts/asobi" snapshot > "$scratch/output" 2>&1; then
  printf 'FAIL: snapshot accepted a running instance\n' >&2
  exit 1
fi
if grep -q 'create-snapshot' "$ASOBI_TEST_LOG"; then
  printf 'FAIL: attempted snapshot of a running instance\n' >&2
  exit 1
fi
printf 'PASS: snapshot requires a stopped instance\n'

: > "$ASOBI_TEST_LOG"
if "$repo/scripts/asobi" destroy > "$scratch/output" 2>&1; then
  printf 'FAIL: unknown operation accepted\n' >&2
  exit 1
fi
test ! -s "$ASOBI_TEST_LOG"
printf 'PASS: unknown operation rejected before AWS access\n'

# Configuration must actually reach AWS calls; failures alone could hide a broken loader.
jq '.name = "other-dev" | .aws_profile = "other-profile" | .region = "us-east-1"' \
  "$repo/config.example.json" > "$scratch/config.json"
export ASOBI_CONFIG="$scratch/config.json"
: > "$ASOBI_TEST_LOG"
"$repo/scripts/asobi" status > "$scratch/output" 2>&1
grep -q -- '--profile other-profile --region us-east-1' "$ASOBI_TEST_LOG"
grep -q 'Name=tag:Project,Values=other-dev' "$ASOBI_TEST_LOG"
grep -q 'Name=tag:Name,Values=other-dev' "$ASOBI_TEST_LOG"
printf 'PASS: account, profile, region and tags come from the selected configuration\n'

export ASOBI_CONFIG="$scratch/nonexistent.json"
: > "$ASOBI_TEST_LOG"
if "$repo/scripts/asobi" stop > "$scratch/output" 2>&1; then
  printf 'FAIL: missing configuration accepted\n' >&2
  exit 1
fi
test ! -s "$ASOBI_TEST_LOG"
printf 'PASS: missing configuration rejected before AWS access\n'
