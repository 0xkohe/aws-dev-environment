#!/usr/bin/env bash
# Shared only by this project's scripts. No credentials are stored here.
set -euo pipefail
ASOBI_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ASOBI_CONFIG=${ASOBI_CONFIG:-$ASOBI_ROOT/config.auto.tfvars.json}
[[ -f "$ASOBI_CONFIG" ]] || { printf 'Copy config.example.json to config.auto.tfvars.json and edit it first.\n' >&2; exit 1; }
ASOBI_ACCOUNT=$(jq -er '.account_id | select(test("^[0-9]{12}$"))' "$ASOBI_CONFIG")
ASOBI_REGION=$(jq -er '.region | select(test("^[a-z0-9-]+$"))' "$ASOBI_CONFIG")
ASOBI_PROFILE=$(jq -er '.aws_profile | select(test("^[A-Za-z0-9_-]+$"))' "$ASOBI_CONFIG")
ASOBI_BUCKET=$(jq -er '.state_bucket | select(test("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$"))' "$ASOBI_CONFIG")
ASOBI_NAME=$(jq -er '.name | select(test("^[a-z][a-z0-9-]{0,39}$"))' "$ASOBI_CONFIG")
export AWS_PAGER=""

asobi_aws() {
  aws --profile "$ASOBI_PROFILE" --region "$ASOBI_REGION" "$@"
}
asobi_check_account() {
  local account
  account=$(asobi_aws sts get-caller-identity --query Account --output text)
  if [[ "$account" != "$ASOBI_ACCOUNT" ]]; then
    printf 'Wrong AWS account: %s (expected %s)\n' "$account" "$ASOBI_ACCOUNT" >&2
    exit 1
  fi
}
asobi_instance() {
  local instances
  instances=$(asobi_aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=$ASOBI_NAME" "Name=tag:Name,Values=$ASOBI_NAME" \
    Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'Reservations[].Instances[].InstanceId' --output json)
  if [[ $(jq 'length' <<< "$instances") != 1 ]]; then
    printf 'Expected exactly one %s instance; found: %s\n' "$ASOBI_NAME" "$instances" >&2
    exit 1
  fi
  jq -r '.[0]' <<< "$instances"
}
