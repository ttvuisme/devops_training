provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

# Subnets
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags = {
    Name = "public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "igw"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public-route"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "allow_all" {
  name        = "allow-all"
  description = "Allow all inbound/outbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-all"
  }
}

# EC2 Instance (Dev environment)
resource "aws_instance" "dev_ec2" {
  ami                         = var.ec2_ami
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.allow_all.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  user_data = file("scripts/install_docker.sh")

  tags = {
    Name = "dev-ec2"
  }
}

# PostgreSQL RDS
resource "aws_db_instance" "postgres" {
  identifier         = "postgres-db"
  engine             = "postgres"
  engine_version     = "15.3"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  db_name            = "appdb"
  username           = var.db_user
  password           = var.db_password
  skip_final_snapshot = true
  publicly_accessible = false
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
}

resource "aws_db_subnet_group" "db_subnet" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.public.id]
  tags = {
    Name = "db-subnet-group"
  }
}

# EKS Cluster (simplified)
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "prod-eks-cluster"
  cluster_version = "1.29"
  subnets         = [aws_subnet.public.id]
  vpc_id          = aws_vpc.main.id

  eks_managed_node_groups = {
    default = {
      desired_capacity = 1
      max_capacity     = 2
      min_capacity     = 1

      instance_types = ["t3.small"]
    }
  }

  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}
