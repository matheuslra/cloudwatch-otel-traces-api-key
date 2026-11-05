#!/usr/bin/env bash
# Create an IAM user for one integration, give it an expiring X-Ray API key, and store the key in Secrets Manager.
# Run with AWS credentials. You can't manage API keys with an API key.
set -euo pipefail

user="${USER_NAME:-xray-traces-api-key-user}"
days="${KEY_AGE_DAYS:-90}"
secret="${SECRET_NAME:-xray-traces-api-key}"

aws iam get-user --user-name "$user" >/dev/null 2>&1 || aws iam create-user --user-name "$user" >/dev/null
aws iam attach-user-policy --user-name "$user" \
  --policy-arn arn:aws:iam::aws:policy/AWSXRayAPIKeyAccess

read -r key_id key < <(aws iam create-service-specific-credential \
  --user-name "$user" \
  --service-name xray.amazonaws.com \
  --credential-age-days "$days" \
  --query 'ServiceSpecificCredential.[ServiceSpecificCredentialId,ServiceCredentialSecret]' \
  --output text)
: "${key:?Could not create the API key}"

# The key goes through stdin so it stays out of the process list. AWS won't show it again.
if aws secretsmanager describe-secret --secret-id "$secret" >/dev/null 2>&1; then
  printf '%s' "$key" | aws secretsmanager put-secret-value --secret-id "$secret" \
    --secret-string file:///dev/stdin >/dev/null
else
  printf '%s' "$key" | aws secretsmanager create-secret --name "$secret" \
    --secret-string file:///dev/stdin >/dev/null
fi

echo "Created key $key_id for $user, expires in $days days, stored in secret $secret"
