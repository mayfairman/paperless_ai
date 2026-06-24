# IAM Roles Anywhere: credential-less access for the home Docker worker.
# An EXTERNAL trust anchor (your own private CA cert — NOT AWS Private CA, which
# is ~$400/mo). The worker presents an X.509 leaf cert signed by that CA and
# receives short-lived STS creds. No static AWS keys exist anywhere.

resource "aws_rolesanywhere_trust_anchor" "worker" {
  name    = "paperless-ai-worker"
  enabled = true

  source {
    source_type = "CERTIFICATE_BUNDLE"
    source_data {
      x509_certificate_data = var.worker_ca_cert_pem
    }
  }
}

# Worker role: assumable ONLY via Roles Anywhere, from our trust anchor, and
# only by a cert whose CN matches the expected worker subject.
data "aws_iam_policy_document" "worker_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession", "sts:SetSourceIdentity"]

    principals {
      type        = "Service"
      identifiers = ["rolesanywhere.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_rolesanywhere_trust_anchor.worker.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalTag/x509Subject/CN"
      values   = [var.worker_cert_subject_cn]
    }
  }
}

resource "aws_iam_role" "worker" {
  name                 = "paperless-bedrock-worker"
  assume_role_policy   = data.aws_iam_policy_document.worker_assume.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "worker_bedrock" {
  name   = "invoke-bedrock-model"
  role   = aws_iam_role.worker.id
  policy = data.aws_iam_policy_document.worker_bedrock.json
}

# Profile binds the role + a tight session policy as a second layer of least
# privilege (the session can never exceed invoking the one model).
resource "aws_rolesanywhere_profile" "worker" {
  name             = "paperless-ai-worker"
  enabled          = true
  role_arns        = [aws_iam_role.worker.arn]
  duration_seconds = 3600
  session_policy   = data.aws_iam_policy_document.worker_bedrock.json
}
