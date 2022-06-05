terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.15.1"
    }
  }
}

provider "aws" {
  region = var.region #Frankfurt

  access_key = var.access_key
  secret_key = var.secret_key
}
