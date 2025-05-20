variable "aws_region" {
  description = "AWS region to deploy to"
  default     = "ap-southeast-1"
}

variable "ami_id" {
  description = "AMI ID to use for EC2"
  default     = "ami-0afc7fe9be84307e4" # Amazon Linux 2023 AMI 2023.7.20250512.0 x86_64 HVM kernel-6.1
}

variable "instance_type" {
  description = "Instance type for EC2"
  default     = "t2.medium"
}

variable "key_name" {
  description = "Name of the key pair"
  default     = "dev-key"
}

variable "vpc_id" {
  description = "VPC ID to use"
  type        = string
  default = "vpc-036478b69897378e3"
}

variable "docker_pat" {
  description = "Docker Hub Personal Access Token"
  type        = string
  // Sensitive information
  sensitive     = true
}

variable "docker_username" {
  description = "Docker Hub username"
  type        = string
  default     = "ttvucse"
}
  