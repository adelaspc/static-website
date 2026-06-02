locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = local.common_tags
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
      values   = ["repo:${var.github_repository}:ref:refs/heads/${var.github_deploy_branch}"]
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
      values   = ["repo:${var.github_repository}:ref:refs/heads/${var.github_deploy_branch}"]
    }
  }
}

data "aws_iam_policy_document" "terraform_plan_assume_role" {
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
      values   = ["repo:${var.github_repository}:pull_request"]
    }
  }
}

resource "aws_iam_role" "frontend_deploy" {
  name               = "${local.name_prefix}-github-frontend-deploy"
  assume_role_policy = data.aws_iam_policy_document.frontend_deploy_assume_role.json
  description        = "GitHub Actions role for deploying static frontend assets to S3."

  tags = local.common_tags
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

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "frontend_deploy" {
  role       = aws_iam_role.frontend_deploy.name
  policy_arn = aws_iam_policy.frontend_deploy.arn
}

resource "aws_iam_role" "terraform" {
  name               = "${local.name_prefix}-github-terraform"
  assume_role_policy = data.aws_iam_policy_document.terraform_assume_role.json
  description        = "GitHub Actions role for managing this Terraform stack."

  tags = local.common_tags
}

data "aws_iam_policy_document" "terraform" {
  statement {
    sid    = "ManageProjectS3"
    effect = "Allow"
    actions = [
      "s3:*",
    ]

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
    sid    = "AccessTerraformStateBucket"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${var.terraform_state_bucket_name}",
      "arn:aws:s3:::${var.terraform_state_bucket_name}/*",
    ]
  }

  statement {
    sid    = "AccessTerraformLockTable"
    effect = "Allow"
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]

    resources = ["arn:aws:dynamodb:*:*:table/${var.terraform_lock_table_name}"]
  }

  statement {
    sid    = "ManageStaticWebsiteEdge"
    effect = "Allow"
    actions = [
      "acm:*",
      "cloudfront:*",
      "cloudwatch:*",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ManageGithubActionsIam"
    effect = "Allow"
    actions = [
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:AttachRolePolicy",
      "iam:CreateOpenIDConnectProvider",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:DeleteOpenIDConnectProvider",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:TagPolicy",
      "iam:TagRole",
      "iam:UntagOpenIDConnectProvider",
      "iam:UntagPolicy",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateOpenIDConnectProviderThumbprint",
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

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "terraform" {
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.terraform.arn
}

resource "aws_iam_role" "terraform_plan" {
  name               = "${local.name_prefix}-github-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.terraform_plan_assume_role.json
  description        = "GitHub Actions role for pull request Terraform plans."

  tags = local.common_tags
}

data "aws_iam_policy_document" "terraform_plan" {
  statement {
    sid    = "ReadProjectS3"
    effect = "Allow"
    actions = [
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
      "s3:GetObject",
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

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
    sid    = "AccessTerraformStateBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${var.terraform_state_bucket_name}",
      "arn:aws:s3:::${var.terraform_state_bucket_name}/*",
    ]
  }

  statement {
    sid    = "AccessTerraformStateLockfile"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = ["arn:aws:s3:::${var.terraform_state_bucket_name}/*.tflock"]
  }

  statement {
    sid    = "AccessTerraformLockTable"
    effect = "Allow"
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
    ]

    resources = ["arn:aws:dynamodb:*:*:table/${var.terraform_lock_table_name}"]
  }

  statement {
    sid    = "ReadStaticWebsiteEdge"
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListTagsForCertificate",
      "cloudfront:GetCachePolicy",
      "cloudfront:GetCloudFrontOriginAccessIdentity",
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:GetResponseHeadersPolicy",
      "cloudfront:ListCachePolicies",
      "cloudfront:ListTagsForResource",
      "cloudwatch:DescribeAlarms",
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
      "sts:GetCallerIdentity",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "terraform_plan" {
  name        = "${local.name_prefix}-github-terraform-plan"
  description = "Allows GitHub Actions to run pull request Terraform plans with limited permissions."
  policy      = data.aws_iam_policy_document.terraform_plan.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "terraform_plan" {
  role       = aws_iam_role.terraform_plan.name
  policy_arn = aws_iam_policy.terraform_plan.arn
}
