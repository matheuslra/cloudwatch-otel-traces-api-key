output "user_name" {
  value = aws_iam_user.traces.name
}

output "secret_name" {
  value = aws_secretsmanager_secret.key.name
}

output "key_issuer_policy_arn" {
  value = aws_iam_policy.issuer.arn
}

output "kill_switch_policy_arn" {
  value = aws_iam_policy.kill_switch.arn
}

output "traces_endpoint" {
  value = "https://xray.${var.region}.amazonaws.com/v1/traces"
}
