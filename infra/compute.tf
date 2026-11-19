# AMI Ubuntu Server 22.04 LTS ARM64 (t4g é Graviton/ARM, então precisa ser arm64)
data "aws_ssm_parameter" "ubuntu_arm" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/arm64/hvm/ebs-gp2/ami-id"
}

# Par de chaves: só a chave PÚBLICA é informada ao Terraform
resource "aws_key_pair" "main" {
  key_name   = var.key_name
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# S1: endurecimento do SSH em TODAS as instâncias (cloud-init, na criação)
#  - autenticação por senha desativada
#  - login direto como root desativado
locals {
  ssh_hardening = <<-EOT
    #cloud-config
    write_files:
      - path: /etc/ssh/sshd_config.d/01-hardening.conf
        permissions: "0644"
        content: |
          PasswordAuthentication no
          KbdInteractiveAuthentication no
          PermitRootLogin no
    runcmd:
      - systemctl restart ssh
  EOT
}

# --- Bastion: subnet pública, IP público estático (Elastic IP) ---
resource "aws_instance" "bastion" {
  ami                    = data.aws_ssm_parameter.ubuntu_arm.value
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.pub_a.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = aws_key_pair.main.key_name

  user_data                   = local.ssh_hardening
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true # S6
  }

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  tags = { Name = "bastion" }
}

resource "aws_eip" "bastion" {
  domain     = "vpc"
  instance   = aws_instance.bastion.id
  tags       = { Name = "eip-bastion" }
  depends_on = [aws_internet_gateway.main]
}

# --- Aplicação: subnet privada, SEM IP público ---
resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.ubuntu_arm.value
  instance_type               = var.app_instance_type
  subnet_id                   = aws_subnet.priv_a.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = false

  user_data                   = local.ssh_hardening
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true # S6
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "app-${var.project}" }

  # Precisa de saída para a internet (pacotes, imagens) via NAT
  depends_on = [aws_nat_gateway.main]
}
