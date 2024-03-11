# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
data "aws_caller_identity" "current" {}

output "account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS Account ID number of the account that owns or contains the calling entity."
}

output "caller_arn" {
  value       = data.aws_caller_identity.current.arn
  description = "ARN associated with the calling entity."
}

output "caller_user" {
  value       = data.aws_caller_identity.current.user_id
  description = "Unique identifier of the calling entity."
}
