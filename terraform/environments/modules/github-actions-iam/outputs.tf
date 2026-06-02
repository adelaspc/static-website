output "frontend_deploy_role_arn" {
  value = aws_iam_role.frontend_deploy.arn
}

output "terraform_role_arn" {
  value = aws_iam_role.terraform.arn
}

output "terraform_plan_role_arn" {
  value = aws_iam_role.terraform_plan.arn
}
