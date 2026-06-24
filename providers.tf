provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "paperless-ai"
      ManagedBy = "terraform"
      Owner     = "peter"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
