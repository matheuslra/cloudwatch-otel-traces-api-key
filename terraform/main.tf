# Everything an X-Ray API key needs except the key itself. scripts/create-key.sh creates the key,
# so it never lands in the Terraform state.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account   = data.aws_caller_identity.current.account_id
  partition = data.aws_partition.current.partition
  user_name = "xray-traces-api-key-user"
}

# Transaction Search is account-wide. The OTLP traces endpoint rejects spans until it's on.
resource "aws_cloudwatch_log_resource_policy" "spans" {
  count       = var.enable_transaction_search ? 1 : 0
  policy_name = "xray-transaction-search"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "TransactionSearchXRayAccess"
      Effect    = "Allow"
      Principal = { Service = "xray.amazonaws.com" }
      Action    = "logs:PutLogEvents"
      Resource = [
        "arn:${local.partition}:logs:${var.region}:${local.account}:log-group:aws/spans:*",
        "arn:${local.partition}:logs:${var.region}:${local.account}:log-group:/aws/application-signals/data:*",
      ]
      Condition = {
        ArnLike      = { "aws:SourceArn" = "arn:${local.partition}:xray:${var.region}:${local.account}:*" }
        StringEquals = { "aws:SourceAccount" = local.account }
      }
    }]
  })
}

resource "awscc_xray_transaction_search_config" "this" {
  count               = var.enable_transaction_search ? 1 : 0
  indexing_percentage = 1
  depends_on          = [aws_cloudwatch_log_resource_policy.spans]
}

# The key's owner. It can send spans and nothing else.
resource "aws_iam_user" "traces" {
  name = local.user_name
}

resource "aws_iam_user_policy_attachment" "traces" {
  user       = aws_iam_user.traces.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AWSXRayAPIKeyAccess"
}

# Holds the key. It starts empty, and scripts/create-key.sh writes the value.
resource "aws_secretsmanager_secret" "key" {
  name        = "xray-traces-api-key"
  description = "X-Ray API key for ${local.user_name}"
}

# Attach to whoever issues and rotates keys. It refuses a key with no expiry, or one longer than max_key_age_days.
resource "aws_iam_policy" "issuer" {
  name = "xray-api-key-issuer"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CreateOnlyExpiringXRayKeys"
        Effect   = "Allow"
        Action   = "iam:CreateServiceSpecificCredential"
        Resource = aws_iam_user.traces.arn
        Condition = {
          StringEquals          = { "iam:ServiceSpecificCredentialServiceName" = "xray.amazonaws.com" }
          NumericLessThanEquals = { "iam:ServiceSpecificCredentialAgeDays" = tostring(var.max_key_age_days) }
        }
      },
      {
        Sid    = "RotateAndRevokeKeys"
        Effect = "Allow"
        Action = [
          "iam:ListServiceSpecificCredentials",
          "iam:UpdateServiceSpecificCredential",
          "iam:DeleteServiceSpecificCredential",
        ]
        Resource = aws_iam_user.traces.arn
      },
      {
        Sid      = "StoreTheKey"
        Effect   = "Allow"
        Action   = ["secretsmanager:DescribeSecret", "secretsmanager:PutSecretValue"]
        Resource = aws_secretsmanager_secret.key.arn
      },
    ]
  })
}

# Attach to the user if a key might be compromised. It blocks every key the user has within about five minutes.
resource "aws_iam_policy" "kill_switch" {
  name = "xray-api-key-kill-switch"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyXRayApiKeys"
      Effect   = "Deny"
      Action   = "xray:CallWithBearerToken"
      Resource = "*"
    }]
  })
}
