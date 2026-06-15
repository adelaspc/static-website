# CI/CD

## Delivery Model

Infrastructure and frontend delivery are intentionally independent:

- `.github/workflows/terraform.yaml` provisions AWS and Cloudflare infrastructure.
- `.github/workflows/deploy-frontend.yaml` builds and publishes website files.

Terraform does not manage website objects, and the frontend workflow does not modify infrastructure configuration.

## Terraform Workflow

Triggers:

- pull requests changing `terraform/**` or the workflow file;
- pushes to `main` changing those paths;
- manual `workflow_dispatch` runs.

### Validate Job

The validation job runs without cloud credentials:

```text
terraform fmt -check -recursive from the repository root
-> initialize and validate terraform/environments/dev without its backend
-> initialize and validate terraform/bootstrap/backend without a backend
-> TFLint
-> Checkov
```

The main environment and bootstrap backend are independent Terraform root modules, so CI initializes and validates each one separately. This prevents bootstrap-only errors from being hidden by successful validation of the main environment.

Both the validation and apply jobs install Terraform `1.15.5` explicitly through `hashicorp/setup-terraform`. This keeps CI reproducible and satisfies the stricter bootstrap stack version constraint.

TFLint fails on warnings or errors. Its configuration enables both the recommended Terraform language rules and the AWS provider ruleset pinned to version `0.47.0`; `tflint --init` installs the plugin before recursive linting. Checkov is also blocking: any finding without a precise, documented suppression fails CI. See [Checkov Trade-offs](checkov-tradeoffs.md).

Equivalent local hooks are configured in `.pre-commit-config.yaml`:

```bash
pre-commit install
pre-commit run --all-files
```

### Pull Request Validation

Pull requests stop after the validation job. They do not initialize the remote backend, read Terraform state, receive the Cloudflare API token, request an OIDC token, or assume an AWS role.

This deliberately trades PR-time infrastructure diff visibility for a smaller trust boundary. The credentialed plan is produced only inside the protected apply job after merge to `main` or manual approval.

### Main Branch Apply

Pushes to `main` and manual runs execute a saved plan followed by apply:

```text
terraform plan -out=tfplan
-> terraform apply -auto-approve tfplan
```

The apply job targets the `dev` GitHub Environment. Required reviewers pause the job only when that environment protection rule is configured.

The workflow requests a four-hour AWS role session, matching the apply role's maximum session duration.

## Frontend Workflow

Triggers:

- pull requests changing `portfolio-site/**` or the workflow file;
- pushes to `main` changing those paths;
- manual `workflow_dispatch` runs.

### Build Job

The build job runs for every trigger:

```text
Checkout
-> Node.js 24 setup
-> npm ci
-> npm run build
-> upload portfolio-site/dist artifact
```

The build rewrites HTML references to the content-hashed CSS file and includes `index.html`, project pages, `error.html`, and static images in `dist`.

Pull requests stop after the artifact upload and do not deploy.

### Deploy Job

The deploy job runs only for `main` pushes and manual dispatches. It targets the `dev` GitHub Environment and performs:

```text
Download build artifact
-> Assume frontend role through OIDC
-> aws s3 sync --delete
-> Apply immutable CSS metadata
-> Apply no-cache HTML metadata
-> Invalidate CloudFront /*
```

The GitHub artifact is an internal transfer mechanism between jobs. S3 receives the extracted files, not an archive.

The website bucket is CI-owned. Manual objects can be deleted by the next `aws s3 sync --delete`.

## OIDC Authentication

Terraform creates one GitHub OIDC provider and two IAM roles:

| Role | Purpose | Trusted subject |
| --- | --- | --- |
| Terraform apply | Infrastructure changes | `repo:<owner>/<repo>:environment:dev` |
| Frontend deploy | S3 publishing and invalidation | `repo:<owner>/<repo>:environment:dev` |

All roles require audience `sts.amazonaws.com`.

At runtime:

1. GitHub issues an OIDC token for the job.
2. `aws-actions/configure-aws-credentials` sends it to AWS STS.
3. STS validates audience, repository, and subject conditions.
4. AWS returns temporary credentials when the trust policy matches.
5. Remaining steps use those temporary credentials.

Only credentialed apply and deploy jobs require:

```yaml
permissions:
  contents: read
  id-token: write
```

AWS access keys should not be stored as GitHub secrets.

## Role Boundaries

The frontend role can:

- list the website bucket;
- read, upload, and delete website objects;
- invalidate only the managed CloudFront distribution.

The apply role can manage the website infrastructure, but it has read-only IAM access. It cannot create, update, attach, or delete IAM roles, policies, or the GitHub OIDC provider, so it cannot modify its own permissions or trust policy.

For the Terraform backend, the apply role can list the state bucket and read or update state objects. `s3:DeleteObject` is restricted to `*.tflock`, so the workflow can release native S3 locks but cannot delete the Terraform state object.

The role's AWS service permissions enumerate the S3, ACM, CloudFront, CloudWatch, and CloudWatch Logs delivery operations required by the managed resources rather than using service-wide wildcards. An IAM permissions boundary repeats the maximum allowed service and resource scope and contains no IAM write actions. Consequently, attaching a broader identity policy does not grant permissions outside the boundary.

Changes under `modules/github-actions-iam` must be planned and applied by the privileged bootstrap identity described in [Bootstrap Lifecycle](bootstrap.md). A regular GitHub apply that includes an IAM change is expected to fail rather than grant the workflow permission to administer itself.

## GitHub Environment

Create an environment named `dev`. It can hold apply- and frontend-specific values and can optionally enforce:

- required reviewers;
- wait timers;
- branch deployment restrictions.

With required reviewers enabled, apply and frontend deployment pause before cloud credentials are requested. Static Terraform validation and frontend pull request builds remain unaffected and have no OIDC permission.

Terraform backend values, deployment inputs, role ARNs, and `CLOUDFLARE_API_TOKEN` can be scoped to the `dev` Environment because pull-request jobs do not consume them.

Required variables and secrets are listed once in the root [README](../README.md).

## Bootstrap Dependency

The remote backend and first main apply must be completed before GitHub Actions can manage the website stack. The roles and OIDC provider do not exist before that apply, and subsequent changes to those IAM resources still require the privileged bootstrap identity.

See [Bootstrap Lifecycle](bootstrap.md) for the setup order and backend lifecycle.

## Failure and Concurrency Behavior

- Terraform jobs share concurrency group `terraform-dev` and do not cancel an active run.
- Frontend jobs share concurrency group `frontend-dev`; a newer run can cancel an older in-progress run.
- An interrupted Terraform run can leave an S3 lockfile; follow [Recovery](recovery.md) before unlocking it.
- A failed frontend deployment may leave a partial release in S3. Redeploy a complete known-good build and invalidate CloudFront.
