terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Data Source: legt nichts an, fragt AWS nur "Wer bin ich?"
data "aws_caller_identity" "aktuell" {}

output "account_id" {
  value = data.aws_caller_identity.aktuell.account_id
}

output "benutzer_arn" {
  value = data.aws_caller_identity.aktuell.arn
}
