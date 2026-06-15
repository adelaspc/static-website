output "frontend_deploy_role_arn" {
  description = "ARN of the GitHub Actions role used to deploy frontend assets."
  value       = aws_iam_role.frontend_deploy.arn
}

output "terraform_role_arn" {
  description = "ARN of the GitHub Actions role used to apply non-IAM Terraform changes."
  value       = aws_iam_role.terraform.arn
}

output "terraform_permissions_boundary_arn" {
  description = "ARN of the permissions boundary attached to the GitHub Actions Terraform role."
  value       = aws_iam_policy.terraform_boundary.arn
}
