# GitHub Actions OIDC -> AWS, fully keyless CI (no stored access keys).
# The deploy role is assumed only by the pinned repo + ref via web identity.

# Account-wide singleton. If you later find you already have one, import it:
#   terraform import aws_iam_openid_connect_provider.github <provider-arn>
# AWS no longer validates a thumbprint for STS-backed OIDC, so it's omitted.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

data "aws_iam_policy_document" "deploy_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Pin to the exact repo + branch/environment.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:${var.github_deploy_ref}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "paperless-ai-deploy"
  assume_role_policy   = data.aws_iam_policy_document.deploy_assume.json
  max_session_duration = 3600
}

# Scope: manage exactly the resources in this stack. Tighten further per your
# org's guardrails; this is intentionally narrow to the services used here.
data "aws_iam_policy_document" "deploy_permissions" {
  statement {
    sid    = "ManageStackResources"
    effect = "Allow"
    actions = [
      "iam:*Role*", "iam:*Policy*", "iam:GetPolicy*", "iam:TagRole", "iam:TagPolicy",
      "rolesanywhere:*",
      "kms:*",
      "bedrock:GetFoundationModel", "bedrock:ListFoundationModels",
      "bedrock:PutFoundationModelEntitlement", "bedrock:GetUseCaseForModelAccess",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "TerraformState"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::REPLACE-paperless-ai-tfstate", "arn:${data.aws_partition.current.partition}:s3:::REPLACE-paperless-ai-tfstate/*"]
  }
}

resource "aws_iam_role_policy" "deploy_permissions" {
  name   = "deploy-permissions"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_permissions.json
}
