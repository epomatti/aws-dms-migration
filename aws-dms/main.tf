provider "aws" {
  region = "sa-east-1"
}

variable "ec2_mysql_endpoint" {
  type = string
}

locals {
  project_name         = "dms-migration"
  availability_zone_1a = "sa-east-1a"
  availability_zone_1b = "sa-east-1b"
  availability_zone_1c = "sa-east-1c"
}

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

resource "aws_subnet" "public3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.120.0/24"
  availability_zone = local.availability_zone_1c

  # Auto-assign public IPv4 address
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.project_name}-public3"
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
    aws_subnet.public1.id, aws_subnet.public2.id, aws_subnet.public3.id
  ]
}

# Create a new replication instance
resource "aws_dms_replication_instance" "main" {
  allocated_storage          = 20
  apply_immediately          = true
  auto_minor_version_upgrade = true
  availability_zone          = local.availability_zone_1a
  engine_version             = "3.4.7"
  multi_az                   = false
  publicly_accessible        = true

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

### Target Databases ###

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.public1.id, aws_subnet.public2.id, aws_subnet.public3.id]
}

// MySQL

resource "aws_db_instance" "target_mysql" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "8.0.28"
  instance_class       = "db.t3.micro"
  db_name              = "testdb"
  username             = "dmsuser"
  password             = "passw0rd"
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible  = true

  vpc_security_group_ids = [aws_security_group.main.id]
  db_subnet_group_name   = aws_db_subnet_group.default.id
}

// PostgreSQL

resource "aws_db_instance" "target_postgres" {
  allocated_storage   = 10
  engine              = "postgres"
  engine_version      = "14.4"
  instance_class      = "db.t3.micro"
  db_name             = "testdb"
  username            = "dmsuser"
  password            = "passw0rd"
  skip_final_snapshot = true
  publicly_accessible = true

  vpc_security_group_ids = [aws_security_group.main.id]
  db_subnet_group_name   = aws_db_subnet_group.default.id
}

// Aurora

resource "aws_rds_cluster" "target_aurora" {
  cluster_identifier  = "aurora-cluster"
  engine              = "aurora-mysql"
  engine_version      = "8.0.mysql_aurora.3.02.0"
  availability_zones  = [local.availability_zone_1a, local.availability_zone_1b, local.availability_zone_1c]
  database_name       = "testdb"
  master_username     = "dmsuser"
  master_password     = "passw0rd"
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.main.id]
  db_subnet_group_name   = aws_db_subnet_group.default.id
}

resource "aws_rds_cluster_instance" "aurora_instances" {
  count               = 1
  identifier          = "aurora-mysql-instance"
  cluster_identifier  = aws_rds_cluster.target_aurora.id
  instance_class      = "db.t3.medium"
  engine              = aws_rds_cluster.target_aurora.engine
  engine_version      = aws_rds_cluster.target_aurora.engine_version
  publicly_accessible = true
}

### Migration Endpoints ###

resource "aws_dms_endpoint" "source_mysql" {
  database_name = "testdb"
  endpoint_id   = "source-mysql"
  endpoint_type = "source"
  engine_name   = "mysql"
  username      = "dmsuser"
  password      = "passw0rd"
  port          = 3306
  server_name   = var.ec2_mysql_endpoint

  tags = {
    Name = "source-mysql"
  }
}

resource "aws_dms_endpoint" "target_rds_mysql" {
  database_name = "testdb"
  endpoint_id   = "target-rds-mysql"
  endpoint_type = "target"
  engine_name   = "mysql"
  username      = "dmsuser"
  password      = "passw0rd"
  port          = 3306
  server_name   = aws_db_instance.target_mysql.address

  tags = {
    Name = "target-rds-mysql"
  }
}

resource "aws_dms_endpoint" "target_rds_postgres" {
  database_name = "testdb"
  endpoint_id   = "target-rds-postgres"
  endpoint_type = "target"
  engine_name   = "postgres"
  username      = "dmsuser"
  password      = "passw0rd"
  port          = 5432
  server_name   = aws_db_instance.target_postgres.address

  tags = {
    Name = "target-rds-postgres"
  }
}

resource "aws_dms_endpoint" "target_rds_aurora" {
  database_name = "testdb"
  endpoint_id   = "target-rds-aurora"
  endpoint_type = "target"
  engine_name   = "aurora"
  username      = "dmsuser"
  password      = "passw0rd"
  port          = 3306
  server_name   = aws_rds_cluster.target_aurora.endpoint

  tags = {
    Name = "target-rds-aurora"
  }
}

# ### Replication Task ###

resource "aws_dms_replication_task" "rds_mysql" {
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  replication_task_id      = "replication-task-rds-mysql-1"
  source_endpoint_arn      = aws_dms_endpoint.source_mysql.endpoint_arn
  table_mappings           = file("${path.module}/table-mappings.json")
  target_endpoint_arn      = aws_dms_endpoint.target_rds_mysql.endpoint_arn

  lifecycle {
    ignore_changes = [
      replication_task_settings
    ]
  }
}

resource "aws_dms_replication_task" "rds_postgres" {
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  replication_task_id      = "replication-task-rds-postgres-1"
  source_endpoint_arn      = aws_dms_endpoint.source_mysql.endpoint_arn
  table_mappings           = file("${path.module}/table-mappings.json")
  target_endpoint_arn      = aws_dms_endpoint.target_rds_postgres.endpoint_arn

  lifecycle {
    ignore_changes = [
      replication_task_settings
    ]
  }
}

resource "aws_dms_replication_task" "rds_aurora" {
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  replication_task_id      = "replication-task-rds-aurora-1"
  source_endpoint_arn      = aws_dms_endpoint.source_mysql.endpoint_arn
  table_mappings           = file("${path.module}/table-mappings.json")
  target_endpoint_arn      = aws_dms_endpoint.target_rds_aurora.endpoint_arn

  lifecycle {
    ignore_changes = [
      replication_task_settings
    ]
  }
}

# ### Outputs ###

output "mysql_target" {
  value = aws_db_instance.target_mysql.address
}

output "postgres_target" {
  value = aws_db_instance.target_postgres.address
}

output "aurora_target" {
  value = aws_rds_cluster.target_aurora.endpoint
}
