# Troubleshooting

Each section follows the same order: symptom, likely causes, checks, and remediation.

## ACM Certificate Remains Pending

**Symptom:** Terraform waits for certificate validation or CloudFront cannot attach the certificate.

**Likely causes:**

- validation records were created in the wrong Cloudflare zone;
- the Cloudflare token lacks Zone Read, DNS Read, or DNS Write;
- the certificate is not in `us-east-1`;
- DNS propagation is incomplete;
- a domain alias is outside the configured zone.

**Checks:**

```bash
dig CNAME <acm-validation-record>
aws acm describe-certificate \
  --certificate-arn <certificate-arn> \
  --region us-east-1
```

**Remediation:** Correct the zone, token scope, or domain list, then rerun Terraform. Do not manually replace Terraform-managed validation records unless state is reconciled afterward.

## CloudFront Returns an Unexpected 403

**Symptom:** A valid deployed object returns 403 instead of its content.

**Likely causes:**

- OAC is not attached to the origin;
- the bucket policy no longer permits the CloudFront service principal;
- the object does not exist;
- the frontend has not been deployed;
- CloudFront still has an old origin configuration.

**Checks:**

```bash
aws s3api head-object \
  --bucket <website-bucket-name> \
  --key index.html

aws cloudfront get-distribution-config \
  --id <cloudfront-distribution-id>
```

**Remediation:** Apply the Terraform configuration, deploy the complete frontend artifact, and wait for CloudFront status `Deployed`. Missing paths should return the branded page with HTTP 404, not expose the origin 403.

## Missing URL Does Not Show the Error Page

**Symptom:** A nonexistent URL returns the homepage, raw XML, 403, or an unexpected status.

**Likely causes:**

- `/error.html` was not deployed;
- custom 403/404 responses are stale or absent;
- an old CloudFront configuration is still deploying;
- cached behavior predates the infrastructure change.

**Checks:**

```bash
aws s3api head-object \
  --bucket <website-bucket-name> \
  --key error.html

curl -i https://<domain-name>/definitely-missing-page
```

**Remediation:** Deploy the frontend, apply Terraform, wait for CloudFront deployment, and invalidate `/*`.

## GitHub OIDC AssumeRoleWithWebIdentity Fails

**Symptom:** `configure-aws-credentials` cannot assume the requested role.

**Likely causes:**

- the OIDC provider or role does not exist yet;
- `id-token: write` is missing;
- the role ARN variable is wrong;
- the token subject does not match the trust policy;
- the job is not associated with GitHub Environment `dev`;
- the repository configured in Terraform differs from the actual repository.

**Checks:**

- confirm the workflow permissions include `contents: read` and `id-token: write`;
- compare `github.repository` with Terraform variable `github_repository`;
- inspect the role trust policy;
- confirm apply/deploy jobs use environment `dev`;
- confirm the credentialed job is a `main` deployment or manual dispatch, not a pull-request job.

**Remediation:** Correct the role variable or trust-policy inputs and apply Terraform with an existing AWS identity if OIDC resources have not yet been created.

## Terraform Lock Remains Stuck

**Symptom:** Terraform reports that the remote state is locked after an interrupted run.

**Likely causes:**

- a workflow or local run is still active;
- a job was cancelled while holding the S3 lockfile;
- connectivity failed before lock cleanup.

**Checks:**

```bash
aws s3api head-object \
  --bucket <state-bucket-name> \
  --key static-website/dev/terraform.tfstate.tflock
```

Check GitHub Actions and local processes before removing anything.

**Remediation:** When no Terraform process is active, use `terraform force-unlock <lock-id>` if Terraform provides an ID. Manual lockfile deletion is a last resort; follow [Recovery](recovery.md).

## Terraform Init or Provider Schema Fails

**Symptom:** Terraform cannot download providers, load schemas, or initialize the backend.

**Likely causes:**

- unsupported Terraform version;
- stale or incomplete `.terraform` directory;
- provider lockfile mismatch;
- missing network access to the Terraform registry;
- incorrect backend bucket, key, or region;
- AWS credentials cannot access the state object or `.tflock` key.

**Checks:**

```bash
terraform version
terraform providers
```

Compare the installed version with the constraints documented in [Operations](operations.md).

**Remediation:** Reinitialize the intended stack, preserve and review lockfile changes, and fix credentials or backend values. Do not delete remote state while troubleshooting provider installation.

## DNS Does Not Resolve

**Symptom:** The custom domain does not resolve to CloudFront.

**Likely causes:**

- records are absent or created in the wrong zone;
- Cloudflare proxying is enabled;
- the domain does not use the expected Cloudflare nameservers;
- DNS propagation is incomplete;
- the alias was omitted from Terraform input.

**Checks:**

```bash
dig NS <zone-name>
dig <domain-name>
dig CNAME <domain-name>
```

**Remediation:** Correct delegation and Terraform inputs, keep records DNS-only, then apply Terraform. Ensure every alias is covered by the ACM certificate.

## Frontend Build Fails

**Symptom:** `npm run build` exits before producing `portfolio-site/dist`.

**Likely causes:**

- Node.js is not version 24;
- `npm ci` was not run;
- a source HTML file or the `images` directory is missing;
- an unsupported Lucide icon name is used;
- generated CSS cannot be written.

**Checks:**

```bash
node --version
cd portfolio-site
npm ci
npm run build
```

**Remediation:** Restore required source files, correct icon names, and reproduce the CI runtime locally with Node.js 24.

## Frontend Deploy Fails Because Configuration Is Missing

**Symptom:** The workflow exits during AWS authentication or S3/CloudFront commands.

**Likely causes:**

- a required GitHub variable or secret is absent;
- the frontend role ARN is stale;
- the bucket or distribution value does not match current Terraform outputs;
- environment-scoped values are unavailable because the job uses the wrong environment.

**Checks:** Compare GitHub configuration with the root [README](../README.md) and current Terraform outputs.

**Remediation:** Update the variables and secret, ensure environment `dev` exists, then rerun the workflow.

## CloudFront Serves an Old Release

**Symptom:** S3 contains new files but the public site still serves old content.

**Likely causes:**

- invalidation is still in progress or failed;
- HTML metadata is not `no-cache`;
- the browser cached content;
- DNS points to another distribution;
- deployment uploaded an unexpected artifact.

**Checks:**

```bash
aws cloudfront list-invalidations \
  --distribution-id <cloudfront-distribution-id>

curl -I https://<domain-name>/index.html
```

**Remediation:** Verify the artifact and S3 metadata, wait for invalidation completion, and confirm DNS targets the expected distribution. Use [Recovery](recovery.md) if rollback is required.
