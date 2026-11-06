import { App } from 'aws-cdk-lib';
import { ApiKeyStack } from '../lib/stack';

const app = new App();

// Override with -c enableTransactionSearch=false or -c maxKeyAgeDays=30.
new ApiKeyStack(app, 'XRayApiKeyDemo', {
  stackName: 'xray-api-key-demo',
  enableTransactionSearch: String(app.node.tryGetContext('enableTransactionSearch') ?? 'true') !== 'false',
  maxKeyAgeDays: Number(app.node.tryGetContext('maxKeyAgeDays') ?? 90),
});
