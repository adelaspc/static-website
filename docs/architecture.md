# Architecture

## Request Path

```text
User -> Cloudflare DNS -> CloudFront -> private S3 bucket
```

Cloudflare is authoritative DNS only. Its records are not proxied, so CloudFront remains the CDN, TLS endpoint, cache, and security boundary in front of S3.

The S3 origin is a regular private bucket origin rather than an S3 website endpoint. CloudFront signs origin requests with SigV4 through Origin Access Control (OAC).


![Architecture diagram](/docs/diagrams/architecture-diagram-portfolio-site.png)

## Terraform Structure

The repository is explicitly dev-only. The environment and bootstrap root modules default to `dev` and reject other values. Shared child modules still accept an environment input for naming and tagging, but that does not imply that staging or production roots currently exist.

Both AWS provider configurations use `default_tags` so supported resources consistently receive `Project`, `Environment`, and `ManagedBy`. The `us-east-1` provider alias uses the same defaults, which also tags the CloudFront ACM certificate. Resources add only resource-specific tags such as S3 bucket `Name`; the backend provider additionally applies `Purpose = terraform-state`.

- `terraform/environments/dev` composes the environment modules.
- `modules/s3` creates the website and CloudFront log buckets.
- `modules/acm-cloudflare` creates the ACM certificate and DNS validation records.
- `modules/cloudfront` creates OAC, the distribution, security headers, logging, and custom errors.
- `modules/cloudflare-dns` creates DNS-only records for the configured aliases.
- `modules/github-actions-iam` creates the GitHub OIDC provider and two deployment roles.
- `modules/monitoring` creates CloudFront 4xx and 5xx alarms.
- `terraform/environments/dev/website-bucket-policy.tf` owns the cross-module S3 policy that binds the website bucket to the exact CloudFront distribution ARN.

The backend is managed separately under `terraform/bootstrap/backend`; see [Bootstrap Lifecycle](bootstrap.md).

The backend bucket retains noncurrent Terraform state versions for 90 days by default and aborts incomplete multipart uploads after seven days. This bounds historical state storage while preserving a practical recovery window.

![Terraform](/docs/diagrams/dependency-graph.png)

## Multi-Environment Extension

Adding staging or production should not be done by passing a different value into the existing `dev` root. A real extension should add separate root modules such as `terraform/environments/staging` and `terraform/environments/prod`, each with:

- an independent remote-state key, for example `static-website/staging/terraform.tfstate`;
- unique bucket names, domains, certificates, CloudFront resources, alarms, and workflow roles;
- a matching protected GitHub Environment with environment-scoped variables and secrets;
- environment-specific concurrency groups and deployment approvals;
- an explicit promotion model between environments.

Production should preferably use a separate AWS account and independently managed backend rather than sharing the dev account and blast radius. Until those controls exist, this repository should be described and operated as dev-only.

## S3 Storage

The project creates two application buckets:

1. A private website bucket named `${project}-${bucket_name}`.
2. A CloudFront log bucket named `${project}-${bucket_name}-cf-logs`.

Both buckets block public access, use S3-managed AES-256 encryption, deny all requests that do not use TLS, use bucket-owner-enforced object ownership, and have versioning enabled. ACLs are disabled on both buckets.

Website object lifecycle behavior:

- noncurrent versions expire after 30 days by default;
- incomplete multipart uploads are aborted after seven days.

CloudFront log lifecycle behavior:

- log objects expire after 90 days by default;
- noncurrent log object versions expire after the same retention period;
- incomplete multipart uploads are aborted after seven days.

Terraform owns bucket configuration, but it does not own website objects. GitHub Actions synchronizes the generated frontend files with `aws s3 sync --delete`, so manually uploaded objects can be removed by the next deployment.

## CloudFront and TLS

CloudFront uses the AWS-managed `CachingOptimized` cache policy and accepts only `GET` and `HEAD` viewer methods. HTTP requests are redirected to HTTPS.

The ACM certificate is created through an aliased AWS provider in `us-east-1`, which is mandatory for CloudFront certificates. Cloudflare DNS validation records are created automatically before the certificate is attached to the distribution.

The viewer TLS minimum is `TLSv1.2_2021`. The distribution uses `PriceClass_100` by default.

## DNS

Every entry in `domain_aliases` is:

- included in the ACM certificate;
- configured as a CloudFront alternate domain name;
- created as a DNS-only Cloudflare CNAME record pointing to the CloudFront domain.

The Cloudflare zone must already exist. Terraform does not create or delegate the zone itself.

![ACM Validation Flow](/docs/diagrams/acm-validation-flow.png)

## Error Handling

Private S3 origins can return HTTP 403 when an object is missing because viewers cannot list the bucket. CloudFront therefore handles both origin 403 and 404 responses consistently.

Both responses serve `/error.html` and return HTTP 404. This preserves correct missing-page semantics and avoids returning the homepage as a soft 404.

The custom error response minimum TTL is `0`.

## Caching

The frontend build generates content hashes for the compiled CSS and JavaScript filenames. Deployment metadata is applied in four stages:

- all synchronized files initially receive `public, max-age=3600`;
- `assets/styles.<hash>.css` receives `public, max-age=31536000, immutable`;
- `assets/site.<hash>.js` receives `public, max-age=31536000, immutable`;
- all HTML files receive `no-cache`.

The workflow invalidates `/*` after deployment. This is simple and reliable for a small portfolio site, although targeted HTML invalidations would be more efficient at larger scale.

## Monitoring and Logging

CloudFront Standard Logging v2 delivers W3C access logs to the dedicated logging bucket through the CloudWatch Logs delivery API. The delivery source, destination, and connection are managed in `us-east-1`, as required by the CloudFront logging API, while the destination remains the regional S3 bucket.

The log bucket policy authorizes `delivery.logs.amazonaws.com` only for this AWS account and `us-east-1` CloudWatch Logs delivery resources. Delivered objects use the AWS-managed `AWSLogs/<account-id>/CloudFront/` prefix, and S3 ACLs remain disabled through bucket-owner-enforced object ownership.

Two alarms are created in `us-east-1`, where CloudFront metrics are exposed:

- 4xx error rate above 5% by default;
- 5xx error rate above 1% by default.

Each alarm evaluates five-minute periods and requires two breaching datapoints. Missing data is treated as not breaching, which avoids false alarms during low-traffic periods.

Notification and recovery actions are optional and default to empty lists.

## Security Model

- CloudFront signs origin requests through OAC.
- The website bucket policy grants `s3:GetObject` to the CloudFront service principal only when `AWS:SourceArn` matches the exact managed distribution ARN.
- GitHub Actions uses temporary STS credentials obtained through OIDC.
- Trust policies restrict role assumption by repository and the `dev` GitHub Environment subject.
- Terraform state is private, encrypted, versioned, and protected with an S3 lockfile.
- Website, CloudFront log, and Terraform state bucket policies deny non-TLS requests through `aws:SecureTransport`.
- The Terraform workflow can update remote state but may delete only `*.tflock` objects, not state objects.
- The Terraform workflow uses explicit S3, ACM, CloudFront, and CloudWatch actions instead of service-wide wildcards.
- An IAM permissions boundary caps the Terraform role at the stack's approved service and resource scope and excludes IAM write access.
- The Cloudflare API token should be scoped to the target zone.

CloudFront adds:

- HSTS with subdomains and preload;
- `X-Frame-Options: DENY`;
- `X-Content-Type-Options: nosniff`;
- `Referrer-Policy: strict-origin-when-cross-origin`.

Content Security Policy is intentionally deferred for this portfolio deployment. Before production use or before adding third-party frontend integrations, add CSP through a CloudFront Response Headers Policy and test it first in report-only mode.

## Shared GitHub OIDC Provider

This repository is the Terraform owner of the AWS account-level GitHub Actions OIDC provider for `https://token.actions.githubusercontent.com`. Other projects in the same AWS account may consume that existing provider through a Terraform `data` source and create their own repository-scoped IAM roles.

Only one provider with this URL can exist in an AWS account. Other projects must not attempt to create a duplicate or import it into a second state. Changes to its URL, audience list, thumbprints, or lifecycle must be reviewed as shared-infrastructure changes because they can affect every GitHub Actions role that trusts the provider.

The provider must remain in place while any external role references its ARN. Before destroying this stack, identify all dependent roles and either migrate them to another deliberately managed provider or remove those dependencies. Deleting the provider first will break OIDC authentication for dependent GitHub Actions workflows.

## Intentional Limitations

- The project deploys only `dev`; staging and production root modules, independent state, promotion workflows, and multi-account isolation are intentionally not implemented.
- No WAF web ACL is attached to CloudFront.
- No SNS notification channel is provisioned by default.
- Cloudflare is used only for DNS, not as a second proxy/CDN.
- The GitHub OIDC provider is shared account-level infrastructure owned by this stack, so stack teardown requires coordination with other projects that consume it.
- The Terraform apply role has broad write access to the website's S3 and edge resources, but IAM access is read-only. IAM and OIDC changes require the privileged bootstrap identity so the workflow cannot administer or escalate itself.

Security scan decisions are documented in [Checkov Trade-offs](checkov-tradeoffs.md).
