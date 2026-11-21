# EBS snapshots of the PostgreSQL data volume (Data Lifecycle Manager)

data "aws_iam_policy_document" "dlm_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm" {
  name               = "${local.name}-dlm"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume.json
}

resource "aws_iam_role_policy_attachment" "dlm" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "postgres_data" {
  description        = "Daily snapshots of the PostgreSQL data volume"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    target_tags    = { Snapshot = "${local.name}-postgres-data" }

    schedule {
      name      = "daily"
      copy_tags = true

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["01:00"]
      }

      retain_rule {
        count = var.snapshot_retain_count
      }

      tags_to_add = { SnapshotCreator = "dlm" }
    }
  }
}

# Logical backups (pg_dump) uploaded by the database host

resource "aws_s3_bucket" "backups" {
  bucket        = "${local.name}-backups-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expire-old-dumps"
    status = "Enabled"

    filter {
      prefix = "postgres/"
    }

    expiration {
      days = var.backup_retention_days
    }
  }
}

data "aws_iam_policy_document" "backups_bucket_tls" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.backups.arn, "${aws_s3_bucket.backups.arn}/*"]

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

resource "aws_s3_bucket_policy" "backups" {
  bucket = aws_s3_bucket.backups.id
  policy = data.aws_iam_policy_document.backups_bucket_tls.json

  depends_on = [aws_s3_bucket_public_access_block.backups]
}

data "aws_iam_policy_document" "backups_write" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.backups.arn}/postgres/*"]
  }
}

resource "aws_iam_role_policy" "backups_write" {
  name   = "backups-write"
  role   = aws_iam_role.ec2["postgres"].id
  policy = data.aws_iam_policy_document.backups_write.json
}
