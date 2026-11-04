# ---------------------------------------------------------------
# Einstellungen für Terraform selbst
# ---------------------------------------------------------------
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote Backend: Der State liegt im S3-Bucket aus Kapitel 08.
  # Wichtig: ein NEUER key – sonst überschreibst du den State aus Kapitel 08/09!
  backend "s3" {
    bucket       = "terraform-state-DEIN-NAME-12345"
    key          = "abschlussprojekt/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# ---------------------------------------------------------------
# Provider: Mit welcher Cloud und welcher Region sprechen wir?
# ---------------------------------------------------------------
provider "aws" {
  region = "us-east-1"

  # Diese Tags bekommt JEDE Ressource automatisch
  default_tags {
    tags = {
      Projekt  = "abschlussprojekt"
      Besitzer = var.vorname
    }
  }
}
