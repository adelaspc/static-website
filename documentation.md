# Static Website Hosting

Terraform configuration for hosting a private S3 static website behind Amazon CloudFront, secured with Origin Access Control, HTTPS through AWS ACM, and DNS managed in Cloudflare.

The project provisions the infrastructure required for a production-style static frontend deployment, including private S3 storage, CloudFront distribution, Cloudflare DNS records, GitHub Actions OIDC authentication, access logging, monitoring, and CI/CD deployment workflows.

## Architecture

The website is hosted using the following architecture:

- Amazon S3 stores the built static website files.
- The website bucket blocks all public access.
- Amazon CloudFront serves the website over HTTPS.
- CloudFront uses Origin Access Control to securely access the private S3 bucket.
- AWS ACM provisions a public TLS certificate in `us-east-1`, required for CloudFront custom
domains.
- Cloudflare remains the authoritative DNS provider and creates DNS-only CNAME records
pointing to the CloudFront distribution.
- GitHub Actions deploys the built frontend artifact to S3 and invalidates the CloudFront cache.
- AWS access from GitHub Actions uses OIDC and IAM roles managed by Terraform.
- A dedicated S3 bucket stores CloudFront standard access logs.
- CloudWatch alarms monitor CloudFront 4xx and 5xx error rates.
- CloudFront maps 403 and 404 responses to /index.html to support static frontend routing.

> Note: The S3 origin is configured as a private S3 bucket origin, not as an S3 static website endpoint. This is required for the Origin Access Control setup.

## What this demonstrates

This project demonstrates:

- Terraform module design for a realistic static website platform.
- Secure private-origin hosting with S3, CloudFront, and Origin Access Control.
- DNS and certificate automation across AWS ACM and Cloudflare.
- Remote Terraform state with S3 backend lockfiles.
- CI/CD separation between infrastructure provisioning and frontend deployment.
- GitHub Actions OIDC authentication without long-lived AWS access keys.
- Pull request validation with Terraform plan, TFLint, and Checkov.
- Controlled production deployment through GitHub Environment approvals.
- Practical caching using content-hashed frontend assets.
- Basic operational visibility through CloudWatch alarms and CloudFront logs.

## DNS design

Cloudflare is used as the authoritative DNS provider for this project. The Terraform configuration creates Cloudflare DNS records that point the configured domain names to the CloudFront distribution. These records are configured as DNS-only, so Cloudflare only resolves DNS and does not proxy traffic through the Cloudflare network. This keeps the request path simple:

> User → Cloudflare DNS → CloudFront → private S3 bucket

CloudFront remains responsible for HTTPS termination, caching, routing, and secure origin access.

## Certificate Validation

The ACM certificate used by CloudFront must be created in `us-east-1`, even if the rest of the infrastructure is deployed in another AWS region. Terraform uses an aliased AWS provider for `us-east-1` to create and validate the CloudFront certificate. DNS validation records are created in Cloudflare automatically. The certificate is a standard non-exportable ACM public certificate. For this CloudFront use case, ACM public certificates are not charged separately.

## ACM Certificate Validation Flow

## Terraform Provisioning Workflow

## Frontend deployment Workflow

## Prerequisites

Before using this project you need:

- An AWS account.
- A Cloudflare account.
- A domain managed by Cloudflare DNS.
- Terraform installed locally.
- A GitHub repository for the project.
- GitHub Actions enabled.
- A Cloudflare API token with permissions to manage DNS records.
- AWS credentials available locally for the initial Terraform bootstrap.

## Remote Backend Bootstrap

First, bootstrap the Terraform remote backend:

```
cd terraform/bootstrap/backend
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

This creates the S3 bucket used by Terraform for remote state storage. State locking uses an S3 `.tflock` object.

## Environment Configuration

After the backend is created, configure the environment variables for the development environment:

```
cp terraform/environments/dev/terraform.tfvars.example terraform/ environments/dev/terraform.tfvars
```

Update terraform/environments/dev/terraform.tfvars with the real values for the project, such as:
- AWS region
- Project name
- Domain name
- Alternate domain names
- Cloudflare zone name
- GitHub repository details
- Alarm notification settings, if enabled
