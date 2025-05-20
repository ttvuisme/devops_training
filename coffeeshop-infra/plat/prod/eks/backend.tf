terraform {
  backend "s3" {
    bucket         = "coffeeshop-tfstate-prod"
    key            = "prod/eks/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}