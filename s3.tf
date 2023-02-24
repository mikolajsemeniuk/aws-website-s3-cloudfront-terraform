resource "aws_s3_bucket" "this" {
  # Important to provide a global unique bucket name.
  # The name of the bucket without the www. prefixm normally domain_name.
  # Otherwise there could be an error BucketAlreadyExistsError.
  bucket = "boodyvo-go-example-static-v3"
}

# Versioning is a means of keeping multiple variants of an object in the same bucket. 
# You can use versioning to preserve, retrieve, and restore every version of every object stored in your Amazon S3 bucket. 
# With versioning, you can easily recover from both unintended user actions and application failures.
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Disabled"
  }
}

# ACL is set to private because only CloudFront should access S3 bucket and nobody else.
resource "aws_s3_bucket_acl" "this" {
  bucket = aws_s3_bucket.this.id
  acl    = "private"
}

# Make bucket private and remove all potential access.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  ignore_public_acls      = true
  block_public_acls       = true
  restrict_public_buckets = true
  block_public_policy     = true
}


# Control ownership of objects written to this bucket from other AWS accounts and the use of access control lists (ACLs). 
# Object ownership determines who can specify access to objects.
# AWS recommendens to enforce bucket ownership for all objects that are added to the bucket. 
# It will disable ACL usage so the bucket always has full control over objects and manage access to them via privileges.
# All objects in this bucket are owned by this account. 
# Access to this bucket and its objects is specified using only policies.
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.bucket

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


# Encoding for all allowed files in "static" folder.
locals {
  content_type_map = {
    css : "text/css; charset=UTF-8"
    js : "text/js; charset=UTF-8"
    svg : "image/svg+xml"
  }
}

# Configure S3 to host a static website.
# 
# References: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_website_configuration
resource "aws_s3_bucket_website_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  routing_rule {
    redirect {
      replace_key_with = "index.html"
    }
  }
}

# Copy files and folders from "static" folder to S3 bucket.
resource "aws_s3_bucket_object" "assets" {
  for_each = fileset("${path.module}/static", "**")

  bucket = aws_s3_bucket.this.id
  key    = each.value
  source = "${path.module}/static/${each.value}"
  etag   = filemd5("${path.module}/static/${each.value}")

  // simplification of the content type serving
  content_type = lookup(
    local.content_type_map,
    split(".", basename(each.value))[length(split(".", basename(each.value))) - 1],
    "text/html; charset=UTF-8",
  )
}

# Create necessary permissions for CloudFront.
data "aws_iam_policy_document" "this" {
  statement {
    actions = ["s3:GetObject"]

    // as we use the bucket only for static content we provide an access for all objects in the bucket
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type = "AWS"
      // the identity specifies in cloudfront.tf
      identifiers = [aws_cloudfront_origin_access_identity.this.iam_arn]
    }
  }
}

# Attach policy to S3 bucket.
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this.json
}

# Configure CORS.
resource "aws_s3_bucket_cors_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = []
    max_age_seconds = 3600
  }
}
