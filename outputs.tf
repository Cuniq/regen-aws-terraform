# output "aws_ami_amazon_linux_name" {
#   value       = data.aws_ami.amazon_linux.name
#   description = "The name of the AMI we are going to use"
# }

# output "aws_ami_custom_java_name" {
#   value       = data.aws_ami.custom_ami.name
#   description = "The name of our custom AMI we are going to use"
# }

# output "aws_subnet_project-public_cidr_block" {
#   value       = aws_subnet.project-public.*.cidr_block
#   description = "The CIDR of our public subnets"
# }

# output "aws_subnet_project_private_backend_cidr_block" {
#   value       = aws_subnet.project-private-backend.*.cidr_block
#   description = "The CIDR of our private backend subnets"
# }

# output "aws_subnet_project_private_database_cidr_block" {
#   value       = aws_subnet.project-private-database.*.cidr_block
#   description = "The CIDR of our private database subnets"
# }

# # output "aws_lb_alb_arn" {
# #   value       = aws_lb.project-application-load-balancer.arn
# #   description = "Load balancer ARN"
# # }
