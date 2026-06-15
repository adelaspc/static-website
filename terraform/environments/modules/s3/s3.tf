data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_s3_bucket" "static_website" {
  #checkov:skip=CKV_AWS_18:CloudFront viewer access logs provide request visibility; additional S3 server access logging is intentionally omitted for this demo.
  #checkov:skip=CKV2_AWS_62:The deployment model does not require S3 event-driven processing or notifications.
  #checkov:skip=CKV_AWS_145:S3-managed AES-256 encryption is accepted for this portfolio environment to avoid KMS cost and key operations.
  #checkov:skip=CKV_AWS_144:Cross-region disaster recovery is outside the documented scope of this single-region portfolio environment.
  bucket = local.website_bucket_name

  lifecycle {
    precondition {
      condition     = local.valid_bucket_names.website
      error_message = "The final website bucket name '${local.website_bucket_name}' is not a valid general purpose S3 bucket name. It must satisfy S3 syntax and reserved-name rules and be no longer than 63 characters."
    }
  }

  tags = {
    Name = local.website_bucket_name
  }
}

resource "aws_s3_bucket" "cloudfront_logs" {
  #checkov:skip=CKV_AWS_18:Enabling server access logging on the log destination would require another destination bucket and add low-value recursive logging complexity.
  #checkov:skip=CKV2_AWS_62:CloudFront log delivery does not require S3 event notifications in this architecture.
  #checkov:skip=CKV_AWS_145:S3-managed AES-256 encryption is accepted for this portfolio log bucket to avoid KMS cost and key operations.
  #checkov:skip=CKV_AWS_144:Cross-region log replication is outside the documented recovery objective for this portfolio environment.
  bucket = local.cloudfront_logs_bucket_name

  lifecycle {
    precondition {
      condition     = local.valid_bucket_names.cloudfront_logs
      error_message = "The final CloudFront log bucket name '${local.cloudfront_logs_bucket_name}' is not a valid general purpose S3 bucket name. It must satisfy S3 syntax and reserved-name rules and be no longer than 63 characters."
    }
  }

  tags = {
    Name = local.cloudfront_logs_bucket_name
  }
}

resource "aws_s3_bucket_public_access_block" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.static_website]
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    id     = "expire-cloudfront-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.cloudfront_log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.cloudfront_log_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.cloudfront_logs]
}

data "aws_iam_policy_document" "cloudfront_logs" {
  statement {
    sid     = "AllowLogDeliveryAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]

    resources = [aws_s3_bucket.cloudfront_logs.arn]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:us-east-1:${data.aws_caller_identity.current.account_id}:*"]
    }
  }

  statement {
    sid     = "AllowCloudFrontLogDelivery"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    resources = [
      "${aws_s3_bucket.cloudfront_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:us-east-1:${data.aws_caller_identity.current.account_id}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.cloudfront_logs.arn,
      "${aws_s3_bucket.cloudfront_logs.arn}/*",
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
}

resource "aws_s3_bucket_policy" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  policy = data.aws_iam_policy_document.cloudfront_logs.json
}
