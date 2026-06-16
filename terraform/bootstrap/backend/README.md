# Bootstrap Backend

Terraform root module that creates the S3 bucket used by the main environment's remote state backend.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.15.5, < 1.16.0 |
| aws | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | 6.47.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| environment | Deployment environment name. This bootstrap stack supports only dev. | `string` | `"dev"` | no |
| noncurrent\_state\_version\_retention\_days | Number of days to retain noncurrent Terraform state object versions. | `number` | `90` | no |
| project | Project name used for naming and tagging backend resources. | `string` | n/a | yes |
| region | AWS region for the Terraform state backend resources. | `string` | n/a | yes |
| state\_bucket\_name | Globally unique S3 bucket name used for Terraform remote state. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| state\_bucket\_arn | ARN of the S3 bucket that stores Terraform remote state. |
| state\_bucket\_name | Name of the S3 bucket that stores Terraform remote state. |
<!-- END_TF_DOCS -->
