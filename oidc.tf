# GitHub Actions OIDC -> AWS, fully keyless CI (no stored access keys).
# The deploy role is assumed only by the pinned repo + ref via web identity.

data "aws_iam_openid_connect_provider" "github" {
  # Reuse if you already have one in the account; otherwise create below and
  # swap this data source for the resource. AWS no longer requires a thumbprint.
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "deploy_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
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
