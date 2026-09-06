#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
asobi_check_account

owned=$(asobi_aws s3api list-buckets --query "Buckets[?Name=='${ASOBI_BUCKET}'].Name" --output json)
if [[ $(jq 'length' <<< "$owned") == 0 ]]; then
  if [[ "$ASOBI_REGION" == us-east-1 ]]; then
    asobi_aws s3api create-bucket --bucket "$ASOBI_BUCKET"
  else
    asobi_aws s3api create-bucket --bucket "$ASOBI_BUCKET" \
      --create-bucket-configuration "LocationConstraint=${ASOBI_REGION}"
  fi
fi
asobi_aws s3api head-bucket --bucket "$ASOBI_BUCKET" --expected-bucket-owner "$ASOBI_ACCOUNT"
asobi_aws s3api put-public-access-block --bucket "$ASOBI_BUCKET" --expected-bucket-owner "$ASOBI_ACCOUNT" \
  --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
asobi_aws s3api put-bucket-ownership-controls --bucket "$ASOBI_BUCKET" --expected-bucket-owner "$ASOBI_ACCOUNT" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'
asobi_aws s3api put-bucket-encryption --bucket "$ASOBI_BUCKET" --expected-bucket-owner "$ASOBI_ACCOUNT" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
asobi_aws s3api put-bucket-versioning --bucket "$ASOBI_BUCKET" --expected-bucket-owner "$ASOBI_ACCOUNT" \
  --versioning-configuration Status=Enabled
policy=$(jq -n --arg bucket "$ASOBI_BUCKET" '{Version:"2012-10-17",Statement:[{Sid:"DenyInsecureTransport",Effect:"Deny",Principal:"*",Action:"s3:*",Resource:[("arn:aws:s3:::"+$bucket),("arn:aws:s3:::"+$bucket+"/*")],Condition:{Bool:{"aws:SecureTransport":"false"}}}]}')
asobi_aws s3api put-bucket-policy --bucket "$ASOBI_BUCKET" --expected-bucket-owner "$ASOBI_ACCOUNT" --policy "$policy"
asobi_aws s3api put-bucket-tagging --bucket "$ASOBI_BUCKET" --expected-bucket-owner "$ASOBI_ACCOUNT" \
  --tagging "TagSet=[{Key=Project,Value=$ASOBI_NAME},{Key=ManagedBy,Value=bootstrap-state}]"
printf 'State bucket ready: %s\n' "$ASOBI_BUCKET"
