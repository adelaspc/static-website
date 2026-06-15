locals {
  website_bucket_name         = "${var.project}-${var.bucket_name}"
  cloudfront_logs_bucket_name = "${var.project}-${var.bucket_name}-cf-logs"

  reserved_bucket_prefixes = ["xn--", "sthree-", "amzn-s3-demo-"]
  reserved_bucket_suffixes = ["-s3alias", "--ol-s3", ".mrap", "--x-s3", "--table-s3"]

  bucket_names = {
    website         = local.website_bucket_name
    cloudfront_logs = local.cloudfront_logs_bucket_name
  }

  valid_bucket_names = {
    for key, name in local.bucket_names : key => (
      length(name) >= 3 &&
      length(name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", name)) &&
      !strcontains(name, "..") &&
      !can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", name)) &&
      alltrue([for prefix in local.reserved_bucket_prefixes : !startswith(name, prefix)]) &&
      alltrue([for suffix in local.reserved_bucket_suffixes : !endswith(name, suffix)])
    )
  }
}
