output "app_url" {
  description = "URL da aplicação (HTTPS)"
  value       = "https://${local.fqdn}"
}

output "bastion_public_ip" {
  description = "IP público estático (Elastic IP) do bastion"
  value       = aws_eip.bastion.public_ip
}

output "nat_public_ip" {
  description = "IP público do NAT Gateway (IP de origem das saídas da subnet privada)"
  value       = aws_eip.nat.public_ip
}

output "bastion_private_ip" {
  description = "IP privado do bastion"
  value       = aws_instance.bastion.private_ip
}

output "app_private_ip" {
  description = "IP privado da instância da aplicação"
  value       = aws_instance.app.private_ip
}

output "alb_dns_name" {
  description = "Endereço do ALB"
  value       = aws_lb.main.dns_name
}

output "db_endpoint" {
  description = "Endpoint do RDS"
  value       = aws_db_instance.main.endpoint
}

output "db_secret_arn" {
  description = "Secret com a senha do banco (Secrets Manager)"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "acm_validation_records" {
  description = "Crie este CNAME no DNS do domínio para validar o certificado"
  value = [
    for o in aws_acm_certificate.main.domain_validation_options : {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  ]
}

output "dns_cname_para_criar" {
  description = "Crie um CNAME deste subdomínio apontando para o ALB"
  value       = "${local.fqdn} -> ${aws_lb.main.dns_name}"
}
