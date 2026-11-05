#!/usr/bin/env bash
# Rotate without losing traces. IAM allows two X-Ray keys per user, so the old key keeps working during the swap.
#   ./scripts/rotate-key.sh new             create a second key and put it in the secret
#   (restart your collector or app so it reads the new key, and confirm traces still arrive)
#   ./scripts/rotate-key.sh retire <key-id> set the old key to inactive
#   (confirm traces still arrive)
#   ./scripts/rotate-key.sh delete <key-id> delete the old key
set -euo pipefail

user="${USER_NAME:-xray-traces-api-key-user}"
script_dir="$(cd "$(dirname "$0")" && pwd)"

case "${1:-}" in
  new)
    "$script_dir/create-key.sh"
    aws iam list-service-specific-credentials --user-name "$user" --service-name xray.amazonaws.com \
      --query 'ServiceSpecificCredentials[].[ServiceSpecificCredentialId,Status,CreateDate]' --output table
    ;;
  retire)
    aws iam update-service-specific-credential --user-name "$user" \
      --service-specific-credential-id "${2:?Pass the old key ID}" --status Inactive
    echo "Key $2 is inactive. The change takes effect within about five minutes."
    ;;
  delete)
    aws iam delete-service-specific-credential --user-name "$user" \
      --service-specific-credential-id "${2:?Pass the old key ID}"
    echo "Key $2 is deleted."
    ;;
  *)
    sed -n '2,7p' "$0"
    exit 1
    ;;
esac
