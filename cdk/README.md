# AWS CDK version (TypeScript)

The same stack as the CloudFormation version, written as a CDK app. `lib/stack.ts` defines the resources and `bin/app.ts` reads the settings. It deploys as the stack `xray-api-key-demo`.

## Before you start

- Node.js and npm. CI uses Node.js 24.
- A CDK-bootstrapped account and Region. If you've never used CDK there, run this once:

  ```bash
  cd cdk && npm ci && npx cdk bootstrap
  ```

## Deploy

```bash
cd cdk
npm ci
npx cdk diff      # optional: see what will be created
npx cdk deploy
```

| Context key | Default | What it does |
| --- | --- | --- |
| `enableTransactionSearch` | `true` | Set to `false` if Transaction Search is already on in this account and Region |
| `maxKeyAgeDays` | `90` | The longest expiry the issuer policy allows on a key |

```bash
npx cdk deploy -c enableTransactionSearch=false -c maxKeyAgeDays=30
```

## Outputs

`npx cdk deploy` prints `UserName`, `SecretName`, `KeyIssuerPolicyArn`, `KillSwitchPolicyArn` and `TracesEndpoint` when it finishes. Then [create a key and send a trace](../README.md#create-a-key-and-send-a-trace).

## Clean up

Delete the user's keys first ([how](../README.md#clean-up)), because IAM won't delete a user that still has keys. Then, from `cdk/`:

```bash
npx cdk destroy
```
