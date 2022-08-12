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

resource "aws_iam_role" "dms_vpc_role" {
  name               = "DMSDiscoveryS3FullAccess"
  assume_role_policy = file("${path.module}/policies/dms-vpc-role.json")
}

data "aws_iam_policy" "amazon_s3_fullaccess" {
  arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "dms_s3_attach" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = data.aws_iam_policy.amazon_s3_fullaccess.arn
}
