# paperless-ai infrastructure (Terraform)

Keyless, least-privilege AWS infra for the paperless AI worker. See the design
doc at [`../../PAPERLESS_AI_TAGGING.md`](../../PAPERLESS_AI_TAGGING.md).

## What it creates
| File | Resource |
|------|----------|
| `oidc.tf` | GitHub Actions OIDC deploy role (keyless CI), pinned to repo + branch |
| `rolesanywhere.tf` | Roles Anywhere trust anchor + profile + worker role (credential-less home worker) |
| `bedrock.tf` | Least-privilege policy: invoke EXACTLY ONE model |
| `kms.tf` | Customer-managed key for state/logs |
| `backend.tf` | S3 remote state + native locking |
| `ca/README.md` | How to make the private CA + worker cert |

## First-time setup
1. **Bootstrap state** (once): create the S3 bucket named in `backend.tf` (and optional CMK), then fill the `REPLACE-...` placeholders in `backend.tf` and `oidc.tf`.
2. **Create the CA + worker cert** — follow [`ca/README.md`](ca/README.md). Export `TF_VAR_worker_ca_cert_pem="$(cat ca/ca.crt)"`.
3. **Set vars** — copy `terraform.tfvars.example` to `terraform.tfvars` and fill `github_repo`.
4. **Deploy** — via CI (push to `main`) or locally:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
5. **Wire the worker** — `terraform output aws_config_credential_process`, paste into `../ai-worker/aws/config` (copy from `aws/config.example`), and install the cert per `ca/README.md`.
6. **Model access** — if apply can't auto-enable it, grant access to the chosen model once in the Bedrock console (Model access).

## This must live in a Git repo
`/home/peter/docker` is not a git repo. Put just this `infra/` tree (plus the CI
workflow) in a **dedicated GitHub repo** (e.g. `paperless-ai-infra`) so CI can
run — do NOT push the whole docker tree (it contains `.env` secrets). The worker
app, compose edits and design doc do not need git.
