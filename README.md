# Send OpenTelemetry traces to CloudWatch with an API key

Sample code for the blog post [Your Traces Can Now Reach CloudWatch With One Header](https://matheusarrais.com/blog/cloudwatch-otel-traces-api-key/).

Since November 2026, any OTLP/HTTP client that can set an `Authorization` header can send traces to the X-Ray OTLP traces endpoint with an API key instead of signing requests with SigV4. This repo sets up what the post recommends before you hand out a key, then sends a trace three ways: with curl, the Python SDK, and the OpenTelemetry Collector.

Use SigV4 with short-term credentials wherever you can. API keys are long-lived, and they're for workloads where short-term credentials aren't practical, such as on-premises servers, other clouds, CI/CD pipelines, and third-party tools.

## What gets deployed

| Resource | Why |
| --- | --- |
| Transaction Search, and the log resource policy it needs | The OTLP traces endpoint requires it. It's account-wide, so you can turn it off in the stack if it's already on |
| IAM user `xray-traces-api-key-user` with `AWSXRayAPIKeyAccess` | The key's owner. It can send spans and nothing else |
| Secret `xray-traces-api-key`, created empty | Where the key lives, so it stays out of config files |
| Policy `xray-api-key-issuer` | For whoever creates and rotates keys. It refuses any key with no expiry or with one longer than 90 days |
| Policy `xray-api-key-kill-switch`, not attached | Attach it to the user to block all of the user's keys at once |

The key itself isn't in the stack. CloudFormation has no resource for it, and creating it with `scripts/create-key.sh` keeps it out of templates and Terraform state.

## Pick a version

The stack is written three ways. They create the same resources, so deploy only one. Each folder's README has its deploy command, settings, outputs and clean-up.

| Version | Folder |
| --- | --- |
| CloudFormation | [`cloudformation/`](cloudformation/README.md) |
| AWS CDK in TypeScript | [`cdk/`](cdk/README.md) |
| Terraform | [`terraform/`](terraform/README.md) |

This creates real resources, and CloudWatch charges apply to the spans you send. Use a [Region that supports API keys](https://docs.aws.amazon.com/xray/latest/devguide/xray-opentelemetry-bearer-token.html), and first check whether Transaction Search is already on:

```bash
aws xray get-trace-segment-destination
```

If it returns `"Status": "ACTIVE"`, turn Transaction Search off in the stack with that version's setting, so the stack doesn't try to own it.

## Create a key and send a trace

Create a 30-day key and store it in the secret. Run this as an identity with the `xray-api-key-issuer` policy; an administrator works too.

```bash
./scripts/create-key.sh   # KEY_AGE_DAYS overrides the 30 days
```

Fetch the key and set the endpoint for your Region:

```bash
export XRAY_API_KEY="$(aws secretsmanager get-secret-value --secret-id xray-traces-api-key --query SecretString --output text)"
export XRAY_TRACES_ENDPOINT=https://xray.us-east-1.amazonaws.com/v1/traces
```

Then send a trace with any of these:

```bash
# curl, the way a CI job could
./scripts/send-with-curl.sh

# The Python SDK, sending straight to the endpoint
pip install -r app/requirements.txt
OTLP_TRACES_ENDPOINT="$XRAY_TRACES_ENDPOINT" python app/send_spans.py

# The collector, which holds the key so the app doesn't
docker compose up -d
OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces XRAY_API_KEY= python app/send_spans.py
```

Look for the `api-key-demo` services in CloudWatch. Spans can take up to 10 minutes to appear after you first turn on Transaction Search. The collector config in `collector/config.yaml` reads the key from the environment, and it shows how to read it from a mounted file instead.

## Rotate and revoke

IAM allows two X-Ray keys per user, so you can rotate without losing traces:

```bash
./scripts/rotate-key.sh new             # create a second key and update the secret
# restart your collector or app, and confirm traces still arrive
./scripts/rotate-key.sh retire <key-id> # set the old key to inactive
# confirm traces still arrive
./scripts/rotate-key.sh delete <key-id> # delete the old key
```

If a key might be compromised, attach the kill switch. It blocks every key the user has within about five minutes:

```bash
aws iam attach-user-policy --user-name xray-traces-api-key-user \
  --policy-arn "arn:aws:iam::<account-id>:policy/xray-api-key-kill-switch"
```

## Before you rely on it

- **Alert on exporter failures.** The endpoint returns HTTP 403 for an expired, inactive or invalid key, and the SDK logs it and carries on, so an expired key looks like a quiet dashboard.
- **Rotate before expiry,** on a schedule.
- **Turn on CloudTrail data events** if you want to see every use of a key. Requests made with a key are recorded with `"callWithBearerToken": true`. The stack doesn't turn them on, because they cost extra.
- **Custom log groups need more permissions.** If you send the `x-aws-log-group` and `x-aws-log-stream` headers, the user also needs permission to write to those log groups.

## Clean up

IAM won't delete a user that still has keys, so delete the keys and detach the kill switch if you attached it:

```bash
user=xray-traces-api-key-user
for id in $(aws iam list-service-specific-credentials --user-name "$user" --service-name xray.amazonaws.com \
  --query 'ServiceSpecificCredentials[].ServiceSpecificCredentialId' --output text); do
  ./scripts/rotate-key.sh delete "$id"
done
```

Then remove the stack with your version's clean-up step: [CloudFormation](cloudformation/README.md#clean-up), [CDK](cdk/README.md#clean-up) or [Terraform](terraform/README.md#clean-up).

Afterwards, run `aws xray get-trace-segment-destination` to confirm whether Transaction Search is still on.

## What CI checks

On every push, CI lints the CloudFormation template, synthesizes the CDK app, validates the Terraform and the collector config, and checks the scripts. None of it needs AWS credentials.

## Learn more

- [Setting up bearer token authentication for traces](https://docs.aws.amazon.com/xray/latest/devguide/xray-opentelemetry-bearer-token.html)
- [Enable Transaction Search](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Enable-TransactionSearch.html)
- [OTLP Endpoints](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-OTLPEndpoint.html)
- [What's New announcement](https://aws.amazon.com/about-aws/whats-new/2026/11/amazon-cloudwatch-api-keys-opentelemetry/)

This is sample code for learning, not an official AWS project. Review it before you use it in your environment.

## License

[MIT-0](LICENSE)
