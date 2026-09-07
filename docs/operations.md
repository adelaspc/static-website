# Operations

## Deployment Verification

Run these checks after the first deployment and after material infrastructure changes.

### S3 Objects

```bash
aws s3 ls s3://<website-bucket-name> --recursive
```

Confirm that `index.html`, `error.html`, project pages, images, and hashed CSS and JavaScript files exist.

Inspect metadata:

```bash
aws s3api head-object \
  --bucket <website-bucket-name> \
  --key index.html

aws s3api head-object \
  --bucket <website-bucket-name> \
  --key assets/styles.<hash>.css

aws s3api head-object \
  --bucket <website-bucket-name> \
  --key assets/site.<hash>.js
```

Expected cache metadata:

- HTML: `no-cache`;
- hashed CSS and JavaScript: `public, max-age=31536000, immutable`;
- other assets: `public, max-age=3600`.

### CloudFront Status and Invalidations

```bash
aws cloudfront get-distribution \
  --id <cloudfront-distribution-id> \
  --query 'Distribution.Status'

aws cloudfront list-invalidations \
  --distribution-id <cloudfront-distribution-id>
```

The distribution should report `Deployed`; the latest release invalidation should eventually report `Completed`.

### DNS and HTTPS

```bash
dig <domain-name>
dig CNAME <domain-name>
curl -I https://<domain-name>
```

Confirm that DNS points to CloudFront, the certificate is valid, and the response includes CloudFront and configured security headers.

For deployments with `WEBSITE_URL` configured, the frontend workflow also verifies the homepage, branded 404 response, and core security headers automatically after invalidation.

### Error Handling

```bash
curl -I https://<domain-name>/definitely-missing-page
```

Expected behavior:

- HTTP status `404`;
- branded `error.html` response body;
- CloudFront security headers remain present.

### Logs

```bash
aws s3 ls \
  s3://<cloudfront-logs-bucket-name>/AWSLogs/<aws-account-id>/CloudFront/ \
  --recursive
```

CloudFront Standard Logging v2 delivers logs asynchronously and they may not appear immediately. The delivery is configured through CloudWatch Logs in `us-east-1`, but log objects are stored in the dedicated S3 bucket.

### CloudWatch Alarms

```bash
aws cloudwatch describe-alarms \
  --alarm-names \
  <cloudfront-4xx-alarm-name> \
  <cloudfront-5xx-alarm-name> \
  --region us-east-1
```

Confirm that both alarms exist. Notification actions can be empty in the demo configuration.

## Routine Checks

Periodically verify:

- GitHub workflow runs are successful;
- the most recent CloudFront invalidation completed;
- the ACM certificate remains issued;
- CloudFront logs continue arriving;
- alarms are not stuck in `INSUFFICIENT_DATA` during normal traffic;
- S3 lifecycle policies remain attached;
- backend state versions are present;
- no stale `.tflock` object remains after Terraform runs;
- GitHub variables still match current Terraform outputs.
- Dependency Review, Actionlint, and Zizmor runs remain successful or triaged.

## Release Verification

The strongest frontend release check is to compare the deployed HTML with the expected hashed CSS and JavaScript references:

```bash
aws s3 cp s3://<website-bucket-name>/index.html -
```

Then confirm the referenced asset exists and returns HTTP 200 through CloudFront.

Do not rely only on S3 timestamps. CloudFront may still serve cached content until invalidation completes.

## Version Policy

Version constraints are owned by the repository configuration:

- main Terraform environment: `>= 1.10, < 2.0`;
- bootstrap Terraform stack: `>= 1.15.5, < 1.16.0`;
- GitHub Actions Terraform version: exactly `1.15.5` for validation and apply jobs;
- AWS provider: `~> 6.0`;
- Cloudflare provider: `~> 5.0`;
- TLS provider: `~> 4.0`;
- TFLint AWS ruleset: exactly `0.47.0`;
- frontend CI runtime: Node.js 24;
- GitHub Action major versions are pinned in workflow files;
- exact Terraform provider selections are recorded in `.terraform.lock.hcl`.

Treat major version changes as planned maintenance. Minor and patch updates still require validation because provider behavior and Checkov results can change.

## Terraform Docs

Root-stack input and output tables are generated with `terraform-docs`. Regenerate them after changing variables, outputs, required providers, or root module composition:

```bash
terraform-docs --config .terraform-docs.yml --output-file terraform/environments/dev/README.md --output-mode inject terraform/environments/dev
terraform-docs --config .terraform-docs.yml --output-file terraform/bootstrap/backend/README.md --output-mode inject terraform/bootstrap/backend
```

The generated sections are intentionally limited to the two root stacks. Child module READMEs and CI/pre-commit enforcement can be added later if the project needs stricter generated-documentation coverage.

## Upgrade Procedure

1. Create a dedicated maintenance branch.
2. Read release notes and migration guides for every major-version change.
3. Update one tool or dependency family at a time.
4. Run `terraform init -upgrade` only in the intended stack directories.
5. Review `.terraform.lock.hcl` changes.
6. Run Terraform formatting, initialization, validation, TFLint, and Checkov.
7. Run `npm ci`, `npm audit --audit-level=high`, and `npm run ci` for frontend/runtime changes.
8. Open a pull request and inspect the remote Terraform plan.
9. Apply only after the plan contains no unexplained replacements or deletions.
10. Perform the deployment verification checks above.

Do not update GitHub Action majors blindly. Confirm that the new release supports the current GitHub runner and Node runtime.

## Operational Ownership

- Terraform owns infrastructure configuration.
- GitHub Actions owns website object deployment.
- Cloudflare remains an external authoritative DNS dependency.
- The local or migrated bootstrap state must have an explicit owner and backup location.
- Recovery actions should be recorded with the state version, object version, commit, and workflow run used.

Use [Troubleshooting](troubleshooting.md) for diagnosis and [Recovery](recovery.md) for restoration procedures.
