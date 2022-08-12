provider "aws" {
  region = "sa-east-1"
}

### Migration Bucket ###

# resource "aws_s3_bucket" "main" {
#   bucket = "bucket-dms-mysql-migration-epomatti999"

#   tags = {
#     Name = "mysql-migration"
#   }
# }

# resource "aws_s3_bucket_acl" "main" {
#   bucket = aws_s3_bucket.main.id
#   acl    = "private"
# }

# resource "aws_s3_bucket_public_access_block" "main" {
#   bucket = aws_s3_bucket.main.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }


# ### DMS ###

# resource "aws_iam_role" "dms_vpc_role" {
#   name               = "DMSDiscoveryS3FullAccess"
#   assume_role_policy = file("${path.module}/policies/dms-vpc-role.json")
# }

# data "aws_iam_policy" "amazon_s3_fullaccess" {
#   arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
# }

# dms-vpc-role

resource "aws_iam_role" "dms_vpc_role" {
  name               = "dms-vpc-role"
  assume_role_policy = file("${path.module}/policies/dmsAssumeRolePolicyDocument.json")
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role_attach" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# dms-cloudwatch-logs-role

resource "aws_iam_role" "dms_cloudwatch_logs_role" {
  name               = "dms-cloudwatch-logs-role"
  assume_role_policy = file("${path.module}/policies/dmsAssumeRolePolicyDocument2.json")
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_logs_role_attach" {
  role       = aws_iam_role.dms_cloudwatch_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

# dms-access-for-endpoint

resource "aws_iam_role" "dms_access_for_endpoint_role" {
  name               = "dms-access-for-endpoint"
  assume_role_policy = file("${path.module}/policies/dmsAssumeRolePolicyDocument3.json")
}

resource "aws_iam_role_policy_attachment" "dms_access_for_endpoint_attach" {
  role       = aws_iam_role.dms_access_for_endpoint_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSRedshiftS3Role"
}


# Create a new replication instance
resource "aws_dms_replication_instance" "test" {
  allocated_storage          = 20
  apply_immediately          = true
  auto_minor_version_upgrade = true
  availability_zone          = "sa-east-1a"
  # engine_version             = "3.4.7"
  # kms_key_arn                  = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  multi_az = false
  # preferred_maintenance_window = "sun:10:30-sun:14:30"
  publicly_accessible         = true
  replication_instance_class  = "dms.t2.micro"
  replication_instance_id     = "dms-replication-instance"
  # replication_subnet_group_id = aws_dms_replication_subnet_group.test-dms-replication-subnet-group-tf.id

  tags = {
    Name = "dms-replication-instance"
  }

  # vpc_security_group_ids = [
  #   "sg-12345678",
  # ]

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_role_attach,
    aws_iam_role_policy_attachment.dms_cloudwatch_logs_role_attach,
    aws_iam_role_policy_attachment.dms_access_for_endpoint_attach
  ]
}
