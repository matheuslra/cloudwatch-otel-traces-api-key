terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    # Transaction Search isn't in the aws provider, so it comes from the Cloud Control provider.
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.100"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "awscc" {
  region = var.region
}
