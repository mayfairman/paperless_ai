# Least-privilege Bedrock policy: the worker may invoke EXACTLY ONE model, in
# this region, and nothing else. Used both as the worker role's inline policy
# and as the Roles Anywhere profile session policy (defence in depth).

locals {
  model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
}

data "aws_iam_policy_document" "worker_bedrock" {
  statement {
    sid       = "InvokeSingleModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = [local.model_arn]
  }
}

# NOTE: open-weights models on Bedrock require one-time model access to be
# granted in the console (Bedrock -> Model access) or via the entitlement API.
# Terraform can't always toggle this for every model; if `terraform apply`
# can't enable it, enable it once in the console for the chosen model.
