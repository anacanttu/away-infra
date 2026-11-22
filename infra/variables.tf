variable "region" {
  description = "Região AWS (São Paulo)"
  type        = string
  default     = "sa-east-1"
}

variable "project" {
  description = "Nome do projeto, usado como prefixo e na tag Project"
  type        = string
  default     = "away"
}

variable "environment" {
  description = "Tag Environment"
  type        = string
  default     = "entrega2"
}

variable "owner" {
  description = "Tag Owner: nome do grupo"
  type        = string
  default     = "grupo-away"
}

variable "vpc_cidr" {
  description = "CIDR da VPC (definido na Entrega 1)"
  type        = string
  default     = "10.20.0.0/16"
}

variable "admin_cidr" {
  description = "IP público do administrador em CIDR /32 (ex: 200.10.20.30/32). Único CIDR com SSH ao bastion"
  type        = string

  validation {
    condition     = var.admin_cidr != "0.0.0.0/0" && can(cidrhost(var.admin_cidr, 0))
    error_message = "Informe um CIDR válido e específico. SSH aberto para 0.0.0.0/0 não é aceito."
  }
}

variable "ssh_public_key_path" {
  description = "Caminho da CHAVE PÚBLICA SSH (.pub). A chave privada nunca entra no Terraform nem no repositório"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "key_name" {
  description = "Nome do key pair criado na AWS a partir da chave pública"
  type        = string
  default     = "away-key"
}

variable "app_instance_type" {
  description = "Tipo da EC2 da aplicação (Nginx + Spring Boot + Keycloak). Definido na Entrega 1: t4g.small"
  type        = string
  default     = "t4g.small"
}

variable "bastion_instance_type" {
  description = "Tipo da EC2 do bastion. A Entrega 1 previa t4g.nano, mas contas no plano gratuito da AWS só aceitam tipos elegíveis (t4g.micro/t4g.small); ver docs/errata.md, item 11"
  type        = string
  default     = "t4g.micro"
}

variable "db_instance_class" {
  description = "Classe da instância RDS. Definido na Entrega 1: db.t4g.micro"
  type        = string
  default     = "db.t4g.micro"
}

variable "app_port" {
  description = "Porta em que o Nginx escuta na EC2 (serve o Angular e repassa ao backend)"
  type        = number
  default     = 80
}

variable "app_health_check_path" {
  description = "Caminho usado no health check do ALB"
  type        = string
  default     = "/"
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "away"
}

variable "db_username" {
  description = "Usuário administrador do banco (a senha é gerada pela AWS e guardada no Secrets Manager)"
  type        = string
  default     = "away_admin"
}

variable "db_backup_retention_days" {
  description = "Retenção do backup automático do RDS (política mínima: no máximo 2 dias)"
  type        = number
  default     = 1

  validation {
    condition     = var.db_backup_retention_days >= 1 && var.db_backup_retention_days <= 2
    error_message = "A política mínima de backup permite de 1 a 2 dias de retenção."
  }
}

variable "domain_name" {
  description = "Domínio que o grupo já possui"
  type        = string
  default     = "aidados.co"
}

variable "app_subdomain" {
  description = "Subdomínio da aplicação (resulta em away.aidados.co)"
  type        = string
  default     = "away"
}

variable "budget_email" {
  description = "E-mail para alertas de custo (vazio = não cria o budget)"
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Limite mensal em USD para o alerta de custo"
  type        = number
  default     = 30
}
