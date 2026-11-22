# AWAY - Infraestrutura em Nuvem

Projeto Integrador | Uniamérica Descomplica | Disciplina: Projeto Integrador | Professor: Gildomiro Bairros

## Grupo

| Integrante | GitHub |
|---|---|
| Ana Luisa Cantu | [@anacanttu](https://github.com/anacanttu) |

## Visão geral

Este repositório contém o projeto e a **implantação na AWS** do **AWAY**, sistema de gestão de patronato penitenciário do grupo:

- Frontend: [Frontend-AWAY](https://github.com/anacanttu/Frontend-AWAY) (Angular)
- Backend: [Backend-AWAY](https://github.com/anacanttu/Backend-AWAY) (Spring Boot + PostgreSQL, autenticação com Keycloak)

- **Entrega 1** (tag `entrega-1`): projeto de arquitetura, ADRs e estimativa de custo.
- **Entrega 2** (tag `entrega-2`): infraestrutura criada por **Terraform** (`infra/`), aplicação instalada por **Ansible** (`infra/ansible/`), segurança, proposta de alta disponibilidade e plano de backup.

> ⚠️ **Custos.** Este ambiente gera custo, pago pelo grupo. O NAT Gateway e o ALB cobram **por hora, mesmo sem tráfego** (cerca de US$ 0,25 por hora no total). Ligue só para testes e para a apresentação, confira o alerta de orçamento **antes do primeiro `apply`** e rode `terraform destroy` no fim. Estimativa: `docs/custos/estimativa.pdf`.

## Estrutura do repositório

```
/
├── README.md
├── IA.md                                  # Declaração de uso de IA
├── docs/
│   ├── arquitetura.md                     # Projeto da Entrega 1
│   ├── seguranca.md                       # Controles S1-S8, achados, ameaças
│   ├── alta-disponibilidade.md            # Proposta de HA (H1-H7)
│   ├── backup.md                          # Plano GFS e política mínima (B1-B7)
│   ├── errata.md                          # Divergências Entrega 1 x implantado
│   ├── adr/                               # 001-005
│   ├── diagramas/                         # arquitetura (E1) e arquitetura-ha
│   ├── custos/                            # estimativa E1, custo da HA, custo GFS 12 meses
│   └── evidencias/                        # relatórios Trivy, Checkov, Gitleaks, etc.
└── infra/
    ├── versions.tf  providers.tf  variables.tf  locals.tf
    ├── network.tf  security.tf  compute.tf  database.tf  alb.tf  budget.tf  outputs.tf
    ├── terraform.tfvars.example
    ├── .terraform.lock.hcl
    └── ansible/                           # instalação da aplicação (Docker, Nginx, backend, Keycloak)
```

## Arquitetura implantada

```
Internet ─► ALB (HTTPS 443, certificado ACM) ─► EC2 app-away (privada): Nginx → Spring Boot → RDS PostgreSQL
                                                                         └► Keycloak (só rede interna)
Administrador ─SSH─► Bastion (IP elástico) ─SSH─► app-away      app-away ─► NAT Gateway ─► Internet
```

VPC `10.20.0.0/16`, sub-redes `pub-a`, `pub-b`, `priv-a`, `priv-b` (diagrama em `docs/diagramas/arquitetura.png`).

## Pré-requisitos

Na máquina de quem vai operar:

| Ferramenta | Para quê |
|---|---|
| Terraform ≥ 1.9 | Criar a infraestrutura |
| AWS CLI com credenciais (`aws configure`) | Autenticar o Terraform e ler o Secrets Manager |
| Ansible (`brew install ansible`) | Instalar a aplicação |
| Docker | Compilar o backend sem depender de um Java local |
| Node.js 20+ e npm | Compilar o Angular |
| Um par de chaves SSH (`ssh-keygen -t ed25519`) | Só a chave **pública** vai para a AWS |
| Um domínio próprio e acesso ao seu painel de DNS | Certificado HTTPS (usamos `aidados.co`) |

**Nunca** commite `terraform.tfvars`, chaves privadas, `.vault_pass`, `vault.yml` ou o `terraform.tfstate` (o `.gitignore` os bloqueia).

## Configuração das variáveis

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
curl ifconfig.me          # descubra seu IP público
```

Edite `terraform.tfvars`:

| Variável | O que informar |
|---|---|
| `admin_cidr` | Seu IP público com `/32` (único CIDR com SSH ao bastion; `0.0.0.0/0` é recusado) |
| `ssh_public_key_path` | Caminho da **chave pública** (`~/.ssh/id_ed25519.pub`) |
| `budget_email` | E-mail do alerta de orçamento |

Os demais valores (região, CIDRs, tipos de instância, domínio) têm padrões documentados em `infra/variables.tf`.

## Criar a infraestrutura (`apply`)

O `apply` é feito em **etapas**, porque o alerta de orçamento precisa existir **antes** de qualquer recurso que cobre, e o certificado HTTPS precisa do DNS.

```bash
cd infra
terraform init

# 1) Alerta de orçamento ANTES do primeiro apply (gratuito)
terraform apply -target=aws_budgets_budget.monthly

# 2) Só o certificado (gratuito) e o registro DNS de validação
terraform apply -target=aws_acm_certificate.main
terraform output acm_validation_records
```

3. **No painel de DNS do domínio**, crie o **CNAME de validação** mostrado (no campo nome, tire o final `.aidados.co`). Espere o certificado ficar `ISSUED`:

```bash
aws acm list-certificates --region sa-east-1 --query "CertificateSummaryList[].[DomainName,Status]" --output text
```

```bash
# 4) Toda a infraestrutura (10 a 15 minutos; o custo começa aqui)
terraform apply

# 5) Mostra o CNAME do site para criar no DNS
terraform output dns_cname_para_criar
```

6. **No painel de DNS**, crie o CNAME `away` apontando para o endereço do ALB mostrado.

Depois do `apply`, `terraform plan` deve responder **No changes**.

## Instalar a aplicação (Ansible), na ordem

Tudo parte da pasta `infra/ansible/`.

**1. Segredos (uma vez).** Crie o cofre e a senha dele:

```bash
cd infra/ansible
openssl rand -base64 24 | tr -d '/+=' > .vault_pass && chmod 600 .vault_pass
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
# edite vault.yml: senha do admin do Keycloak, client secret (openssl rand -hex 16) e as senhas dos usuários
ansible-vault encrypt group_vars/all/vault.yml
```

**2. Compilar o sistema** (clona os repositórios, compila o backend dentro do Docker e o Angular apontando para o domínio):

```bash
./build.sh
```

**3. Gerar o inventário** a partir dos outputs do Terraform (o app não tem IP público: o SSH passa pelo bastion):

```bash
./gerar-inventario.sh ~/.ssh/id_ed25519
```

**4. Instalar.** O playbook instala o Docker, copia o WAR e o Angular, sobe Nginx, Spring Boot e Keycloak em containers, importa o realm `away`, define as senhas dos usuários e confere o endurecimento do SSH:

```bash
ansible-playbook site.yml
```

**5. Verificar.** Abra `https://away.aidados.co` e entre com um dos usuários do cofre (`ansible-vault view group_vars/all/vault.yml`). No console da AWS, o *target group* do ALB deve mostrar a instância **healthy**.

### Acessar as máquinas

```bash
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
ssh ubuntu@<bastion_public_ip>
ssh -J ubuntu@<bastion_public_ip> ubuntu@<app_private_ip>
```

Os IPs vêm de `terraform output`.

## Destruir (`destroy`)

```bash
cd infra
terraform destroy
```

Depois confira **no console**, apenas para consultar, que não restaram NAT Gateway, IPs elásticos, volumes, snapshots nem buckets. Guarde a evidência em `docs/evidencias/`.

## Verificações de segurança

```bash
trivy config infra/
checkov -d infra/
gitleaks detect --source .
```

Resultados e decisões: [`docs/seguranca.md`](docs/seguranca.md).

## Divisão das demonstrações

O grupo da Entrega 2 tem **uma integrante**, que conduz todas as demonstrações (roteiro do enunciado, seção 10.1). Ver a errata, item 10:

| Etapa | Demonstração | Responsável |
|---|---|---|
| D1 | Estado consistente: `terraform plan` sem alterações e `terraform output` | Ana Luisa Cantu |
| D2 | Aplicação por HTTPS (S3) e funcionalidade verificável | Ana Luisa Cantu |
| D3 | Acesso administrativo: SSH ao bastion, à instância privada pelo bastion e recusa de senha (S1) | Ana Luisa Cantu |
| D4 | NAT e isolamento: IP de saída da instância privada igual ao IP do NAT | Ana Luisa Cantu |
| D5 | Segurança: segredos fora do código (S4) e relatório de análise (S7) | Ana Luisa Cantu |
| D6 | Backup: política mínima configurada e custo anual da política GFS | Ana Luisa Cantu |
| D7 | Alta disponibilidade: diagrama proposto e análise de custo | Ana Luisa Cantu |

## Documentação

| Documento | Conteúdo |
|---|---|
| [`docs/arquitetura.md`](docs/arquitetura.md) | Projeto da Entrega 1 |
| [`docs/seguranca.md`](docs/seguranca.md) | S1 a S8, achados e ameaças |
| [`docs/alta-disponibilidade.md`](docs/alta-disponibilidade.md) | H1 a H7 |
| [`docs/backup.md`](docs/backup.md) | B1 a B7 |
| [`docs/errata.md`](docs/errata.md) | Divergências e incidente de segurança |
| [`docs/adr/`](docs/adr/) | ADRs 001 a 005 |
| [`docs/custos/`](docs/custos/) | Estimativas e custo real |
| [`IA.md`](IA.md) | Declaração de uso de IA |
