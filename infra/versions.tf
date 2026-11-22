# Versões fixadas (reprodutibilidade). O .terraform.lock.hcl também é versionado.
terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.100.0"
    }
  }

  # O state fica local (terraform.tfstate, ignorado pelo git).
}
