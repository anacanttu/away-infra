# Segurança (Parte B)

Este documento cobre os controles S1 a S8, o tratamento dos achados das ferramentas de análise e a análise de ameaças.

## 1. Controles S1 a S8

| # | Controle | Como foi aplicado | Onde | Como demonstrar |
|---|---|---|---|---|
| **S1** | Endurecimento do SSH | Autenticação por senha **desativada** e login direto como `root` **desativado** em **todas** as instâncias (bastion e aplicação), por *cloud-init* na criação. O Ansible confere o resultado com `sshd -T` e falha se não for `no`. | `infra/compute.tf` (`local.ssh_hardening`), `infra/ansible/site.yml` | `ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password ubuntu@<IP_BASTION>` deve responder `Permission denied (publickey)` |
| **S2** | Saída restrita | Nenhum grupo de segurança libera todo o tráfego de saída. Aplicação e bastion saem só em **80/443** (pacotes e imagens, via NAT) e **53** (DNS, só para a VPC). A aplicação fala com o banco só na **5432**, para o grupo `sg-db`. O bastion só acessa a aplicação na **22**. O ALB só envia para a aplicação na porta dela. O banco **não tem regra de saída**. | `infra/security.tf` | `aws ec2 describe-security-groups` mostra a lista de regras de saída; o `terraform plan` não tem nenhuma regra `-1` (todos os protocolos) |
| **S3** | HTTPS | O ALB atende em **443** com certificado **válido do ACM** para o domínio próprio `away.aidados.co` (validação por DNS), política TLS 1.2/1.3. A porta 80 **redireciona** (301) para HTTPS. | `infra/alb.tf` | `curl -vI https://away.aidados.co` (certificado válido) e `curl -I http://away.aidados.co` (redireciona) |
| **S4** | Gestão de segredos | A senha do banco é **gerada pela AWS** e guardada no **Secrets Manager** (`manage_master_user_password = true`); o Ansible a lê na hora do deploy, na máquina de quem opera. Os demais segredos (senha do admin do Keycloak, *client secret*, senhas dos usuários) ficam no **ansible-vault** (criptografado) e o arquivo está no `.gitignore`. Nada de senha no Terraform, nas variáveis ou no repositório. | `infra/database.tf`, `infra/ansible/group_vars/all/vault.yml.example`, `.gitignore` | `git grep -iE "password\|secret"` não encontra valores; relatório do Gitleaks (S7) |
| **S5** | Menor privilégio nas instâncias | As instâncias **não têm perfil de instância nem chaves de acesso gravadas nelas**: nenhuma delas acessa serviços da AWS, então não precisam de permissões. O Ansible lê o Secrets Manager com as credenciais da pessoa que opera, não da instância. IMDSv2 é obrigatório (`http_tokens = "required"`). Se uma rotina de backup para S3 for adotada, ela usaria um *instance profile* restrito ao bucket (ver `backup.md`, B4). | `infra/compute.tf` | `aws ec2 describe-instances --query "...IamInstanceProfile"` retorna vazio |
| **S6** | Criptografia em repouso | Discos EBS das duas instâncias com `encrypted = true` e o RDS com `storage_encrypted = true`, ambos **declarados explicitamente**. Os backups e snapshots do RDS herdam a criptografia. | `infra/compute.tf`, `infra/database.tf` | `aws ec2 describe-volumes --query "Volumes[].Encrypted"` e `aws rds describe-db-instances --query "DBInstances[].StorageEncrypted"` |
| **S7** | Análise automatizada | **Trivy** e **Checkov** sobre `infra/`, **Gitleaks** sobre todo o histórico do repositório. Relatórios em `docs/evidencias/`. Achados tratados na seção 2. | `docs/evidencias/` | `trivy config infra/`, `checkov -d infra/`, `gitleaks detect --source .` |
| **S8** | Proteção da conta | MFA habilitado na conta AWS usada pelo grupo. | Console da AWS | **Evidência pendente do grupo:** captura de tela em `docs/evidencias/mfa.png`, sem dados sensíveis |

Controles adicionais, além dos exigidos: **IMDSv2 obrigatório** nas duas instâncias; o ALB **descarta cabeçalhos HTTP inválidos**; as sub-redes públicas **não atribuem IP público automaticamente** (só o IP elástico explícito do bastion); o **SSH ao bastion só aceita o CIDR do administrador**, validado por variável que recusa `0.0.0.0/0`; o banco não tem IP público nem rota para a internet.

## 2. Tratamento dos achados

Foram executados Trivy (`trivy config infra/`), Checkov (`checkov -d infra/`) e Gitleaks. Os relatórios completos estão em `docs/evidencias/`. Os arquivos `*-antes` são da primeira execução e `*-depois` do estado final, com as correções.

### 2.1 Resumo

| Ferramenta | Antes | Depois |
|---|---|---|
| Trivy | 4 críticos, 4 altos, 4 médios, 1 baixo | 4 críticos, 1 alto, 4 médios, 1 baixo |
| Checkov | 100 aprovadas, 16 reprovadas | 102 aprovadas, 14 reprovadas |
| Gitleaks, `away-infra` | Nenhum segredo no histórico | Nenhum segredo no histórico (23 commits) |
| Gitleaks, `Backend-AWAY` | 10 achados no histórico (ver 2.3 e a errata) | Os arquivos foram removidos da branch principal, mas o **histórico mantém os segredos** |

### 2.2 Achados de severidade alta ou crítica

| Achado | Severidade | Recurso | Decisão | Justificativa |
|---|---|---|---|---|
| AWS-0104: regra de saída para `0.0.0.0/0` | Crítica (×4) | `app_http`, `app_https`, `bastion_http`, `bastion_https` | **Aceito** | O enunciado cita HTTP/HTTPS para atualização de pacotes como saída legítima. A aplicação precisa baixar pacotes e imagens Docker pelo NAT, e os destinos (repositórios Ubuntu, Docker Hub, GitHub, quay.io) mudam de IP e não cabem em uma lista fixa. Foram removidas todas as outras portas de saída. **Risco residual:** uma instância comprometida poderia exfiltrar dados pela porta 443. Em produção: proxy de saída com lista de domínios, ou VPC endpoints. |
| Saída irrestrita (todos os protocolos) nos 4 grupos de segurança | Alta | `sg-app`, `sg-bastion`, `sg-alb`, `sg-db` | **Corrigido** (controle S2) | A primeira versão do código liberava toda a saída. Foi corrigida **antes** das varreduras, então esse achado não aparece nos relatórios de `evidencias/`; o resultado está na linha anterior (somente 80/443/53 e a porta do banco). |
| AWS-0052: ALB não descarta cabeçalhos inválidos | Alta | `aws_lb.main` | **Corrigido** | `drop_invalid_header_fields = true` em `infra/alb.tf`. |
| AWS-0164: sub-rede pública atribui IP público por padrão | Alta (×2) | `pub_a`, `pub_b` | **Corrigido** | `map_public_ip_on_launch = false` em `infra/network.tf`. O bastion recebe um IP elástico explícito. |
| AWS-0053: balanceador exposto à internet | Alta | `aws_lb.main` | **Aceito** | É a porta de entrada pública da aplicação, por definição (fluxo 1 da arquitetura). A exposição é limitada às portas 80 (redireciona) e 443. Os demais componentes ficam em sub-redes privadas. |

### 2.3 Outros achados registrados (média, baixa e Checkov)

| Achado | Recurso | Decisão | Justificativa |
|---|---|---|---|
| AWS-0177 / CKV_AWS_293: proteção contra exclusão do RDS desativada | `aws_db_instance.main` | Aceito | Ambiente acadêmico que precisa ser destruído com `terraform destroy` e não deixar nada cobrando. Em produção seria `true`. |
| CKV_AWS_150: proteção contra exclusão do ALB | `aws_lb.main` | Aceito | Mesmo motivo. |
| AWS-0077: retenção do backup do RDS deveria ser maior que 1 dia | `aws_db_instance.main` | Aceito | A política mínima do enunciado limita a **no máximo 2 dias**; o valor 1 é o padrão do projeto. A política conservadora (7 dias) está em `backup.md`. |
| AWS-0176 / CKV_AWS_161: autenticação IAM no RDS desativada | `aws_db_instance.main` | Aceito | A aplicação usa senha gerenciada pelo Secrets Manager. A autenticação IAM exigiria mudanças no backend. |
| AWS-0178: VPC Flow Logs desativado | `aws_vpc.main` | Aceito | Gera custo contínuo e grupos de log que sobrevivem ao `destroy`. Recomendado em produção. |
| CKV_AWS_91: logs de acesso do ALB | `aws_lb.main` | Aceito | Exigiria um bucket S3 que sobreviveria ao `destroy`. |
| CKV_AWS_126 / CKV_AWS_118 / CKV_AWS_353 / CKV_AWS_129 / AWS-0133: monitoramento detalhado, Performance Insights e exportação de logs | EC2 e RDS | Aceito | Custo adicional sem necessidade para o perfil de uso. |
| CKV_AWS_157: RDS sem Multi-AZ | `aws_db_instance.main` | Aceito | A arquitetura implantada é Single-AZ por decisão da Entrega 1 (ADR-003). A alta disponibilidade é apenas projetada (`alta-disponibilidade.md`). |
| CKV_AWS_135: EC2 sem EBS otimizado | `aws_instance.*` | **Corrigido** | `ebs_optimized = true`. |
| CKV_AWS_260 / CKV_AWS_24 em `app_from_alb` e `app_ssh_from_bastion` | `sg-app` | **Falso positivo** | As regras referenciam **outro grupo de segurança** (`referenced_security_group_id`), não `0.0.0.0/0`. A ferramenta não interpretou o atributo dos novos recursos de regra. |
| CKV_AWS_260: porta 80 aberta para `0.0.0.0/0` | `alb_http` | Aceito | Só redireciona para HTTPS (S3). |
| CKV_AWS_394: zonas de disponibilidade sem fixar | `data.aws_availability_zones` | Aceito | As duas primeiras zonas disponíveis são suficientes e evitam fixar nomes no código. |

### 2.4 Gitleaks e o incidente do repositório do backend

O Gitleaks **não encontrou segredos no repositório `away-infra`**. Já no repositório do backend (`anacanttu/Backend-AWAY`), que é público, ele encontrou **10 achados no histórico**: arquivos `.env`, `env.template`, `INSTRUCOES-VM.md`, `corrigir-cors-vm.sh`, `.ebextensions/environment.config` e chaves privadas em `certs/`. Os arquivos foram removidos da branch principal pelo pull request nº 1, mas **continuam no histórico**. O incidente e a revogação estão na [errata](errata.md). O relatório (valores ocultos) está em `evidencias/gitleaks-backend-away.json`.

## 3. Análise de ameaças

| # | Ameaça | Ativo afetado | Controle aplicado | Risco residual |
|---|---|---|---|---|
| 1 | Força bruta ou uso de credencial roubada no SSH do bastion, único ponto de entrada administrativo exposto | Bastion | S1 (sem senha, sem root), SSH só do CIDR `/32` do administrador (R7), chave pública informada ao Terraform | O comprometimento da **chave privada** de um integrante dá acesso ao bastion e, por ele, à aplicação |
| 2 | **Segredo versionado no Git e exposto em repositório público**, como aconteceu no `Backend-AWAY` (senha do banco, `JWT_SECRET`, chaves privadas) | Banco, VM, certificados | S4 (segredos fora do código), `.gitignore`, Gitleaks, remoção dos arquivos | O **histórico antigo** do `Backend-AWAY` ainda contém os valores: dependem de revogação, e uma senha reutilizada em outro serviço continuaria exposta |
| 3 | Aplicação comprometida (por exemplo, falha de injeção) tentando ler ou apagar o banco | RDS | Banco em sub-rede privada, sem IP público; `sg-db` só aceita a `sg-app`; disco criptografado; backup automático | A aplicação **tem** credencial legítima, então uma falha na própria aplicação ainda leria os dados. Os dados vêm criptografados em repouso, mas não do ponto de vista da aplicação |
| 4 | Interceptação de credenciais de login na rede | Tráfego usuário ↔ ALB | S3: HTTPS com certificado válido, redirecionamento da porta 80, política TLS 1.2/1.3 | O trecho **ALB → EC2** é HTTP dentro da VPC (aceito: tráfego interno e sub-rede privada). O Keycloak roda em modo de desenvolvimento, sem TLS interno |
| 5 | Exfiltração de dados ou acesso remoto ao atacante a partir de uma EC2 comprometida | EC2 da aplicação | S2: saída limitada a 80/443/53 e à porta do banco; sem IP público | A **porta 443 aberta para a internet** (achado crítico aceito) permite exfiltração por HTTPS |
| 6 | Acesso indevido ao console de administração do **Keycloak**, que cria usuários e define perfis | Keycloak | O container **não é publicado**: só responde dentro da rede do Docker; acesso por túnel SSH através do bastion; senha de administrador no `ansible-vault` | Keycloak em modo `start-dev` com banco H2 em volume local: não é a configuração recomendada para produção |
| 7 | **SSRF** que roubaria credenciais pelo serviço de metadados da instância | EC2 | IMDSv2 obrigatório e **nenhum perfil de instância** associado: não há credenciais da AWS para roubar | Segredos que estiverem no ambiente do container (como a senha do banco no `backend.env`) continuariam acessíveis a um invasor que executasse código na instância |
| 8 | Perda ou roubo da credencial AWS (chave de acesso do usuário IAM `terraform-away`) usada pelo Terraform | Conta AWS | S8: MFA na conta; credenciais fora do código, só no perfil local da CLI; recomenda-se **apagar a chave de acesso após o trabalho** | O usuário tem a política `AdministratorAccess` (simplificação do trabalho acadêmico): se a chave vazar, vale tudo na conta |
