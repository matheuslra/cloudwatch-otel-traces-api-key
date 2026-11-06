# CloudFormation version

One template, `template.yaml`, deployed with the AWS CLI. It creates everything listed in the [main README](../README.md#what-gets-deployed): Transaction Search and its log resource policy, the IAM user, the empty secret, the issuer policy and the kill switch.

## Deploy

```bash
aws cloudformation deploy --stack-name xray-api-key-demo \
  --template-file cloudformation/template.yaml --capabilities CAPABILITY_NAMED_IAM
```

`CAPABILITY_NAMED_IAM` is needed because the template gives the IAM user and the policies fixed names, which the scripts in `scripts/` rely on.

| Parameter | Default | What it does |
| --- | --- | --- |
| `EnableTransactionSearch` | `true` | Set to `false` if Transaction Search is already on in this account and Region |
| `MaxKeyAgeDays` | `90` | The longest expiry the issuer policy allows on a key |

```bash
aws cloudformation deploy --stack-name xray-api-key-demo \
  --template-file cloudformation/template.yaml --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides EnableTransactionSearch=false MaxKeyAgeDays=30
```

## Outputs

`UserName`, `SecretName`, `KeyIssuerPolicyArn`, `KillSwitchPolicyArn` and `TracesEndpoint`:

```bash
aws cloudformation describe-stacks --stack-name xray-api-key-demo --query 'Stacks[0].Outputs' --output table
```

Then [create a key and send a trace](../README.md#create-a-key-and-send-a-trace).

## Clean up

Delete the user's keys first ([how](../README.md#clean-up)), because IAM won't delete a user that still has keys. Then:

```bash
aws cloudformation delete-stack --stack-name xray-api-key-demo
aws cloudformation wait stack-delete-complete --stack-name xray-api-key-demo
```
