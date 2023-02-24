terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

// This block tells Terraform that we're going to provision AWS resources.
provider "aws" {
  region                  = "eu-central-1"
  shared_credentials_file = "/Users/mikolaj.semeniuk/.aws/credentials"
  profile                 = "default"
}
