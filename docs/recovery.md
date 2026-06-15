# Recovery

## Safety Rules

- Stop GitHub Actions Terraform workflows before changing state or lock objects.
- Confirm no local Terraform process is running.
- Back up the current state before restoring an older version.
- Never edit Terraform state JSON manually unless no supported recovery method remains.
- Run `terraform plan` after every recovery and inspect the full proposal before applying.

## Recover Remote Terraform State

The backend bucket has versioning enabled and retains noncurrent state versions for 90 days by default. S3 lifecycle processing is asynchronous, and versions older than the configured retention period must not be assumed recoverable. To identify available versions:

```bash
aws s3api list-object-versions \
  --bucket <state-bucket-name> \
  --prefix static-website/dev/terraform.tfstate
```

Back up the current state object:

```bash
aws s3 cp \
  s3://<state-bucket-name>/static-website/dev/terraform.tfstate \
  /tmp/terraform.tfstate.current-backup
```

Download the selected historical version and inspect it locally:

```bash
aws s3api get-object \
  --bucket <state-bucket-name> \
  --key static-website/dev/terraform.tfstate \
  --version-id <version-id> \
  /tmp/terraform.tfstate.recovered

terraform show /tmp/terraform.tfstate.recovered
```

When the selected version is confirmed, restore it as the current object:

```bash
aws s3 cp \
  /tmp/terraform.tfstate.recovered \
  s3://<state-bucket-name>/static-website/dev/terraform.tfstate
```

Reinitialize if necessary, run `terraform state list`, then run `terraform plan`. Do not apply until the proposed changes match the expected infrastructure.

## Recover a Stale S3 Lock

First verify that no workflow or local process is using the state. A live lock must not be removed.

Prefer Terraform's supported unlock command when Terraform reports a lock ID:

```bash
terraform force-unlock <lock-id>
```

If the lock error does not provide a usable ID, inspect the backend key and `.tflock` object before taking further action:

```bash
aws s3api head-object \
  --bucket <state-bucket-name> \
  --key static-website/dev/terraform.tfstate.tflock
```

Manual deletion of the `.tflock` object is a last resort and is safe only after confirming there is no active Terraform operation.

## Recover Website Objects

The website bucket retains noncurrent versions for 30 days by default.

List versions for a damaged object:

```bash
aws s3api list-object-versions \
  --bucket <website-bucket-name> \
  --prefix index.html
```

Download a known-good version and upload it as the new current version:

```bash
aws s3api get-object \
  --bucket <website-bucket-name> \
  --key index.html \
  --version-id <version-id> \
  /tmp/index.html.recovered

aws s3 cp /tmp/index.html.recovered \
  s3://<website-bucket-name>/index.html \
  --cache-control "no-cache" \
  --content-type "text/html"
```

Create a CloudFront invalidation after restoring objects:

```bash
aws cloudfront create-invalidation \
  --distribution-id <cloudfront-distribution-id> \
  --paths "/*"
```

Restoring one HTML file may not be sufficient if it references hashed assets from another release.

## Roll Back a Frontend Release

The preferred rollback is to redeploy a known-good repository commit rather than restore files individually:

1. Check out or revert to the known-good frontend commit on a recovery branch.
2. Run `npm ci` and `npm run build` in `portfolio-site`.
3. Verify the generated `dist` directory.
4. Run the frontend workflow through `workflow_dispatch`, or merge the rollback change according to repository policy.
5. Verify S3 objects, cache headers, the invalidation, and the public site.

Because deployment uses `aws s3 sync --delete`, redeploying a complete known-good build also removes objects that do not belong to that release.

## Recover Lost Bootstrap State

If the bootstrap local state is lost but the backend bucket still exists, do not apply the bootstrap stack immediately because Terraform may attempt to create an already existing bucket.

1. Back up any remaining local files.
2. Recreate the bootstrap configuration and initialize it locally.
3. Import the existing S3 bucket and each managed bucket subresource into the matching Terraform addresses.
4. Run `terraform plan` repeatedly until no resource recreation is proposed.
5. Back up the reconstructed state.
6. Consider migrating it to an independent remote backend as described in [Bootstrap Lifecycle](bootstrap.md).

The resources to reconcile are defined in `terraform/bootstrap/backend/main.tf`; use that file as the source of truth for required imports.

## Post-Recovery Validation

- `terraform state list` contains the expected resources.
- `terraform plan` shows no unexplained create, replace, or destroy actions.
- The website returns HTTPS responses through CloudFront.
- A missing URL returns the branded page with HTTP 404.
- HTML has `Cache-Control: no-cache`.
- The hashed CSS asset exists and has immutable cache metadata.
- CloudFront invalidation completes.
- DNS, logs, and CloudWatch alarms remain operational.
