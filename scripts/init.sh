#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
asobi_check_account
umask 077
jq '{bucket: .state_bucket, key: .state_key, region: .region, profile: .aws_profile,
     allowed_account_ids: [.account_id], encrypt: true, use_lockfile: true}' \
  "$ASOBI_CONFIG" > "$ASOBI_ROOT/backend.local.json"
terraform -chdir="$ASOBI_ROOT" init -input=false -backend-config=backend.local.json "$@"
