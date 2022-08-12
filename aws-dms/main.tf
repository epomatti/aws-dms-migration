provider "aws" {
  region = "sa-east-1"
}

### Migration Bucket ###

resource "aws_s3_bucket" "main" {
  bucket = "bucket-dms-mysql-migration-epomatti999"

  tags = {
    Name = "mysql-migration"
  }
}

resource "aws_s3_bucket_acl" "main" {
  bucket = aws_s3_bucket.main.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


### DMS ###

resource "aws_iam_role" "dms_role" {
  name = "sandbox-rds-mysql-migration-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "dms.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "dms_s3_policy" {
  name = "sandbox-rds-mysql-migration-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutObjectTagging"
        ]
        Resource = "arn:aws:s3:::${aws_s3_bucket.main.bucket}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${aws_s3_bucket.main.bucket}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_s3_attach" {
  role       = aws_iam_role.dms_role.name
  policy_arn = aws_iam_policy.dms_s3_policy.arn
}
