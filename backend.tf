# Remote state in S3 with native state locking (use_lockfile, TF >= 1.10).
# The bucket + CMK must exist before `terraform init` (bootstrap once, manually
# or via a separate tiny stack). Accessed via the same GitHub OIDC role as the
# rest of the deploy — no static keys.
#
# Fill bucket/key/region, then `terraform init`.
terraform {
  backend "s3" {
    bucket       = "mylward-paperless-ai-tfstate"
    key          = "paperless-ai/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
    # kms_key_id = "arn:aws:kms:eu-west-1:ACCOUNT_ID:key/..."  # optional CMK
  }
}
