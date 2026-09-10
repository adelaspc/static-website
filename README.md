# Static Website Hosting

[![Terraform](https://github.com/adelaspc/static-website/actions/workflows/terraform.yaml/badge.svg)](https://github.com/adelaspc/static-website/actions/workflows/terraform.yaml)
[![Deploy Frontend](https://github.com/adelaspc/static-website/actions/workflows/deploy-frontend.yaml/badge.svg)](https://github.com/adelaspc/static-website/actions/workflows/deploy-frontend.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Terraform-managed static website hosting with a private Amazon S3 origin, Amazon CloudFront, AWS Certificate Manager, Cloudflare DNS, and GitHub Actions OIDC deployments.

## Project Scope

This project is production-inspired, but it is not presented as a production-ready platform. It demonstrates realistic infrastructure patterns while intentionally keeping cost and operational complexity appropriate for a portfolio environment.

The repository intentionally deploys one `dev` environment. It does not claim staging or production support; a genuine multi-environment design would require separate Terraform root modules, state keys, GitHub Environments, deployment controls, and preferably AWS account isolation.

Implemented patterns include:

- private S3 origin access through CloudFront Origin Access Control (OAC);
- ACM certificate issuance in `us-east-1` with Cloudflare DNS validation;
- native S3 Terraform state locking;
- separate Terraform and frontend delivery workflows;
- GitHub Actions OIDC authentication without long-lived AWS credentials;
- CloudFront Standard Logging v2 to an ACL-disabled S3 bucket and CloudWatch error-rate alarms;
- explicit frontend caching and a branded HTTP 404 page.

The detailed design and accepted limitations are documented in [Architecture](docs/architecture.md) and [Checkov Trade-offs](docs/checkov-tradeoffs.md).

Repository security controls include full-history secret scanning, dependency review, GitHub Actions analysis, CodeQL for JavaScript, and pull-request checks intended for the `main` ruleset. Vulnerabilities should be reported privately according to the [Security Policy](SECURITY.md).

## Estimated Cost

This stack is intended to stay inexpensive for a low-traffic portfolio site. Exact charges depend on region, traffic, request volume, retained logs, free-tier eligibility, and any Cloudflare or domain-registration costs outside AWS. Use the [AWS Pricing Calculator](https://calculator.aws/) for a real estimate before leaving the stack running long term.

Assuming one `dev` environment, a small static site, low request volume, and less than 1 GB of website, log, and state data, the expected AWS cost is usually under a few dollars per month and can be close to zero when covered by free-tier or CloudFront free-plan allowances.

| Component | Cost behavior |
| --- | --- |
| S3 website, log, and state buckets | Usage-based storage and request charges. Versioning and CloudFront logs increase stored data until lifecycle rules expire old objects. |
| CloudFront | Usage-based or plan-based CDN pricing, depending on the active CloudFront pricing model and allowances. This project uses `PriceClass_100` to limit edge cost. |
| ACM public certificate | Non-exportable public certificates used with integrated AWS services have no additional ACM charge. |
| CloudWatch alarms | Two standard CloudFront metric alarms are configured. Standard alarm metrics are low fixed monthly charges outside applicable free-tier allowances. |
| CloudWatch Logs delivery | CloudFront Standard Logging v2 delivers logs to S3; the durable storage cost is primarily S3 log storage and requests. |
| Not provisioned by default | AWS WAF, customer-managed KMS keys, SNS notifications, cross-region replication, and multi-environment infrastructure are intentionally omitted to avoid fixed demo costs. |

Pricing references: [S3](https://aws.amazon.com/s3/pricing/), [CloudFront](https://aws.amazon.com/cloudfront/pricing/), [CloudWatch](https://aws.amazon.com/cloudwatch/pricing/), and [ACM](https://aws.amazon.com/certificate-manager/pricing/). Reviewed on 2026-06-16.

## Quick Start

### 1. Bootstrap the Remote Backend

```bash
cp terraform/bootstrap/backend/terraform.tfvars.example \
  terraform/bootstrap/backend/terraform.tfvars
terraform -chdir=terraform/bootstrap/backend init
terraform -chdir=terraform/bootstrap/backend plan
terraform -chdir=terraform/bootstrap/backend apply
```

This creates the encrypted, versioned S3 state bucket. Terraform locking uses an S3 `.tflock` object; no DynamoDB table is required.

### 2. Configure the Dev Environment

```bash
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
export CLOUDFLARE_API_TOKEN="..."
```

Populate the local `terraform.tfvars` with the real project, domain, bucket, repository, and optional alarm values.

### 3. Initialize and Apply

```bash
terraform -chdir=terraform/environments/dev init \
  -backend-config="bucket=<state-bucket-name>" \
  -backend-config="key=static-website/dev/terraform.tfstate" \
  -backend-config="region=eu-central-1" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"

terraform -chdir=terraform/environments/dev fmt -recursive
terraform -chdir=terraform/environments/dev validate
terraform -chdir=terraform/environments/dev plan
terraform -chdir=terraform/environments/dev apply
```

The first apply must use an existing AWS identity that can create IAM roles and the GitHub OIDC provider. The workflow roles cannot be used until this apply creates them. The Terraform workflow role intentionally has read-only IAM access, so later changes to the GitHub Actions roles, policies, or OIDC provider must also be applied with that privileged bootstrap identity.

### 4. Configure GitHub and Deploy

Map the Terraform outputs to the GitHub variables listed below, create the `dev` GitHub Environment, and add `CLOUDFLARE_API_TOKEN` as a repository Actions secret. The frontend can be deployed after the website bucket, CloudFront distribution, and frontend IAM role exist.

See [Bootstrap Lifecycle](docs/bootstrap.md) for the full first-run procedure and [CI/CD](docs/ci-cd.md) for workflow behavior.

## Deployment Ordering

```text
Bootstrap backend
-> First Terraform apply with an existing AWS identity
-> Configure GitHub variables, secret, and dev Environment
-> Validate Terraform configuration through GitHub Actions
-> Deploy the frontend
-> Verify DNS, HTTPS, logs, alarms, and error handling
```

The Terraform and frontend workflows are independent and use different path filters. Infrastructure changes do not automatically deploy the frontend, and frontend changes do not automatically apply Terraform.

## Required GitHub Configuration

| Name | Type | Required | Source / Example |
| --- | --- | --- | --- |
| `CLOUDFLARE_API_TOKEN` | Secret | Yes | Zone-scoped Cloudflare API token |
| `AWS_REGION` | Variable | No | Defaults to `eu-central-1` |
| `AWS_TERRAFORM_ROLE_ARN` | Variable | Yes | `github_actions_terraform_role_arn` output |
| `AWS_FRONTEND_DEPLOY_ROLE_ARN` | Variable | Yes | `github_actions_frontend_role_arn` output |
| `TF_STATE_BUCKET` | Variable | Yes | Backend bootstrap bucket name |
| `TF_STATE_KEY` | Variable | No | Defaults to `static-website/dev/terraform.tfstate` |
| `TF_PROJECT` | Variable | Yes | Terraform `project` value |
| `TF_BUCKET_NAME` | Variable | Yes | Terraform `bucket_name` value |
| `CLOUDFLARE_ZONE_NAME` | Variable | Yes | Existing Cloudflare zone name |
| `DOMAIN_ALIASES_JSON` | Variable | Yes | JSON list such as `["example.com", "www.example.com"]` |
| `S3_BUCKET_NAME` | Variable | Yes | `bucket_name` output |
| `CLOUDFRONT_DISTRIBUTION_ID` | Variable | Yes | `cloudfront_distribution_id` output |
| `WEBSITE_URL` | Variable | No | URL displayed by the frontend deployment environment |

Required reviewers are optional. Deployments pause for approval only when the `dev` GitHub Environment has that protection rule enabled.

Pull requests run static Terraform validation and frontend builds without cloud credentials, remote state, deployment variables, or the Cloudflare API token. Credentialed Terraform apply and frontend deploy jobs run only for `main` pushes or manual dispatches and target the `dev` GitHub Environment, so their secrets and variables can be environment-scoped.

Both Terraform validation and frontend CI run on every pull request targeting `main` so they can be configured as stable required checks. Push-triggered deployments retain path filters and run only when their respective source or workflow files change.

## Repository Hygiene

Never commit credentials, local state, local variable files, or generated dependency/build directories.

The repository `.gitignore` excludes:

```text
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
*.tfvars
node_modules/
dist/
```

Commit `.terraform.lock.hcl` files. They pin provider selections and improve consistency between local runs and CI.

Keep the following private:

- Cloudflare API tokens and AWS credentials;
- all real `terraform.tfvars` files;
- the bootstrap stack's local state and backups;
- downloaded state recovery files;
- generated frontend artifacts unless intentionally published.

## Destroy Behavior

Destroying the environment requires care:

- S3 buckets must be empty before Terraform can delete them.
- The backend state bucket has `prevent_destroy = true`.
- The backend must remain available while any environment still uses it.
- This stack owns the account-level GitHub Actions OIDC provider used by other projects; migrate or remove all dependent IAM roles before destroying it.
- CloudFront deletion can take several minutes.
- Deleting the website bucket also removes the object versions used for frontend rollback.

Destroy the main environment before considering backend removal. Detailed teardown and backend migration procedures are in [Bootstrap Lifecycle](docs/bootstrap.md); restoration procedures are in [Recovery](docs/recovery.md).

## Documentation

- [Architecture](docs/architecture.md): infrastructure design, security, caching, logging, monitoring, and limitations.
- [Bootstrap Lifecycle](docs/bootstrap.md): backend creation, first apply, state migration, and teardown.
- [CI/CD](docs/ci-cd.md): workflow triggers, jobs, artifacts, OIDC, and GitHub Environment behavior.
- [Operations](docs/operations.md): deployment verification, routine checks, and version policy.
- [Troubleshooting](docs/troubleshooting.md): common failures, diagnostics, and remediation.
- [Recovery](docs/recovery.md): Terraform state recovery, lock handling, and frontend rollback.
- [Checkov Trade-offs](docs/checkov-tradeoffs.md): security scan policy and accepted demo limitations.

## License

This project is available under the [MIT License](LICENSE).
