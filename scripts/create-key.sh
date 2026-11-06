#!/usr/bin/env bash
# Give the stack's IAM user an expiring X-Ray API key, and store the key in the stack's secret.
# Run it with AWS credentials that have the xray-api-key-issuer policy. You can't manage API keys with an API key.
# The stack doesn't create the key, so the key never lands in a template, a CDK output or a Terraform state file.
set -euo pipefail

user="${USER_NAME:-xray-traces-api-key-user}"
days="${KEY_AGE_DAYS:-30}"
secret="${SECRET_NAME:-xray-traces-api-key}"

read -r key_id key < <(aws iam create-service-specific-credential \
  --user-name "$user" \
  --service-name xray.amazonaws.com \
  --credential-age-days "$days" \
  --query 'ServiceSpecificCredential.[ServiceSpecificCredentialId,ServiceCredentialSecret]' \
  --output text)
: "${key:?Could not create the API key}"

# The key goes through stdin so it stays out of the process list. AWS won't show it again.
printf '%s' "$key" | aws secretsmanager put-secret-value --secret-id "$secret" \
  --secret-string file:///dev/stdin >/dev/null

echo "Created key $key_id for $user. It expires in $days days and is stored in secret $secret."
