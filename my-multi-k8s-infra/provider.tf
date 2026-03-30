terraform {
  required_version = ">= 1.0" # מוודא שה-Terraform עצמו לא ענתיקה

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # זה יכריח אותו להשתמש בגרסה 5 החדשה
    }
  }
}

provider "aws" {
  region = "us-east-1"
}