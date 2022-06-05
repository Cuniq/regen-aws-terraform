variable "region" {
  default     = "eu-central-1"
  description = "AWS Region"
  type        = string
}

variable "vpc-cidr" {
  default     = "10.0.252.0/22"
  description = "VPC CIDR Block"
  type        = string
}

variable "public_subnets_cidr_ip4" {
  default     = ["10.0.252.0/26", "10.0.252.64/26", "10.0.252.128/26"]
  description = "CIDR of public subnets"
  type        = list(string)
}

variable "private_backend_cidr_ip4" {
  default     = ["10.0.254.0/26", "10.0.254.64/26", "10.0.254.128/26"]
  description = "CIDR of private backend subnets"
  type        = list(string)
}

variable "private_database_cidr_ip4" {
  default     = ["10.0.255.0/26", "10.0.255.64/26", "10.0.255.128/26"]
  description = "CIDR of private database subnets"
  type        = list(string)
}

variable "availability_zones" {
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  description = "AZs we want to deploy our subnets"
  type        = list(string)
}

variable "db_username" {
  description = "Database user name"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  type        = string
  sensitive   = true
}

variable "access_key" {
  description = "Account's access key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Account's secret key"
  type        = string
  sensitive   = true
}
