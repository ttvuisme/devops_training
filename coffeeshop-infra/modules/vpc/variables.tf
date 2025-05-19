variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "name_prefix" {
  type    = string
  default = "dev"
}

variable "public_subnet_count" {
  type    = number
  default = 2
}


variable "azs" {
  description = "List of availability zones"
  type        = list(string)
  default = []
}
