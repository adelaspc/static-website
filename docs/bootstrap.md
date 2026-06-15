# Bootstrap Lifecycle

## Purpose

The main `dev` stack stores Terraform state in S3 and uses native S3 state locking. The state bucket must exist before that stack can initialize, so it is created by the separate stack in `terraform/bootstrap/backend`.

Both root modules are intentionally dev-only and default `environment` to `dev`. Staging or production require separate roots and independent state rather than overriding this value.

The bootstrap stack itself keeps local state by default. Keep that state and its backups private.

## Create the Backend

The bootstrap stack currently requires Terraform `>= 1.15.5, < 1.16.0`.

```bash
cd terraform/bootstrap/backend
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

It creates one S3 bucket with:

- AES-256 server-side encryption;
- versioning;
- expiration of noncurrent state versions after 90 days by default;
- public access blocking;
- a bucket policy that denies non-TLS requests;
- bucket-owner-enforced ownership;
- `prevent_destroy = true`.

Record the `state_bucket_name` output for main-stack initialization and GitHub variable `TF_STATE_BUCKET`.

The `noncurrent_state_version_retention_days` input controls recovery history and defaults to 90 days, with a minimum of 30 days. Increasing it extends the recovery window and storage of historical state values; reducing it permanently removes older versions when lifecycle processing runs.

## Initialize the Main Stack

```bash
cd terraform/environments/dev
terraform init \
  -backend-config="bucket=<state-bucket-name>" \
  -backend-config="key=static-website/dev/terraform.tfstate" \
  -backend-config="region=eu-central-1" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"
```

`use_lockfile=true` creates a `.tflock` object next to the state object while Terraform holds the lock. No DynamoDB table is used.

## First Main Apply

The first main apply must use an existing AWS identity with permissions to create the complete stack, including IAM roles and the GitHub OIDC provider.

```bash
export CLOUDFLARE_API_TOKEN="..."
terraform plan
terraform apply
```

After apply, map these outputs into GitHub variables:

```bash
terraform output bucket_name
terraform output cloudfront_distribution_id
terraform output github_actions_frontend_role_arn
terraform output github_actions_terraform_role_arn
```

The remaining required GitHub values are listed in the root [README](../README.md).

## Update GitHub Actions IAM

The Terraform apply role intentionally has no IAM write permissions. It can read the managed roles, policies, and OIDC provider during refresh and planning, but it cannot modify its own policy or trust relationship.

Whenever `terraform/environments/modules/github-actions-iam` changes, run the main-stack plan and apply with the same privileged bootstrap identity used for the first deployment. Review the plan carefully and do not grant the workflow role IAM administration as a shortcut. Normal website infrastructure changes can continue through GitHub Actions.

The Standard Logging v2 migration adds explicit CloudWatch Logs delivery permissions to the Terraform role and its permissions boundary. Perform this rollout with the privileged bootstrap identity before relying on the GitHub workflow to create or update the logging delivery resources.

An existing deployment requires one explicit ACL cleanup before the migration apply. Removing an `aws_s3_bucket_acl` resource from Terraform state does not change the remote ACL, and S3 rejects `BucketOwnerEnforced` while the legacy CloudFront canonical-user grant remains. Reset the log bucket to its owner-only private ACL, then apply the final configuration:

```bash
aws s3api put-bucket-acl \
  --bucket "<existing-cloudfront-log-bucket-name>" \
  --acl private

terraform plan
terraform apply
```

The bucket name follows `${project}-${bucket_name}-cf-logs`; confirm the existing resource in S3 before running the command. After the migration apply, `terraform output -raw cloudfront_logs_bucket_name` returns it directly.

The apply removes the legacy distribution logging block, enables bucket-owner-enforced ownership, installs the v2 delivery bucket policy, creates the CloudWatch Logs delivery resources in `us-east-1`, and updates the Terraform role and boundary. A short access-log delivery interruption during this one-time migration is acceptable for the dev-only environment.

The first rollout of the Terraform role permissions boundary must also use the privileged bootstrap identity. The existing workflow role cannot create the boundary policy or attach it to itself, by design. After rollout, verify the `github_actions_terraform_permissions_boundary_arn` output and confirm the role shows that boundary in IAM.

This stack also owns the account-level GitHub Actions OIDC provider. Other projects may read it with a Terraform `data` source, but they must not create or import a second copy. Treat provider changes as shared-infrastructure changes and verify all dependent IAM roles before applying them.

## Protect the Local Bootstrap State

- Do not commit `terraform.tfstate`, backups, or real `terraform.tfvars`.
- Store an encrypted backup of the bootstrap state outside the repository.
- Back up the state again after any bootstrap-stack change.
- Do not run the bootstrap stack concurrently from multiple machines while it uses local state.

## Migrate Bootstrap State

For stronger lifecycle management, move the bootstrap resources into a separately managed backend that does not depend on the bucket being managed.

Recommended sequence:

1. Create or select an independent Terraform backend.
2. Back up the current local bootstrap state.
3. Add the new backend configuration to the bootstrap stack.
4. Run `terraform init -migrate-state`.
5. Confirm the migration prompt and verify `terraform state list`.
6. Run `terraform plan`; it should not propose recreating backend resources.
7. Preserve the local backup until the migrated state has been tested.

Do not configure the bootstrap stack to use the same state bucket it creates unless the ownership and teardown implications are explicitly accepted.

## Destroy the Main Environment

Destroy the main environment before touching the backend:

1. Preserve any frontend or state versions needed for recovery.
2. Inventory IAM roles in other projects that trust this stack's GitHub OIDC provider.
3. Migrate or remove every external dependency on the provider. Do not destroy it while dependent workflows remain.
4. Empty the website bucket, including object versions and delete markers.
5. Empty the CloudFront log bucket.
6. Run `terraform destroy` from `terraform/environments/dev`.
7. Wait for CloudFront and DNS resources to finish deleting.

S3 bucket deletion fails while objects or versions remain. The frontend workflow's `--delete` option does not remove historical object versions.

## Destroy the Backend

Only remove the backend after every dependent Terraform environment has been destroyed or migrated.

1. Back up the latest remote state and bootstrap state.
2. Confirm no workflow or local Terraform process is running.
3. Remove `prevent_destroy` from the backend bucket intentionally.
4. Apply or plan the lifecycle change so the removal is explicit.
5. Empty all state object versions, lockfiles, and delete markers from the bucket.
6. Run `terraform destroy` for the bootstrap stack.

Backend destruction is intentionally not a routine operation. Recovery procedures are documented in [Recovery](recovery.md).
