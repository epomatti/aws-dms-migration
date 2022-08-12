provider "aws" {
  region = "sa-east-1"
}

### Locals ###

locals {
  affix      = "onprem-mysql"
  INADDR_ANY = "0.0.0.0/0"
}

### VPC ###
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  # Enable DNS hostnames 
  enable_dns_hostnames = true

  tags = {
    Name = local.affix
  }
}

### Internet Gateway ###

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${local.affix}"
  }
}

### Route Tables ###

resource "aws_default_route_table" "internet" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = local.INADDR_ANY
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "internet-rt"
  }
}

### Subnets ###

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "sa-east-1a"

  # Auto-assign public IPv4 address
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.affix}-subnet"
  }
}

### Security Group ###

# This will clean up all default entries
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group_rule" "ingress_ssh" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_default_security_group.default.id
}

### IAM Role ###

resource "aws_iam_role" "main" {
  name = local.affix

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm-managed-instance-core" {
  role       = aws_iam_role.main.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

### Key Pair ###
resource "aws_key_pair" "deployer" {
  key_name   = "mysql-server-key"
  public_key = file("${path.module}/id_rsa.pub")
}

### EC2 ###

resource "aws_network_interface" "main" {
  subnet_id       = aws_subnet.main.id
  security_groups = [aws_default_security_group.default.id]

  tags = {
    Name = "ni-${local.affix}"
  }
}

resource "aws_iam_instance_profile" "main" {
  name = "${local.affix}-profile"
  role = aws_iam_role.main.id
}

resource "aws_instance" "main" {
  ami           = "ami-0a9e90bd830396d02"
  instance_type = "t3.medium"

  iam_instance_profile = aws_iam_instance_profile.main.id
  key_name             = aws_key_pair.deployer.key_name

  # Detailed monitoring enabled
  monitoring = true

  # Install MySQL
  # user_data = file("${path.module}/mysql.sh")

  network_interface {
    network_interface_id = aws_network_interface.main.id
    device_index         = 0
  }

}
