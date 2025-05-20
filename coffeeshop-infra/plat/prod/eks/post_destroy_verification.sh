# Check for remaining EC2 instances
aws ec2 describe-instances --filters "Name=tag:terraform,Values=true" --query "Reservations[].Instances[].[InstanceId,Tags[?Key=='Name'].Value|[0]]"

# Check VPC resources (subnets, gateways, etc.)
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=coffeeshop-*"
aws ec2 describe-subnets --filters "Name=tag:Name,Values=coffeeshop-*"

# Check EKS clusters
aws eks list-clusters --region ap-southeast-1

# Check S3 buckets (especially for Terraform state)
aws s3 ls | grep coffeeshop

# Check IAM resources
aws iam list-roles --query "Roles[?contains(RoleName, 'coffeeshop')].RoleName"
aws iam list-policies --query "Policies[?contains(PolicyName, 'coffeeshop')].PolicyName"