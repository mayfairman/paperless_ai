variable "aws_region" {
  description = "Bedrock region. In-Region only (no Global cross-region profiles) for EU data residency."
  type        = string
  default     = "eu-west-1"
}

variable "bedrock_model_id" {
  description = "On-demand Bedrock model id the worker may invoke (the ONLY model it can call)."
  type        = string
  default     = "mistral.mixtral-8x7b-instruct-v0:1"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the deploy role, as 'owner/name'."
  type        = string
  # e.g. "petermylward/paperless-ai-infra"
}

variable "github_deploy_ref" {
  description = "Git ref allowed to deploy (sub claim). Pins CI to one branch."
  type        = string
  default     = "ref:refs/heads/main"
}

variable "worker_ca_cert_pem" {
  description = <<-EOT
    PEM of YOUR private CA certificate used as the Roles Anywhere external trust
    anchor. This is the CA cert only (never the CA key). Generate it offline
    (see ca/README.md). Provide via TF_VAR_worker_ca_cert_pem or a tfvars file
    that is NOT committed.
  EOT
  type        = string
}

variable "worker_cert_subject_cn" {
  description = "Expected CN on the worker leaf cert; constrains who can assume the role."
  type        = string
  default     = "paperless-ai-worker"
}
