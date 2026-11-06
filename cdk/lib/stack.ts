import { Aws, CfnOutput, Stack, StackProps } from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as xray from 'aws-cdk-lib/aws-xray';
import { Construct } from 'constructs';

export interface ApiKeyStackProps extends StackProps {
  enableTransactionSearch: boolean;
  maxKeyAgeDays: number;
}

// Everything an X-Ray API key needs except the key itself. scripts/create-key.sh creates the key,
// so it never lands in a template or a state file.
export class ApiKeyStack extends Stack {
  constructor(scope: Construct, id: string, props: ApiKeyStackProps) {
    super(scope, id, props);

    // Transaction Search is account-wide. The OTLP traces endpoint rejects spans until it's on.
    if (props.enableTransactionSearch) {
      const logGroup = (name: string) =>
        `arn:${Aws.PARTITION}:logs:${Aws.REGION}:${Aws.ACCOUNT_ID}:log-group:${name}:*`;
      const spansPolicy = new logs.CfnResourcePolicy(this, 'SpansResourcePolicy', {
        policyName: 'xray-transaction-search',
        policyDocument: this.toJsonString({
          Version: '2012-10-17',
          Statement: [{
            Sid: 'TransactionSearchXRayAccess',
            Effect: 'Allow',
            Principal: { Service: 'xray.amazonaws.com' },
            Action: 'logs:PutLogEvents',
            Resource: [logGroup('aws/spans'), logGroup('/aws/application-signals/data')],
            Condition: {
              ArnLike: { 'aws:SourceArn': `arn:${Aws.PARTITION}:xray:${Aws.REGION}:${Aws.ACCOUNT_ID}:*` },
              StringEquals: { 'aws:SourceAccount': Aws.ACCOUNT_ID },
            },
          }],
        }),
      });
      const search = new xray.CfnTransactionSearchConfig(this, 'TransactionSearch', { indexingPercentage: 1 });
      search.node.addDependency(spansPolicy);
    }

    // The key's owner. It can send spans and nothing else.
    const user = new iam.User(this, 'TracesUser', {
      userName: 'xray-traces-api-key-user',
      managedPolicies: [iam.ManagedPolicy.fromAwsManagedPolicyName('AWSXRayAPIKeyAccess')],
    });

    // Holds the key. It starts empty, and scripts/create-key.sh writes the value.
    const secret = new secretsmanager.CfnSecret(this, 'KeySecret', {
      name: 'xray-traces-api-key',
      description: 'X-Ray API key for xray-traces-api-key-user',
    });

    // Attach to whoever issues and rotates keys. It refuses a key with no expiry, or one longer than maxKeyAgeDays.
    const issuer = new iam.ManagedPolicy(this, 'KeyIssuerPolicy', {
      managedPolicyName: 'xray-api-key-issuer',
      statements: [
        new iam.PolicyStatement({
          sid: 'CreateOnlyExpiringXRayKeys',
          actions: ['iam:CreateServiceSpecificCredential'],
          resources: [user.userArn],
          conditions: {
            StringEquals: { 'iam:ServiceSpecificCredentialServiceName': 'xray.amazonaws.com' },
            NumericLessThanEquals: { 'iam:ServiceSpecificCredentialAgeDays': String(props.maxKeyAgeDays) },
          },
        }),
        new iam.PolicyStatement({
          sid: 'RotateAndRevokeKeys',
          actions: [
            'iam:ListServiceSpecificCredentials',
            'iam:UpdateServiceSpecificCredential',
            'iam:DeleteServiceSpecificCredential',
          ],
          resources: [user.userArn],
        }),
        new iam.PolicyStatement({
          sid: 'StoreTheKey',
          actions: ['secretsmanager:DescribeSecret', 'secretsmanager:PutSecretValue'],
          resources: [secret.ref],
        }),
      ],
    });

    // Attach to the user if a key might be compromised. It blocks every key the user has within about five minutes.
    const killSwitch = new iam.ManagedPolicy(this, 'KillSwitchPolicy', {
      managedPolicyName: 'xray-api-key-kill-switch',
      statements: [
        new iam.PolicyStatement({
          sid: 'DenyXRayApiKeys',
          effect: iam.Effect.DENY,
          actions: ['xray:CallWithBearerToken'],
          resources: ['*'],
        }),
      ],
    });

    new CfnOutput(this, 'UserName', { value: user.userName });
    new CfnOutput(this, 'SecretName', { value: 'xray-traces-api-key' });
    new CfnOutput(this, 'KeyIssuerPolicyArn', { value: issuer.managedPolicyArn });
    new CfnOutput(this, 'KillSwitchPolicyArn', { value: killSwitch.managedPolicyArn });
    new CfnOutput(this, 'TracesEndpoint', { value: `https://xray.${Aws.REGION}.amazonaws.com/v1/traces` });
  }
}
