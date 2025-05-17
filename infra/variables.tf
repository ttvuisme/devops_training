variable "aws_region" {
  default = "us-east-1"
}

variable "ec2_ami" {
  description = "Amazon Linux AMI ID"
  default     = "ami-test" # Update if needed
}

variable "key_name" {
  description = "SSH Key name"
}

variable "db_user" {
  default = "postgres"
}

variable "db_password" {
  default = "postgres1234"
  sensitive = true
}
