# Provider AWS. Credenciais NÃO ficam no código: use `aws configure` ou variáveis de ambiente.
provider "aws" {
  region = var.region

  # Tags aplicadas automaticamente em todos os recursos que aceitam tags
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
    }
  }
}
