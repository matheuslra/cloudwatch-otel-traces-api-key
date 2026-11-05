#!/usr/bin/env bash
# Send one span as OTLP JSON with nothing but curl, the way a CI job or a small script could.
set -euo pipefail

: "${XRAY_API_KEY:?Set XRAY_API_KEY}"
endpoint="${XRAY_TRACES_ENDPOINT:-https://xray.us-east-1.amazonaws.com/v1/traces}"

trace_id="$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')"
span_id="$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')"
end_ns="$(date +%s)000000000"
start_ns="$(( $(date +%s) - 1 ))000000000"

payload="$(cat <<EOF
{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"api-key-demo-curl"}}]},
"scopeSpans":[{"scope":{"name":"send-with-curl"},"spans":[{"traceId":"$trace_id","spanId":"$span_id","name":"deploy","kind":1,
"startTimeUnixNano":"$start_ns","endTimeUnixNano":"$end_ns"}]}]}]}
EOF
)"

# The header goes through stdin so the key stays out of the process list.
status="$(printf 'Authorization: Bearer %s\n' "$XRAY_API_KEY" | curl -sS -o /dev/null -w '%{http_code}' \
  -X POST "$endpoint" -H 'Content-Type: application/json' -H @- -d "$payload")"

echo "HTTP $status from $endpoint (trace $trace_id)"
[ "$status" = "200" ]
