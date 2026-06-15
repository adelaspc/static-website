locals {
  name_prefix = "${var.project}-${var.environment}"

  terraform_s3_actions = [
    "s3:DeleteBucket",
    "s3:DeleteBucketPolicy",
    "s3:GetAccelerateConfiguration",
    "s3:GetBucketAcl",
    "s3:GetBucketCORS",
    "s3:GetBucketLocation",
    "s3:GetBucketLogging",
    "s3:GetBucketObjectLockConfiguration",
    "s3:GetBucketOwnershipControls",
    "s3:GetBucketPolicy",
    "s3:GetBucketPublicAccessBlock",
    "s3:GetBucketRequestPayment",
    "s3:GetBucketTagging",
    "s3:GetBucketVersioning",
    "s3:GetBucketWebsite",
    "s3:GetEncryptionConfiguration",
    "s3:GetLifecycleConfiguration",
    "s3:GetReplicationConfiguration",
    "s3:ListBucket",
    "s3:PutBucketOwnershipControls",
    "s3:PutBucketPolicy",
    "s3:PutBucketPublicAccessBlock",
    "s3:PutBucketTagging",
    "s3:PutBucketVersioning",
    "s3:PutEncryptionConfiguration",
    "s3:PutLifecycleConfiguration",
  ]

  terraform_acm_actions = [
    "acm:AddTagsToCertificate",
    "acm:DeleteCertificate",
    "acm:DescribeCertificate",
    "acm:ListTagsForCertificate",
    "acm:RemoveTagsFromCertificate",
    "acm:RequestCertificate",
  ]

  terraform_cloudfront_actions = [
    "cloudfront:CreateDistribution",
    "cloudfront:CreateOriginAccessControl",
    "cloudfront:CreateResponseHeadersPolicy",
    "cloudfront:DeleteDistribution",
    "cloudfront:DeleteOriginAccessControl",
    "cloudfront:DeleteResponseHeadersPolicy",
    "cloudfront:GetCachePolicy",
    "cloudfront:GetDistribution",
    "cloudfront:GetDistributionConfig",
    "cloudfront:GetOriginAccessControl",
    "cloudfront:GetResponseHeadersPolicy",
    "cloudfront:ListCachePolicies",
    "cloudfront:ListTagsForResource",
    "cloudfront:TagResource",
    "cloudfront:UntagResource",
    "cloudfront:UpdateDistribution",
    "cloudfront:UpdateOriginAccessControl",
    "cloudfront:UpdateResponseHeadersPolicy",
  ]

  terraform_cloudwatch_actions = [
    "cloudwatch:DeleteAlarms",
    "cloudwatch:DescribeAlarms",
    "cloudwatch:ListTagsForResource",
    "cloudwatch:PutMetricAlarm",
    "cloudwatch:TagResource",
    "cloudwatch:UntagResource",
  ]

  terraform_cloudwatch_logs_actions = [
    "logs:CreateDelivery",
    "logs:DeleteDelivery",
    "logs:DeleteDeliveryDestination",
    "logs:DeleteDeliverySource",
    "logs:GetDelivery",
    "logs:GetDeliveryDestination",
    "logs:GetDeliverySource",
    "logs:ListTagsForResource",
    "logs:PutDeliveryDestination",
    "logs:PutDeliverySource",
    "logs:TagResource",
    "logs:UntagResource",
    "logs:UpdateDeliveryConfiguration",
  ]

}

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "frontend_deploy_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.environment}"]
    }
  }
}

data "aws_iam_policy_document" "terraform_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "frontend_deploy" {
  name               = "${local.name_prefix}-github-frontend-deploy"
  assume_role_policy = data.aws_iam_policy_document.frontend_deploy_assume_role.json
  description        = "GitHub Actions role for deploying static frontend assets to S3."
}

data "aws_iam_policy_document" "frontend_deploy" {
  statement {
    sid     = "ListWebsiteBucket"
    effect  = "Allow"
    actions = ["s3:ListBucket"]

    resources = [var.website_bucket_arn]
  }

  statement {
    sid    = "WriteWebsiteObjects"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = ["${var.website_bucket_arn}/*"]
  }

  statement {
    sid       = "InvalidateDistribution"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [var.cloudfront_distribution_arn]
  }
}

resource "aws_iam_policy" "frontend_deploy" {
  name        = "${local.name_prefix}-github-frontend-deploy"
  description = "Allows GitHub Actions to deploy frontend assets to S3 and invalidate CloudFront."
  policy      = data.aws_iam_policy_document.frontend_deploy.json
}

resource "aws_iam_role_policy_attachment" "frontend_deploy" {
  role       = aws_iam_role.frontend_deploy.name
  policy_arn = aws_iam_policy.frontend_deploy.arn
}

resource "aws_iam_role" "terraform" {
  name                 = "${local.name_prefix}-github-terraform"
  assume_role_policy   = data.aws_iam_policy_document.terraform_assume_role.json
  description          = "GitHub Actions role for managing this Terraform stack."
  max_session_duration = 14400
  permissions_boundary = aws_iam_policy.terraform_boundary.arn
}

data "aws_iam_policy_document" "terraform" {
  #checkov:skip=CKV_AWS_111:Selected ACM, CloudFront, CloudWatch, CloudWatch Logs delivery, IAM read, and account metadata APIs require wildcard resources; actions are explicitly enumerated and capped by a permissions boundary.
  #checkov:skip=CKV_AWS_356:Wildcard resources are limited to APIs that do not support resource-level permissions; S3 and state access remain resource-scoped.
  statement {
    sid       = "CreateProjectS3Buckets"
    effect    = "Allow"
    actions   = ["s3:CreateBucket"]
    resources = ["arn:aws:s3:::${var.project}-*"]
  }

  statement {
    sid     = "ManageProjectS3"
    effect  = "Allow"
    actions = local.terraform_s3_actions

    resources = [
      var.website_bucket_arn,
      "${var.website_bucket_arn}/*",
      var.cloudfront_logs_bucket_arn,
      "${var.cloudfront_logs_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "ReadS3AccountMetadata"
    effect = "Allow"
    actions = [
      "s3:GetAccountPublicAccessBlock",
      "s3:ListAllMyBuckets",
    ]

    resources = ["*"]
  }

  statement {
    sid       = "ListTerraformStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.terraform_state_bucket_name}"]
  }

  statement {
    sid    = "ReadWriteTerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["arn:aws:s3:::${var.terraform_state_bucket_name}/*"]
  }

  statement {
    sid    = "ManageTerraformStateLockfile"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["arn:aws:s3:::${var.terraform_state_bucket_name}/*.tflock"]
  }

  statement {
    sid       = "ManageStaticWebsiteAcm"
    effect    = "Allow"
    actions   = local.terraform_acm_actions
    resources = ["*"]
  }

  statement {
    sid       = "ManageStaticWebsiteCloudFront"
    effect    = "Allow"
    actions   = local.terraform_cloudfront_actions
    resources = ["*"]
  }

  statement {
    sid       = "ManageStaticWebsiteCloudWatch"
    effect    = "Allow"
    actions   = local.terraform_cloudwatch_actions
    resources = ["*"]
  }

  statement {
    sid       = "ManageCloudFrontLogDelivery"
    effect    = "Allow"
    actions   = local.terraform_cloudwatch_logs_actions
    resources = ["*"]
  }

  statement {
    sid    = "ReadGithubActionsIam"
    effect = "Allow"
    actions = [
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
    ]

    resources = ["*"]
  }

  statement {
    sid       = "ReadAccountIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "terraform" {
  name        = "${local.name_prefix}-github-terraform"
  description = "Allows GitHub Actions to manage the Terraform resources in this static website stack."
  policy      = data.aws_iam_policy_document.terraform.json
}

data "aws_iam_policy_document" "terraform_boundary" {
  #checkov:skip=CKV_AWS_111:The boundary repeats only explicitly approved actions; global resource scope is required by selected AWS APIs and IAM write is excluded.
  #checkov:skip=CKV_AWS_356:Wildcard resources are retained only for APIs without practical resource-level scoping, while S3 resources are explicitly constrained.
  statement {
    sid       = "CreateProjectS3Buckets"
    effect    = "Allow"
    actions   = ["s3:CreateBucket"]
    resources = ["arn:aws:s3:::${var.project}-*"]
  }

  statement {
    sid     = "ManageProjectS3"
    effect  = "Allow"
    actions = local.terraform_s3_actions
    resources = [
      var.website_bucket_arn,
      "${var.website_bucket_arn}/*",
      var.cloudfront_logs_bucket_arn,
      "${var.cloudfront_logs_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "ReadS3AccountMetadata"
    effect = "Allow"
    actions = [
      "s3:GetAccountPublicAccessBlock",
      "s3:ListAllMyBuckets",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ListTerraformStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.terraform_state_bucket_name}"]
  }

  statement {
    sid    = "ReadWriteTerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["arn:aws:s3:::${var.terraform_state_bucket_name}/*"]
  }

  statement {
    sid    = "ManageTerraformStateLockfile"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["arn:aws:s3:::${var.terraform_state_bucket_name}/*.tflock"]
  }

  statement {
    sid       = "ManageStaticWebsiteAcm"
    effect    = "Allow"
    actions   = local.terraform_acm_actions
    resources = ["*"]
  }

  statement {
    sid       = "ManageStaticWebsiteCloudFront"
    effect    = "Allow"
    actions   = local.terraform_cloudfront_actions
    resources = ["*"]
  }

  statement {
    sid       = "ManageStaticWebsiteCloudWatch"
    effect    = "Allow"
    actions   = local.terraform_cloudwatch_actions
    resources = ["*"]
  }

  statement {
    sid       = "ManageCloudFrontLogDelivery"
    effect    = "Allow"
    actions   = local.terraform_cloudwatch_logs_actions
    resources = ["*"]
  }

  statement {
    sid    = "ReadGithubActionsIam"
    effect = "Allow"
    actions = [
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ReadAccountIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "terraform_boundary" {
  name        = "${local.name_prefix}-github-terraform-boundary"
  description = "Maximum permissions available to the GitHub Actions Terraform role."
  policy      = data.aws_iam_policy_document.terraform_boundary.json
}

resource "aws_iam_role_policy_attachment" "terraform" {
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.terraform.arn
}
