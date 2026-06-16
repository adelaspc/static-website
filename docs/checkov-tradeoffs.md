# Checkov Trade-offs

## Policy

Checkov scans the Terraform configuration in GitHub Actions and through the local pre-commit configuration. It is blocking in both locations: an unsuppressed failed check returns a non-zero exit code and stops validation.

Every active finding must be:

- fixed;
- accepted and documented here; or
- suppressed by its exact check ID with a concise justification near the relevant resource.

Do not maintain this document as a permanent copy of one historical scan. Check IDs and findings can change when Checkov, providers, or Terraform code change. Review it against the latest CI output.

## Current Intentional Decisions

| Area | Decision | Reason |
| --- | --- | --- |
| AWS WAF | Not enabled for the demo | WAF improves edge protection but adds fixed and request-based cost. |
| S3 server access logging | Not enabled for every bucket | CloudFront logs provide viewer request visibility; additional S3 logging adds storage and operational overhead. |
| S3 event notifications | Not configured | Deployment is driven by GitHub Actions and does not require event processing. |
| Cross-region replication | Not configured | The project does not claim a cross-region disaster recovery objective. |
| Customer-managed KMS keys | Not used | S3-managed AES-256 encryption is sufficient for the demo and avoids key-management cost and operations. |
| Checkov enforcement | Blocking | New unsuppressed findings fail CI and pre-commit validation. |
| CloudFront geo restriction | Not configured | The public portfolio is intentionally available globally. |
| CloudFront origin failover | Not configured | The project claims no multi-origin availability objective. |
| Content Security Policy | Deferred | The current site is a static portfolio with no authentication, no user-generated content, and no backend application runtime, so CSP is documented as a production-hardening item rather than enabled immediately. Add CSP before introducing analytics, third-party scripts, external fonts, forms, embeds, or client-side API calls. Roll it out through a CloudFront Response Headers Policy and test first with `Content-Security-Policy-Report-Only`. |

Each accepted exception is suppressed beside the relevant Terraform resource with its exact Checkov ID and a concise reason. The current accepted check IDs are:

- `CKV_AWS_18`: additional S3 server access logging;
- `CKV2_AWS_62`: S3 event notifications;
- `CKV_AWS_145`: customer-managed KMS encryption;
- `CKV_AWS_144`: cross-region S3 replication;
- `CKV_AWS_68` and `CKV2_AWS_47`: CloudFront WAF requirements;
- `CKV_AWS_310`: CloudFront origin failover;
- `CKV_AWS_374`: CloudFront geographic restrictions;
- `CKV_AWS_86`: false positive because the check recognizes only legacy `logging_config`; access logging is managed through Standard Logging v2 delivery resources;
- `CKV_AWS_111` and `CKV_AWS_356`: wildcard resources required by selected AWS APIs, mitigated through explicit actions, resource-scoped S3 access, read-only IAM, and a permissions boundary.

## Review Process

For each dependency or infrastructure change:

1. Run Checkov locally or inspect the CI output.
2. Compare new findings with this document.
3. Fix regressions introduced by the change.
4. Document any newly accepted trade-off with its scope and reason.
5. Remove obsolete entries and inline suppressions when the related resource or trade-off no longer exists.

The former DynamoDB lock-table finding is intentionally absent because state locking now uses native S3 lockfiles.

## Production Hardening Direction

Before treating the platform as production-ready, consider:

- attaching an AWS WAF web ACL to CloudFront;
- using customer-managed KMS keys where key ownership is required;
- defining recovery objectives and enabling replication where justified;
- adding SNS or incident-management alarm targets;
- adding a Content Security Policy;
- reducing or removing accepted Checkov exceptions when the cost and operational model changes.
