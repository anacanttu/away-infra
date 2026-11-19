resource "aws_db_subnet_group" "main" {
  name       = "dbsubnet-${var.project}"
  subnet_ids = [aws_subnet.priv_a.id, aws_subnet.priv_b.id]
}

resource "aws_db_instance" "main" {
  identifier     = "db-${var.project}"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true # S6: declarado explicitamente (inclui backups e snapshots)

  db_name  = var.db_name
  username = var.db_username
  # S4: a AWS gera a senha e a guarda no Secrets Manager (fora do código e do state versionado)
  manage_master_user_password = true

  multi_az               = false # Single-AZ (Entrega 1); HA apenas projetada
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  # Política mínima de backup (Parte D): geração diária, retenção curta, por código
  backup_retention_period  = var.db_backup_retention_days
  backup_window            = "03:00-04:00" # UTC
  copy_tags_to_snapshot    = true
  delete_automated_backups = true # destroy não deixa backups para trás

  auto_minor_version_upgrade = true
  skip_final_snapshot        = true  # ambiente acadêmico: não deixar snapshot cobrando
  deletion_protection        = false # permite o terraform destroy
}
