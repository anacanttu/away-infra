#!/usr/bin/env bash
# Gera o inventory.ini a partir dos outputs do Terraform (rode depois do terraform apply).
# Uso: ./gerar-inventario.sh [caminho-da-chave-ssh]
set -euo pipefail
cd "$(dirname "$0")"
KEY="${1:-$HOME/.ssh/id_ed25519}"
TF="terraform -chdir=.."

BASTION_IP=$($TF output -raw bastion_public_ip)
APP_IP=$($TF output -raw app_private_ip)
DB_HOST=$($TF output -raw db_endpoint | cut -d: -f1)
DB_SECRET=$($TF output -raw db_secret_arn)

cat > inventory.ini <<INV
[app]
app-away ansible_host=${APP_IP}

[app:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=${KEY}
# O app não tem IP público: o SSH passa pelo bastion
ansible_ssh_common_args='-o ProxyCommand="ssh -i ${KEY} -o StrictHostKeyChecking=accept-new -W %h:%p ubuntu@${BASTION_IP}" -o StrictHostKeyChecking=accept-new'
db_host=${DB_HOST}
db_secret_arn=${DB_SECRET}
INV
echo "inventory.ini gerado (bastion ${BASTION_IP}, app ${APP_IP})"
