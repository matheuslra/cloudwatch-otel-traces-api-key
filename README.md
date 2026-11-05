# Send OpenTelemetry traces to CloudWatch with an API key

Sample code for the blog post [Your Traces Can Now Reach CloudWatch With One Header](https://matheusarrais.com/blog/cloudwatch-otel-traces-api-key/).

Since November 2026, any OTLP/HTTP client that can set an `Authorization` header can send traces to the X-Ray OTLP traces endpoint with an API key instead of signing requests with SigV4. This repo shows three ways to do it, plus the IAM setup around the key.

Use SigV4 with short-term credentials wherever you can. API keys are long-lived, and they're for workloads where short-term credentials aren't practical, such as on-premises servers, other clouds, CI/CD pipelines, and third-party tools.

## What's here

| Path | What it does |
| --- | --- |
| `collector/config.yaml` | OpenTelemetry Collector using `bearertokenauth` |
| `docker-compose.yml` | Runs the collector, with an optional mock endpoint |
| `app/send_spans.py` | Python SDK sending spans through the collector or directly |
| `scripts/send-with-curl.sh` | Sends one span with only curl, as a CI job could |
| `scripts/create-key.sh` | Creates the IAM user and an expiring key, and stores the key in Secrets Manager |
| `scripts/rotate-key.sh` | Rotates a key without losing traces |
| `iam/limit-key-creation.json` | Allows keys for one user only, and only if they expire within 90 days |
| `iam/deny-api-key-use.json` | Blocks an identity from using API keys |
| `local/mock_otlp.py` | Local stand-in for the endpoint that checks the bearer token |

## Try it without an AWS account

The mock endpoint checks the bearer token and stores nothing. It needs Python 3 and has no dependencies.

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r app/requirements.txt

# Terminal 1: the mock endpoint
XRAY_API_KEY=local-test-key python local/mock_otlp.py

# Terminal 2: Python SDK, then curl
export XRAY_API_KEY=local-test-key
OTLP_TRACES_ENDPOINT=http://localhost:4319/v1/traces python app/send_spans.py
XRAY_TRACES_ENDPOINT=http://localhost:4319/v1/traces ./scripts/send-with-curl.sh

# Now try a wrong key and watch for the 403
XRAY_API_KEY=wrong OTLP_TRACES_ENDPOINT=http://localhost:4319/v1/traces python app/send_spans.py
```

To run the collector path against the mock with Docker:

```bash
XRAY_API_KEY=local-test-key XRAY_TRACES_ENDPOINT=http://mock:4319/v1/traces \
  docker compose --profile local up

# In another terminal, with no key: the collector holds it
unset XRAY_API_KEY
OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces python app/send_spans.py
```

`./local/smoke-test.sh` runs all of this at once and fails if a wrong key is accepted or the collector doesn't deliver.

## Run it against AWS

These steps create real resources in your account, and CloudWatch charges apply to the spans you send.

1. [Enable Transaction Search](https://docs.aws.amazon.com/xray/latest/devguide/xray-transactionsearch.html). The OTLP traces endpoint requires it.
2. Create the key, using AWS credentials that can manage IAM and Secrets Manager:

   ```bash
   ./scripts/create-key.sh
   ```

   `USER_NAME`, `KEY_AGE_DAYS`, and `SECRET_NAME` override the defaults. The script needs a Unix-like shell where `/dev/stdin` is available.
3. Fetch the key and set your Region's endpoint, using a [Region that supports API keys](https://docs.aws.amazon.com/xray/latest/devguide/xray-opentelemetry-bearer-token.html):

   ```bash
   export XRAY_API_KEY="$(aws secretsmanager get-secret-value --secret-id xray-traces-api-key --query SecretString --output text)"
   export XRAY_TRACES_ENDPOINT=https://xray.us-east-1.amazonaws.com/v1/traces
   ```

4. Send a trace with any of the three clients:

   ```bash
   ./scripts/send-with-curl.sh

   OTLP_TRACES_ENDPOINT="$XRAY_TRACES_ENDPOINT" python app/send_spans.py

   docker compose up   # then send to http://localhost:4318/v1/traces from another terminal, with no key
   ```

5. Look for the `api-key-demo` services in CloudWatch.

## Rotate and revoke

```bash
./scripts/rotate-key.sh new             # create a second key and update the secret
# restart your collector or app, and confirm traces still arrive
./scripts/rotate-key.sh retire <key-id> # set the old key to inactive
# confirm traces still arrive
./scripts/rotate-key.sh delete <key-id> # delete the old key
```

If a key might be compromised, set it to inactive immediately, or attach `iam/deny-api-key-use.json` to the IAM user to block all of its keys while you investigate. Changes take effect within about five minutes.

## Clean up

Delete the keys, detach the policy, delete the IAM user, and delete the secret:

```bash
user=xray-traces-api-key-user
for id in $(aws iam list-service-specific-credentials --user-name "$user" --service-name xray.amazonaws.com \
  --query 'ServiceSpecificCredentials[].ServiceSpecificCredentialId' --output text); do
  aws iam delete-service-specific-credential --user-name "$user" --service-specific-credential-id "$id"
done
aws iam detach-user-policy --user-name "$user" --policy-arn arn:aws:iam::aws:policy/AWSXRayAPIKeyAccess
aws iam delete-user --user-name "$user"
aws secretsmanager delete-secret --secret-id xray-traces-api-key
```

## Learn more

- [Setting up bearer token authentication for traces](https://docs.aws.amazon.com/xray/latest/devguide/xray-opentelemetry-bearer-token.html)
- [OTLP Endpoints](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-OTLPEndpoint.html)
- [What's New announcement](https://aws.amazon.com/about-aws/whats-new/2026/11/amazon-cloudwatch-api-keys-opentelemetry/)

This is sample code for learning, not an official AWS project. Review it before you use it in your environment.

## License

[MIT-0](LICENSE)
