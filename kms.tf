# Customer-managed key for encrypting state / logs (privacy posture).
resource "aws_kms_key" "paperless_ai" {
  description             = "paperless-ai: state and log encryption"
  deletion_window_in_days = 14
  enable_key_rotation     = true
}

resource "aws_kms_alias" "paperless_ai" {
  name          = "alias/paperless-ai"
  target_key_id = aws_kms_key.paperless_ai.key_id
}
