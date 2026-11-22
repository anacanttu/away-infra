# Errata: divergências entre o projeto (Entrega 1) e o que foi implantado

Cada linha registra uma diferença entre o documento da Entrega 1 e a implantação da Entrega 2, o motivo e, quando uma **decisão** mudou, o ADR afetado. Nenhum dos ADRs 001 a 003 teve a decisão alterada (bastion, NAT gerenciado, RDS), então nenhum recebeu o status "substituída". Os ADRs 004 e 005 são novos.

| # | Item | Entrega 1 | Implantado | Motivo | ADR afetado |
|---|---|---|---|---|---|
| 1 | Instalação da aplicação | *cloud-init* (seção 5.6) | **Ansible**, executado da máquina do operador **através do bastion** (`infra/ansible/`) | O enunciado permite instalação manual documentada; a automação reduz o custo de destruir e recriar entre testes. O Ansible foi pedido pelo professor da disciplina. | Nenhum (era escolha de ferramenta, não decisão arquitetural) |
| 2 | Alerta de orçamento | US$ 20 por mês, avisos a 50%, 80% e 100% | **US$ 30 por mês**, avisos a 50%, 80% e 100% (gasto real) **e** previsão acima de 100%. O budget mede o uso **sem descontar créditos** (`include_credit = false`) | A conta tem US$ 100 em créditos promocionais do plano gratuito, que fariam o gasto aparente ficar perto de zero. Margem maior para dois ciclos de teste mais a apresentação. | Nenhum |
| 3 | Créditos de nuvem | "A instituição não oferece créditos" | A conta do grupo tem **US$ 100 em créditos do plano gratuito da AWS**, com validade até 21/03/2027 | O custo real a registrar em `custos/` é o **uso bruto** (antes dos créditos), para ser comparável ao cenário B. | Nenhum |
| 4 | Key pair | Não detalhado | Criado pelo Terraform (`aws_key_pair`) a partir da chave pública informada. **Houve um erro de processo:** em 18/11, durante o preparo, um key pair `away-key` foi **importado manualmente** pela CLI. Foi **apagado** e recriado pelo Terraform **antes do primeiro `apply`** (enunciado, seção 1 e R7) | Correção do erro: nenhum recurso de infraestrutura pode ser criado fora do código. | Nenhum |
| 5 | Tipo de pacote do backend | JAR (implícito) | **WAR executável** do Spring Boot, executado com `java -jar` | O `pom.xml` do projeto declara `<packaging>war</packaging>`. É o mesmo artefato que o grupo já usa. | Nenhum |
| 6 | Banco do Keycloak | Não detalhado ("containerizado, na mesma instância") | Keycloak em modo `start-dev` com o banco **H2 em volume local** da instância | Simplicidade e memória para caber na `t4g.small`. **É um risco aceito** (ver `seguranca.md`, ameaça 6, e `backup.md`, B1). | Nenhum. A proposta de HA (ADR-004) move o Keycloak para o RDS |
| 7 | Senhas de login do sistema | As mesmas do ambiente local | **Definidas pelo Ansible a partir do cofre**; o arquivo do realm no repositório **não tem hashes de senha** | Para não versionar credenciais. Quem opera lê as senhas com `ansible-vault view`. | Nenhum |
| 8 | Retenção do backup do RDS | Não definida (RDS com backup automático, ADR-003) | **1 dia**, com validação que impede mais de 2 | Política mínima do enunciado (seção 6.3). | ADR-003 continua válido; ADR-005 detalha |
| 9 | Escopo dos recursos extras | ALB, NAT, RDS, 2 EC2 | Além disso: **ACM** (certificado), **Elastic IP** do bastion, **budget** | Exigências de S3 (HTTPS), R6 (IP estático) e do alerta de orçamento. | Nenhum |
| 10 | Composição do grupo | A Entrega 1 foi feita por **dois integrantes** (Ana Luisa Cantu e Pablo) | A Entrega 2 é entregue e apresentada por **uma integrante** (Ana Luisa Cantu), pois o outro integrante deixou o grupo. **O registro da comunicação ao professor está pendente de confirmação pela integrante** (a data e o meio não foram informados até a entrega) | Mudança na composição do grupo. A divisão das demonstrações no README foi ajustada: uma só pessoa conduz D1 a D7 e responde pela defesa técnica. | Nenhum |
| 11 | Tipo da instância do bastion | `t4g.nano` (seção 5.7) | **`t4g.micro`** (custo de cerca de US$ 0,017 por hora, em vez de US$ 0,008) | A conta do grupo está no plano gratuito da AWS, que **recusa** `t4g.nano` na criação (`The specified instance type is not eligible for Free Tier`). O `t4g.micro` é o menor tipo ARM aceito. Diferença de cerca de US$ 6 por mês, irrelevante para o período do trabalho. O tipo é variável (`bastion_instance_type`), então basta voltar a `t4g.nano` numa conta paga. | Nenhum |
| 12 | Descrição de regra de segurança | Texto com acento | Descrições sem acentos | A AWS aceita só um conjunto de caracteres ASCII nas descrições de regras (o primeiro `apply` falhou em `alb_http` por causa de um `ó`). Corrigido no código. | Nenhum |

## Incidente de segurança: segredos no repositório do backend

**O que aconteceu.** O repositório público do backend (`anacanttu/Backend-AWAY`) continha, desde antes desta entrega, arquivos com credenciais e chaves: senha de um banco RDS antigo (região Ohio) e de uma VM antiga (`98.83.35.183`), `JWT_SECRET`, arquivos `.env` e chaves privadas em `certs/`. O Gitleaks (S7) confirmou **10 achados no histórico** (`evidencias/gitleaks-backend-away.json`, valores ocultos).

**Quando foi identificado.** Em **17/11/2026**, durante a preparação da implantação, ao ler o repositório para criar o deploy.

**O que foi feito.**

- Os arquivos foram **removidos da branch principal** pelo pull request nº 1 do repositório do backend, mesclado em **18/11/2026** (Backend-AWAY#1).
- Trechos que repetiam valores (`INSTRUCOES-VM.md`, `corrigir-cors-vm.sh`) foram trocados por *placeholders*.
- O `.gitignore` passou a bloquear certificados, chaves e `environment.config`.
- A aplicação implantada **não usa nenhum desses valores**: a senha do banco é gerada pela AWS (Secrets Manager) e o `JWT_SECRET` nem é usado pelo código.

**O que ainda depende do grupo (revogação).** Remover o arquivo não basta, porque ele permanece no histórico do Git.

| Credencial | Ação necessária | Situação na data da entrega (22/11/2026) |
|---|---|---|
| Senha do RDS antigo (Ohio) | Trocar a senha ou **apagar** o banco antigo | **Não confirmada pelo grupo.** A consulta à API da conta AWS atual, na região `us-east-2`, **não encontrou** nenhuma instância RDS, EC2 ou ambiente Beanstalk. O grupo não conseguiu confirmar se o banco foi apagado ou se estava em outra conta. A revogação continua **pendente de confirmação** |
| Senha da VM `98.83.35.183` | Trocar a senha ou **apagar** a VM | **Não confirmada.** Pendente |
| `JWT_SECRET` antigo | Considerar comprometido (não é usado pela aplicação atual) | Sem ação necessária |
| Autoridade certificadora e chaves de `certs/` | Remover de qualquer computador em que tenham sido instaladas como confiáveis | **Não confirmada.** Pendente de conferência |
| Uso da mesma senha em outros serviços | Trocar nesses serviços | **Não confirmada.** Pendente de conferência |

**Compromisso do grupo.** As pendências acima serão verificadas e resolvidas **depois da entrega**, e o resultado será registrado em [`evidencias/revogacao-credenciais.md`](evidencias/revogacao-credenciais.md) (pasta que o enunciado permite alterar após a tag). Até lá, o risco residual é o descrito na análise de ameaças (`seguranca.md`, ameaça 2): quem tiver acesso ao histórico público do `Backend-AWAY` pode obter as credenciais antigas, **que não são usadas por esta implantação**.

O **histórico** do repositório do backend continua contendo os valores antigos. Reescrever o histórico (`git filter-repo` + *force push*) é possível, mas quebraria os clones do outro integrante; a revogação acima é a medida que de fato protege.

O repositório entregue (`away-infra`) **não tem segredos** (Gitleaks sobre os 23 commits da época da varredura: nenhum achado).
