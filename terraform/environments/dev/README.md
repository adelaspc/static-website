# Dev Environment

Terraform root module for the single supported `dev` static website environment.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10, < 2.0 |
| aws | ~> 6.0 |
| cloudflare | ~> 5.0 |
| tls | ~> 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | 6.47.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| acm\_certificate | ../modules/acm-cloudflare | n/a |
| cloudflare\_dns | ../modules/cloudflare-dns | n/a |
| cloudfront | ../modules/cloudfront | n/a |
| github\_actions\_iam | ../modules/github-actions-iam | n/a |
| monitoring | ../modules/monitoring | n/a |
| s3 | ../modules/s3 | n/a |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| bucket\_name | Environment-specific component used with project to build the final S3 bucket names. | `string` | n/a | yes |
| cloudflare\_zone\_name | Cloudflare zone name that contains the DNS records. | `string` | n/a | yes |
| cloudfront\_4xx\_error\_rate\_threshold | CloudFront 4xx error rate percentage threshold for the monitoring alarm. | `number` | `5` | no |
| cloudfront\_5xx\_error\_rate\_threshold | CloudFront 5xx error rate percentage threshold for the monitoring alarm. | `number` | `1` | no |
| cloudwatch\_alarm\_actions | SNS topic ARNs or other CloudWatch alarm action ARNs invoked when CloudFront alarms enter ALARM state. | `list(string)` | `[]` | no |
| cloudwatch\_ok\_actions | SNS topic ARNs or other CloudWatch alarm action ARNs invoked when CloudFront alarms return to OK state. | `list(string)` | `[]` | no |
| domain\_aliases | Domain names served by the CloudFront distribution and Cloudflare DNS records. | `list(string)` | n/a | yes |
| environment | Deployment environment name. This root module supports only dev. | `string` | `"dev"` | no |
| github\_repository | GitHub repository allowed to assume the GitHub Actions IAM roles, in owner/repo format. | `string` | n/a | yes |
| project | Project name used for naming and tagging resources. | `string` | n/a | yes |
| region | AWS region for regional resources. | `string` | n/a | yes |
| terraform\_state\_bucket\_name | S3 bucket name used by the Terraform remote backend. | `string` | n/a | yes |
| terraform\_state\_key | S3 object key used by the Terraform remote backend for this environment. | `string` | `"static-website/dev/terraform.tfstate"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bucket\_name | Name of the S3 bucket receiving frontend deployment artifacts. |
| cloudfront\_4xx\_alarm\_name | Name of the CloudWatch alarm monitoring CloudFront 4xx errors. |
| cloudfront\_5xx\_alarm\_name | Name of the CloudWatch alarm monitoring CloudFront 5xx errors. |
| cloudfront\_distribution\_id | CloudFront distribution ID used for deployment invalidations. |
| cloudfront\_domain\_name | CloudFront-assigned domain name for the website distribution. |
| cloudfront\_logs\_bucket\_name | Name of the S3 bucket that stores CloudFront Standard Logging v2 access logs. |
| github\_actions\_frontend\_role\_arn | ARN of the GitHub Actions role used by the frontend deployment workflow. |
| github\_actions\_terraform\_permissions\_boundary\_arn | ARN of the permissions boundary attached to the Terraform workflow role. |
| github\_actions\_terraform\_role\_arn | ARN of the GitHub Actions role used by the Terraform apply workflow. |
| website\_urls | Public HTTPS URLs configured for the website. |
<!-- END_TF_DOCS -->
