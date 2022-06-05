# Our subnet structure
# 3 public subnets -> bastion hosts
# 3 private subnets -> EC2 servers (backend)
# 3 private subnets -> For our RDS (postgress). For free tier we will use one subnet, but we will create 3 for future proof-ity (multi-az)

# 64 (-5 because of amazon) per subnet is more than enough
# 64ips * 9 subnets = 576 IP in total
# So we need a VPC with 1024 IPs (10.0.252.0/22) to cover everything

locals {
  #Make sure all subnets and AZ have same length
  validate_subnets_have_same_length = (length(var.public_subnets_cidr_ip4) == length(var.private_backend_cidr_ip4) && length(var.private_backend_cidr_ip4) == length(var.availability_zones) && length(var.availability_zones) == length(var.private_backend_cidr_ip4)) ? true : tobool("All subnets and AZ must have the same length")

  vpc_cidr_ip4              = var.vpc-cidr
  public_subnets_cidr_ip4   = var.public_subnets_cidr_ip4
  private_backend_cidr_ip4  = var.private_backend_cidr_ip4
  private_database_cidr_ip4 = var.private_database_cidr_ip4
  availability_zones        = var.availability_zones

  free_tier_machine = "t2.micro"
}

#############################################################
# Data sources to get already created resources
#############################################################
#Get amazon kernel linux for bastion host
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

}

#For our backend EC2 our custom AMI, preloaded with all the tools we need
data "aws_ami" "custom_ami" {
  most_recent = true
  owners      = ["511278743332"]

  filter {
    name   = "name"
    values = ["project-backend-with-java-tomcat-and-jar"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

}

#Use this key for ssh
data "aws_key_pair" "auto_scale_key" {
  filter {
    name   = "key-name"
    values = ["auto-scale-group-apache-key"]
  }
}

#############################################################
# Create VPC
#############################################################

resource "aws_vpc" "project-vpc" {
  cidr_block           = local.vpc_cidr_ip4
  enable_dns_support   = "true" #gives you an internal domain name
  enable_dns_hostnames = "true" #gives you an internal host name
  enable_classiclink   = "false"
  instance_tenancy     = "default"

  tags = {
    Name = "project-vpc"
  }
}

#############################################################
# Create subnets
#############################################################
resource "aws_subnet" "project-public" {
  count = length(local.public_subnets_cidr_ip4)

  vpc_id                  = aws_vpc.project-vpc.id
  map_public_ip_on_launch = "true" //it makes this a public subnet

  cidr_block        = local.public_subnets_cidr_ip4[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "project-public-subnet-${local.availability_zones[count.index]}"
  }
}

resource "aws_subnet" "project-private-backend" {
  count = length(local.private_backend_cidr_ip4)

  vpc_id                  = aws_vpc.project-vpc.id
  map_public_ip_on_launch = "false" //it makes this a public subnet

  cidr_block        = local.private_backend_cidr_ip4[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "project-private-backend-subnet-${local.availability_zones[count.index]}"
  }
}

resource "aws_subnet" "project-private-database" {
  count = length(local.private_database_cidr_ip4)

  vpc_id                  = aws_vpc.project-vpc.id
  map_public_ip_on_launch = "false" //it makes this a public subnet

  cidr_block        = local.private_database_cidr_ip4[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "project-private-database-subnet-${local.availability_zones[count.index]}"
  }
}

#############################################################
# Create internet gateway
#############################################################
resource "aws_internet_gateway" "project-igw" {
  vpc_id = aws_vpc.project-vpc.id
  tags = {
    Name = "project-igw"
  }
}

#############################################################
# Create route tables
#############################################################

resource "aws_route_table" "project-public-rt" {
  vpc_id = aws_vpc.project-vpc.id

  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    //RT uses this IGW to reach internet
    gateway_id = aws_internet_gateway.project-igw.id
  }

  tags = {
    Name = "project-public-rt"
  }
}

resource "aws_route_table" "project-private-backend-rts" {
  count = length(local.private_backend_cidr_ip4)

  vpc_id = aws_vpc.project-vpc.id

  tags = {
    Name = "project-private-backend-rt-${count.index}"
  }
}

resource "aws_route_table" "project-private-database-rts" {
  count = length(local.private_database_cidr_ip4)

  vpc_id = aws_vpc.project-vpc.id

  tags = {
    Name = "project-private-database-rt-${count.index}"
  }
}

#############################################################
# Create route table associations
#############################################################

resource "aws_route_table_association" "project-rta-public-subnets" {
  count = length(aws_subnet.project-public)

  subnet_id      = aws_subnet.project-public[count.index].id
  route_table_id = aws_route_table.project-public-rt.id
}

resource "aws_route_table_association" "project-rta-private-backend-subnets" {
  count = length(aws_subnet.project-private-backend)

  subnet_id      = aws_subnet.project-private-backend[count.index].id
  route_table_id = aws_route_table.project-private-backend-rts[count.index].id
}

resource "aws_route_table_association" "project-rta-private-database-subnets" {
  count = length(aws_subnet.project-private-database)

  subnet_id      = aws_subnet.project-private-database[count.index].id
  route_table_id = aws_route_table.project-private-database-rts[count.index].id
}

#############################################################
# Create Postgres RDS subnet group
#############################################################
resource "aws_db_subnet_group" "project_rds_subnet_group" {
  name       = "project_rds_subnet_group"
  subnet_ids = [aws_subnet.project-private-database[0].id, aws_subnet.project-private-database[1].id, aws_subnet.project-private-database[2].id, aws_subnet.project-private-backend[0].id, aws_subnet.project-private-backend[1].id, aws_subnet.project-private-backend[2].id, aws_subnet.project-public[0].id, aws_subnet.project-public[1].id, aws_subnet.project-public[2].id]

  tags = {
    Name = "My DB subnet group"
  }
}

#############################################################
# Create Postgres RDS
#############################################################
resource "aws_db_instance" "project-postgress-rds" {
  identifier           = "project-postgres-db"
  engine               = "postgres"
  engine_version       = "13.4"
  instance_class       = "db.t3.micro"
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.postgres13"
  storage_type         = "gp2"
  port                 = 5432

  skip_final_snapshot = true

  allocated_storage            = 20
  max_allocated_storage        = 0 #Disable storag auto scaling
  monitoring_interval          = 0
  backup_retention_period      = 0
  auto_minor_version_upgrade   = false
  multi_az                     = false
  publicly_accessible          = false
  performance_insights_enabled = false
  deletion_protection          = false

  db_subnet_group_name   = aws_db_subnet_group.project_rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.project-allow-postgress-from-backend.id]

  depends_on = [
    aws_security_group.project-allow-postgress-from-backend
  ]

  tags = {
    Name = "Postgress 13.4 RDS - FREE TIER"
  }
}

#############################################################
# Create secutiry groups
#############################################################

resource "aws_security_group" "project-http-lb" {
  name        = "project-http-lb"
  description = "Enable load balancers to receive HTTP traffic"
  vpc_id      = aws_vpc.project-vpc.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project-http-lb"
  }
}

resource "aws_security_group" "project-http-from-lb" {
  name        = "project-http-from-lb"
  description = "Allow HTTP from load balancers"
  vpc_id      = aws_vpc.project-vpc.id

  ingress {
    description     = "HTTP from the Load Balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.project-http-lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_security_group.project-http-lb
  ]

  tags = {
    Name = "project-http-from-lb"
  }
}

resource "aws_security_group" "project-bastion-ssh" {
  name        = "project-bastion-ssh"
  description = "Enable SSH connection. We need multiple persons to be able to connect"
  vpc_id      = aws_vpc.project-vpc.id

  ingress {
    description = "SSH from the internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project-bastion-ssh"
  }
}

resource "aws_security_group" "project-ssh-from-bastion" {
  name        = "project-ssh-from-bastion"
  description = "Enable SSH connection. We need multiple persons to be able to connect"
  vpc_id      = aws_vpc.project-vpc.id

  ingress {
    description     = "SSH from the internet"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.project-bastion-ssh.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project-ssh-from-bastion"
  }
}

resource "aws_security_group" "project-postgresql-backend" {
  name        = "project-postgresql-backend"
  description = "Allows backend to receive traffic from everyone at postgress port"
  vpc_id      = aws_vpc.project-vpc.id

  ingress {
    description = "Postgress port"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project-ssh-from-bastion"
  }
}

resource "aws_security_group" "project-allow-postgress-from-backend" {
  name        = "project-allow-postgress-from-backend"
  description = "Allows postgress to receive traffic only from backend"
  vpc_id      = aws_vpc.project-vpc.id

  ingress {
    description     = "Postgress port"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.project-postgresql-backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_security_group.project-postgresql-backend
  ]

  tags = {
    Name = "project-ssh-from-bastion"
  }
}

# #############################################################
# # Create Launch template
# #############################################################

resource "aws_launch_template" "project-auto-scale-backend" {
  name        = "project-backend-launch-template"
  description = "Launch template for backend autoscale group."

  instance_type = local.free_tier_machine

  vpc_security_group_ids = [aws_security_group.project-http-from-lb.id, aws_security_group.project-ssh-from-bastion.id, aws_security_group.project-postgresql-backend.id]

  key_name  = data.aws_key_pair.auto_scale_key.key_name
  image_id  = data.aws_ami.custom_ami.image_id
  user_data = base64encode(templatefile("${path.module}/create-apache.sh", { db_endpoint = aws_db_instance.project-postgress-rds.endpoint, db_username = var.db_username, db_password = var.db_password, db_name = var.db_name }))

  tags = {
    Name = "project-backend-lt"
  }
}

resource "aws_launch_template" "project-auto-scale-bastion" {
  name        = "project-bastion-launch-template"
  description = "Launch template for bastion autoscale group."

  instance_type = local.free_tier_machine

  vpc_security_group_ids = [aws_security_group.project-bastion-ssh.id]

  key_name = data.aws_key_pair.auto_scale_key.key_name
  image_id = data.aws_ami.amazon_linux.image_id

  tags = {
    Name = "project-bastion-lt"
  }
}

#############################################################
# Create Empty Target group
#############################################################

resource "aws_lb_target_group" "project-lb-backend-autoscale-group-tg" {
  name             = "project-backend-tg"
  vpc_id           = aws_vpc.project-vpc.id
  protocol         = "HTTP"
  protocol_version = "HTTP1"
  port             = 80
  target_type      = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 3
    unhealthy_threshold = 2
  }

  stickiness {
    cookie_duration = 86400
    cookie_name     = ""
    enabled         = false
    type            = "lb_cookie"
  }

  load_balancing_algorithm_type = "round_robin"

  tags = {
    Name = "project-backend-tg"
  }
}

#############################################################
# Create Application Load balancer
#############################################################

resource "aws_lb" "project-application-load-balancer" {
  name               = "project-lb"
  internal           = false
  ip_address_type    = "ipv4"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.project-http-lb.id]

  subnets = aws_subnet.project-public.*.id

  desync_mitigation_mode     = "defensive"
  enable_deletion_protection = false

  # Maybe check this later for logging/monitoring 
  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.bucket
  #   prefix  = "test-lb"
  #   enabled = true
  # }

  tags = {
    Name = "Project Application LB internet-facing"
  }
}

#############################################################
# Create Auto scale group -> put it in target group
#############################################################

resource "aws_autoscaling_group" "project-ec2-autoscaling-group" {

  name                = "project-backend-asg"
  vpc_zone_identifier = aws_subnet.project-private-backend.*.id
  target_group_arns   = [aws_lb_target_group.project-lb-backend-autoscale-group-tg.arn]

  health_check_type = "EC2"

  desired_capacity = 1
  max_size         = 3
  min_size         = 1

  default_cooldown = 180

  launch_template {
    id = aws_launch_template.project-auto-scale-backend.id
  }

  depends_on = [aws_launch_template.project-auto-scale-backend]

  tag {
    key                 = "Name"
    value               = "Backend EC2"
    propagate_at_launch = true
  }
  tag {
    key                 = "asg_name"
    value               = "project-asg-t2micro"
    propagate_at_launch = true
  }

}

resource "aws_autoscaling_group" "project-bastion-autoscaling-group" {

  name                = "project-bastion-asg"
  vpc_zone_identifier = aws_subnet.project-public.*.id

  health_check_type = "EC2"

  desired_capacity = 1
  max_size         = 3
  min_size         = 1

  default_cooldown = 180

  launch_template {
    id = aws_launch_template.project-auto-scale-bastion.id
  }

  depends_on = [aws_launch_template.project-auto-scale-bastion]

  tag {
    key                 = "Name"
    value               = "Bastion EC2"
    propagate_at_launch = true
  }
  tag {
    key                 = "asg_name"
    value               = "project-asg-bastion-t2micro"
    propagate_at_launch = true
  }

}

#############################################################
# Create Load Balancer Listener -> Listen for connections on 
# LB and forward everything to target group
#############################################################

resource "aws_lb_listener" "project-lb-listener" {
  load_balancer_arn = aws_lb.project-application-load-balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.project-lb-backend-autoscale-group-tg.arn
  }
}

#############################################################
# Create AutoScaling Policy base on CPU Utilization
#############################################################

resource "aws_autoscaling_policy" "project-asg-target-tracking-policy" {
  name                      = "project-asg-target-tracking-policy"
  policy_type               = "TargetTrackingScaling"
  autoscaling_group_name    = aws_autoscaling_group.project-ec2-autoscaling-group.name
  estimated_instance_warmup = 60

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = "60"

  }
}

resource "aws_autoscaling_policy" "project-asg-bastion-target-tracking-policy" {
  name                   = "project-asg-bastion-target-tracking-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.project-bastion-autoscaling-group.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = "80"

  }
}
