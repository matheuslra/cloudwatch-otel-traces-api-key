#!/usr/bin/env bash
# Run every client against the mock endpoint, with no AWS account. Needs Docker and app/requirements.txt.
set -euo pipefail

export XRAY_API_KEY=local-test-key
export XRAY_TRACES_ENDPOINT=http://mock:4319/v1/traces
mock_url=http://127.0.0.1:4319/v1/traces

trap 'docker compose --profile local down' EXIT
docker compose --profile local up -d

for port in 4319 4318; do
  for _ in $(seq 1 30); do
    curl -s -o /dev/null "http://127.0.0.1:$port/" && break
    sleep 2
  done
done

echo "curl with the right key is accepted"
XRAY_TRACES_ENDPOINT=$mock_url ./scripts/send-with-curl.sh

echo "curl with a wrong key is rejected"
if XRAY_API_KEY=wrong XRAY_TRACES_ENDPOINT=$mock_url ./scripts/send-with-curl.sh; then
  echo "FAIL: the mock accepted a wrong key"
  exit 1
fi

echo "SDK spans reach the mock through the collector, which holds the key"
env -u XRAY_API_KEY OTLP_TRACES_ENDPOINT=http://127.0.0.1:4318/v1/traces python app/send_spans.py
for _ in $(seq 1 30); do
  if docker compose --profile local logs mock | grep -q '200 /v1/traces application/x-protobuf'; then
    echo "Smoke test passed"
    exit 0
  fi
  sleep 2
done

echo "FAIL: the collector never delivered spans with a valid key"
docker compose --profile local logs
exit 1
