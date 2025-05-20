module "vpc" {
  source              = "../../modules/vpc"
  vpc_cidr            = "10.10.0.0/16"
  name_prefix         = "coffeeshop-dev"
  public_subnet_count = 2

  azs                 = slice(data.aws_availability_zones.available.names, 0, 2)
}

data "aws_availability_zones" "available" {
  state = "available" # Explicitly filter only available AZs
}

data "aws_caller_identity" "current" {}

resource "aws_security_group" "dev_sg" {
  name        = "dev-sg"
  description = "Allow SSH and app traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "dev_ec2" {
  ami           = var.ami_id
  instance_type = "t2.medium"
  key_name      = var.key_name
  subnet_id     = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.dev_sg.id] 

  user_data = templatefile("${path.module}/../../scripts/install_docker.tpl.sh", {
    DOCKER_USERNAME = var.docker_username
    DOCKER_PAT      = var.docker_pat
  })
  
  root_block_device {
    volume_size = 10  # GB
    volume_type = "gp3"
    encrypted   = true
  }
  tags = {
    Name = "coffeeshop-dev"
  }
}
