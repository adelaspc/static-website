moved {
  from = module.s3.aws_s3_bucket_policy.allow_cloudfront_access
  to   = aws_s3_bucket_policy.allow_cloudfront_access
}

data "aws_iam_policy_document" "allow_cloudfront_access" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      module.s3.bucket_arn,
      "${module.s3.bucket_arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "AllowCloudFrontDistributionReadOnly"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = ["${module.s3.bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront.distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_cloudfront_access" {
  bucket = module.s3.bucket_id
  policy = data.aws_iam_policy_document.allow_cloudfront_access.json
}
