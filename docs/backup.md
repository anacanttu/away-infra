# Plano de backup (Parte D)

> Alta disponibilidade não substitui backup: uma réplica copia também um `DELETE` errado. E o Terraform recria a infraestrutura, mas não recria os dados. Este plano trata só dos **dados**.

## B1. Inventário: o que precisa de backup

| Ativo | Precisa de backup? | Justificativa |
|---|---|---|
| **Banco PostgreSQL (RDS)** | **Sim** | Contém assistidos, comparecimentos, usuários do sistema e endereços. É o único ativo que não se reconstrói pelo código. |
| **Realm do Keycloak** (clients, roles, usuários) | **Parcial** | A configuração está versionada em `infra/ansible/files/away-realm.json` (sem senhas) e é reimportada pelo Ansible. As senhas ficam no `ansible-vault`. Os usuários criados depois pela interface vivem no volume do Keycloak (H2) e **não** têm backup. Risco aceito: ver "O que a política mínima não protege". |
| Arquivos enviados por usuários | Não se aplica | O backend não grava arquivos: não há upload implementado (a tela "Gerenciar Documentos" não tem endpoint correspondente). Se isso mudar, o storage precisa sair da instância (ver `alta-disponibilidade.md`, H5). |
| State do Terraform | Sim, mas fora do escopo da nuvem | O state é local (`terraform.tfstate`, no `.gitignore`). Como o ambiente é destruído após a apresentação, perdê-lo não perde dados; só impede o `destroy` pelo Terraform (a infra teria de ser apagada manualmente). Em produção: bucket S3 versionado com lock. |
| Código, configuração, Ansible, documentação | Não | Estão no Git (`anacanttu/away-infra`). O repositório **é** o backup. |
| Sistema operacional e containers das EC2 | Não | Reproduzíveis por Terraform + Ansible. Backup de disco só reproduziria o que o código já recria. |
| Segredos (senha do RDS) | Não | A senha do RDS é gerada pela AWS no Secrets Manager e recriada junto com o banco. Os segredos do Ansible ficam no cofre do próprio grupo. |

## B2. RPO e RTO

O AWAY é um sistema interno de um patronato, usado por 5 a 15 pessoas em horário comercial, de segunda a sexta (Entrega 1, seção 5.1). Os cadastros são digitados a partir de documentos que a instituição já possui em papel ou em processos judiciais, então um dado perdido pode ser redigitado.

| Métrica | Valor | Justificativa |
|---|---|---|
| **RPO** | **24 horas** | Perder, no pior caso, um dia de cadastros é tolerável: os dados podem ser redigitados a partir da origem. Um backup diário atende. |
| **RTO** | **4 horas** | Sistema de uso interno em horário comercial, sem atendimento ao público. Um dia de trabalho sem sistema é ruim, mas meio período é suportável. Com Terraform + Ansible, recriar a infra leva cerca de 30 minutos; o restante do tempo é para restaurar o banco e validar. |

## B3. Política conservadora (GFS): o que o grupo recomendaria em produção

O esquema Grandfather-Father-Son guarda cópias recentes em maior número e as antigas de forma espaçada.

| Geração | Frequência | Promoção | Retenção | Classe de armazenamento |
|---|---|---|---|---|
| **Son** (filho) | Diária, às 03:00 UTC (00:00 em Brasília) | Toda cópia diária é criada nova | **7 dias** | S3 Standard |
| **Father** (pai) | Semanal | A cópia diária de **domingo** é copiada para o prefixo `semanal/` | **4 semanas** | S3 Standard-IA |
| **Grandfather** (avô) | Mensal | A cópia semanal do **último domingo do mês** é copiada para o prefixo `mensal/` | **12 meses** | S3 Standard-IA |

**Mecanismo por ativo:** dump lógico (`pg_dump`, formato custom, comprimido) do RDS gravado em um bucket S3, com cada geração sob um prefixo (`diario/`, `semanal/`, `mensal/`) e **regra de ciclo de vida por prefixo** (expiração em 7, 35 e 365 dias). O dump é consistente do ponto de vista do banco, o que o snapshot de disco não garante.

Complemento: o **backup automático do RDS com retenção de 7 dias** permite restauração para um ponto no tempo (PITR, RPO de minutos nessa janela) e, até 100% do tamanho do banco, não gera custo adicional de armazenamento.

**Por que Standard-IA para pai e avô:** acessados raramente, com retenção de 35 dias ou mais (4 semanas mais uma folga), o que respeita a duração mínima de cobrança de 30 dias dessa classe. Para o Son, de 7 dias, a classe Standard evita pagar 30 dias por uma cópia que vive 7.

## B4. Armazenamento

- **Fora da instância:** em um bucket S3, nunca no disco da EC2 nem na mesma instância do banco.
- **Outra região (recomendado):** bucket em `us-east-1`, para sobreviver à perda da região `sa-east-1`. Além de mais resiliente, essa região é mais barata. O cálculo abaixo usa os preços de `sa-east-1`, portanto é um **teto**.
- **Criptografia (S6):** SSE-S3 (ou SSE-KMS) habilitada explicitamente no bucket; bloqueio de acesso público ativo; versionamento habilitado.
- **Acesso restrito (S5):** a instância que executa o dump usa um **instance profile** com permissão `s3:PutObject` somente nesse bucket e nos prefixos das gerações. Sem permissão de `DeleteObject`/`DeleteBucket`: assim, uma instância comprometida **não consegue apagar os backups**. A remoção por expiração é feita pela regra de ciclo de vida do próprio S3.

## B5. Responsabilidade compartilhada

| Ativo | A AWS garante | O grupo é responsável por |
|---|---|---|
| **RDS** | Execução dos backups automáticos agendados, durabilidade do armazenamento do snapshot, patch do mecanismo e do sistema do host do banco | Definir a retenção, testar a restauração, proteger as credenciais, decidir o que fazer após um erro de operação (um `DELETE` errado é replicado e copiado) |
| **S3 (bucket de backup)** | Durabilidade de 99,999999999% e disponibilidade do serviço; execução das regras de ciclo de vida (de forma assíncrona) | Criptografia, bloqueio de acesso público, políticas de acesso, escolha das regiões, retenção e custo |
| **EC2 (app, bastion)** | Hardware e hipervisor | Sistema operacional, atualizações, dados dentro do disco, snapshots, se os quiser |
| **Keycloak (volume H2)** | Nada: é um container rodando numa EC2 | Tudo: backup do volume ou migração para o RDS |

## B6. Política mínima configurada (o que está na nuvem)

Como o banco é um **serviço gerenciado**, o mecanismo é o **backup automático do próprio RDS**. Só a geração Son, com retenção curta, conforme a seção 6.3 do enunciado.

| Requisito | Como foi atendido | Onde |
|---|---|---|
| Configuração por código | `backup_retention_period = var.db_backup_retention_days`, `backup_window = "03:00-04:00"` | `infra/database.tf` |
| Retenção de no máximo 2 dias | Padrão de **1 dia**; uma `validation` na variável **impede valores acima de 2** | `infra/variables.tf` |
| Criptografia | `storage_encrypted = true`, declarada explicitamente; os backups e snapshots herdam a criptografia | `infra/database.tf` |
| Existência de cópia | O RDS gera um backup automático ao criar a instância com retenção maior que 0 | Conferir com o comando abaixo no dia da apresentação |
| Custo | Backups de até 100% do tamanho do banco dentro do período de retenção não geram custo adicional; ver B7 | Abaixo |
| Nada sobra após o destroy | `delete_automated_backups = true` e `skip_final_snapshot = true` | `infra/database.tf` |

**Comando de verificação da cópia** (executar no dia, e guardar a saída em `docs/evidencias/`):

```bash
aws rds describe-db-instances --region sa-east-1 --db-instance-identifier db-away \
  --query "DBInstances[0].{retencao:BackupRetentionPeriod,janela:PreferredBackupWindow,criptografado:StorageEncrypted,ultimoBackup:LatestRestorableTime}"
aws rds describe-db-snapshots --region sa-east-1 --db-instance-identifier db-away --snapshot-type automated \
  --query "DBSnapshots[].{id:DBSnapshotIdentifier,status:Status,criada:SnapshotCreateTime,criptografado:Encrypted}"
```

**Verificado em 22/11/2026** (ver [`evidencias/verificacao-aws-2026-11-22.txt`](evidencias/verificacao-aws-2026-11-22.txt)): retenção de 1 dia, criptografia ativa e **um snapshot automático existente** (`status: available`, `Encrypted: true`).

Observação do enunciado: a expiração é feita pelo provedor de forma **assíncrona**; o backup pode ficar um pouco além de 1 dia antes de ser removido.

### O que a política mínima **não** protege (em comparação com a GFS)

- Um erro descoberto **depois de 1 dia** não pode ser desfeito: não há cópia semanal nem mensal.
- Não há cópia **em outra região**: a perda de `sa-east-1` perde os backups. Eles também são **apagados junto com a instância** (`delete_automated_backups`).
- Os backups automáticos pertencem à instância: se **alguém apagar o banco**, os backups automáticos vão junto (um dump no S3 não teria esse problema).
- Os **usuários criados no Keycloak** depois da implantação não têm backup (o volume do container não é copiado).
- Não há teste de restauração (o enunciado não exige), então **a restauração não foi verificada**.

## B7. Custos

### Política mínima, no período do trabalho

Retenção de 1 dia sobre um banco de poucos MB: o armazenamento do backup fica **dentro dos 100% do tamanho do banco que a AWS não cobra**. O custo adicional estimado é **US$ 0,00**. O custo real a conferir no painel de faturamento após a apresentação entra em `docs/custos/`.

### Política conservadora (GFS), 12 meses

**Premissas** (a calculadora oficial deve ser usada para conferir os valores):

- Dados iniciais: **2 GB**, crescimento de **0,5 GB por mês** (cadastros de texto, sem arquivos).
- Cada dump comprimido ocupa cerca de **50% do tamanho dos dados**.
- Preços unitários de `sa-east-1`: **S3 Standard US$ 0,0405/GB-mês** ([fonte](https://upstash.com/blog/aws-s3-pricing-explained-2026)); **S3 Standard-IA US$ 0,0221/GB-mês** ([fonte: AWS Storage Blog, dez/2021](https://aws.amazon.com/blogs/storage/s3-storage-class-price-reductions), valor possivelmente desatualizado, **confirmar na calculadora**).
- Requisições: cerca de 35 PUTs por mês, a US$ 0,007 por 1.000: desprezível.
- Transferência de dados: **zero**, pois o dump é gravado a partir da EC2 na mesma região, e a restauração não está no cálculo.
- O RDS com 7 dias de retenção não entra: o armazenamento até 100% do banco não é cobrado.

Cópias retidas no mês *m*: Son = 7; Father = mín(4, 4m); Grandfather = mín(12, m).

| Mês | Dados (GB) | Cópias (Son+Father+Grandfather) | Armazenado (GB) | Custo do mês (USD) |
|---|---|---|---|---|
| 1 | 2,0 | 7+4+1 = 12 | 12,0 | 0,394 |
| 2 | 2,5 | 7+4+2 = 13 | 16,2 | 0,520 |
| 3 | 3,0 | 7+4+3 = 14 | 21,0 | 0,658 |
| 4 | 3,5 | 7+4+4 = 15 | 26,2 | 0,806 |
| 5 | 4,0 | 7+4+5 = 16 | 32,0 | 0,965 |
| 6 | 4,5 | 7+4+6 = 17 | 38,2 | 1,135 |
| 7 | 5,0 | 7+4+7 = 18 | 45,0 | 1,317 |
| 8 | 5,5 | 7+4+8 = 19 | 52,2 | 1,509 |
| 9 | 6,0 | 7+4+9 = 20 | 60,0 | 1,713 |
| 10 | 6,5 | 7+4+10 = 21 | 68,2 | 1,927 |
| 11 | 7,0 | 7+4+11 = 22 | 77,0 | 2,153 |
| 12 | 7,5 | 7+4+12 = 23 | 86,2 | 2,389 |
| **Total no ano** | | | | **US$ 15,49** |

A planilha completa está em [`custos/gfs-12-meses.csv`](custos/gfs-12-meses.csv). O custo **cresce a cada mês**, porque as gerações antigas acumulam até atingirem a retenção, e por isso o cálculo cobre os 12 meses e não só o primeiro.

### Qual parâmetro mais influencia o custo anual?

Variando um parâmetro por vez, em relação ao total de US$ 15,49:

| Variação | Total anual | Diferença |
|---|---|---|
| Son com 3 dias em vez de 7 | US$ 10,87 | **−US$ 4,62 (−30%)** |
| Tudo em S3 Standard (sem Standard-IA) | US$ 21,65 | +US$ 6,16 (+40%) |
| Grandfather de 6 meses em vez de 12 | US$ 13,94 | −US$ 1,55 |
| Father de 2 semanas em vez de 4 | US$ 14,23 | −US$ 1,26 |
| Dobro do crescimento dos dados | US$ 24,78 | +US$ 9,29 |

Dentro da **política** (frequência, retenção e classe), o que mais pesa é a **retenção da geração Son**: ela fica na classe mais cara (Standard) e é a mais numerosa. Reduzir de 7 para 3 dias economiza cerca de 30%, mas o grupo **perderia a capacidade de voltar a qualquer dia da última semana**: um erro descoberto no quinto dia só poderia ser desfeito com a cópia semanal, perdendo até uma semana de dados, o que ultrapassa o RPO de 24 horas. A **classe de armazenamento** é o segundo parâmetro, e usar Standard-IA para pai e avô poupa 28% sem perder nenhuma cópia.

O fator que mais pesa de fato é o **crescimento dos dados**, que não é parâmetro da política. Mesmo assim, o custo total da política conservadora é **inferior a US$ 2 por mês**, bem abaixo do custo do restante da infraestrutura (cerca de US$ 152 por mês): o backup não é o item que justifica economia.
