# These feed the worker's aws/config (credential_process ARNs) and the .env.

output "trust_anchor_arn" {
  description = "Roles Anywhere trust anchor ARN — put in aws/config."
  value       = aws_rolesanywhere_trust_anchor.worker.arn
}

output "profile_arn" {
  description = "Roles Anywhere profile ARN — put in aws/config."
  value       = aws_rolesanywhere_profile.worker.arn
}

output "worker_role_arn" {
  description = "Worker IAM role ARN — put in aws/config."
  value       = aws_iam_role.worker.arn
}

output "deploy_role_arn" {
  description = "GitHub Actions assumes this role (CI workflow)."
  value       = aws_iam_role.deploy.arn
}

output "bedrock_model_arn" {
  description = "The single model the worker is permitted to invoke."
  value       = local.model_arn
}

output "kms_key_arn" {
  value = aws_kms_key.paperless_ai.arn
}

# Convenience: a ready-to-paste credential_process line for aws/config.
output "aws_config_credential_process" {
  description = "Paste into ai-worker/aws/config (adjust cert/key paths)."
  value = join(" ", [
    "/usr/local/bin/aws_signing_helper credential-process",
    "--certificate /etc/aiworker/worker.crt",
    "--private-key /etc/aiworker/worker.key",
    "--trust-anchor-arn ${aws_rolesanywhere_trust_anchor.worker.arn}",
    "--profile-arn ${aws_rolesanywhere_profile.worker.arn}",
    "--role-arn ${aws_iam_role.worker.arn}",
  ])
}
