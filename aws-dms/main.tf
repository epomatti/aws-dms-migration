provider "aws" {
  region = "sa-east-1"
}

locals {
  project_name         = "dms-migration"
  availability_zone_1a = "sa-east-1a"
  availability_zone_1b = "sa-east-1b"
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

### VPC ###

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  # Enable DNS hostnames 
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-${local.project_name}"
  }
}

### Internet Gateway ###

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${local.project_name}"
  }
}

### Route Tables ###

resource "aws_default_route_table" "internet" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "internet-rt"
  }
}

### Subnets ###

resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.80.0/24"
  availability_zone = local.availability_zone_1a

  # Auto-assign public IPv4 address
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.project_name}-public1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.100.0/24"
  availability_zone = local.availability_zone_1b

  # Auto-assign public IPv4 address
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.project_name}-public2"
  }
}


### Security Group ###

# Clean-up Default
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group" "main" {
  name        = "${local.project_name}-public-sc"
  description = "Allow Traffic"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.project_name}-public-sc"
  }
}

resource "aws_security_group_rule" "all_inbound" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.main.id
}

resource "aws_security_group_rule" "all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.main.id
}

### DMS ###

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

resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_description = "DMS replication subnet"
  replication_subnet_group_id          = "dms-replication-subnet-group"

  subnet_ids = [
    aws_subnet.public1.id, aws_subnet.public2.id
  ]
}

# Create a new replication instance
resource "aws_dms_replication_instance" "test" {
  allocated_storage          = 20
  apply_immediately          = true
  auto_minor_version_upgrade = true
  availability_zone          = local.availability_zone_1a
  # engine_version             = "3.4.7"
  # kms_key_arn                  = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  multi_az = false
  # preferred_maintenance_window = "sun:10:30-sun:14:30"
  publicly_accessible         = true
  replication_instance_class  = "dms.t2.micro"
  replication_instance_id     = "dms-replication-instance"
  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id

  tags = {
    Name = "dms-replication-instance"
  }

  vpc_security_group_ids = [
    aws_security_group.main.id
  ]

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_role_attach,
    aws_iam_role_policy_attachment.dms_cloudwatch_logs_role_attach,
    aws_iam_role_policy_attachment.dms_access_for_endpoint_attach
  ]
}
