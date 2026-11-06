# Terraform version

The same stack as the CloudFormation version, in Terraform. It uses two providers: `hashicorp/awscc` for Transaction Search, which the `aws` provider doesn't cover, and `hashicorp/aws` for everything else: the log resource policy, the IAM user, the secret and the policies.

## Before you start

- Terraform 1.6 or later.
- AWS credentials for the target account, for example `export AWS_PROFILE=my-test-account`.

## Deploy

```bash
cd terraform
terraform init
terraform plan    # optional: see what will be created
terraform apply
```

| Variable | Default | What it does |
| --- | --- | --- |
| `region` | `us-east-1` | Where to deploy. Use a [Region that supports API keys](https://docs.aws.amazon.com/xray/latest/devguide/xray-opentelemetry-bearer-token.html) |
| `enable_transaction_search` | `true` | Set to `false` if Transaction Search is already on in this account and Region |
| `max_key_age_days` | `90` | The longest expiry the issuer policy allows on a key |

```bash
terraform apply -var enable_transaction_search=false -var max_key_age_days=30
```

The API key itself never enters Terraform state, because `scripts/create-key.sh` creates it outside Terraform. The state still holds resource names and ARNs, so keep it out of version control. `.gitignore` already excludes it.

## Outputs

```bash
terraform output
```

That lists `user_name`, `secret_name`, `key_issuer_policy_arn`, `kill_switch_policy_arn` and `traces_endpoint`. Then [create a key and send a trace](../README.md#create-a-key-and-send-a-trace).

## Clean up

Delete the user's keys first ([how](../README.md#clean-up)), because IAM won't delete a user that still has keys. Then, from `terraform/`:

```bash
terraform destroy
```
