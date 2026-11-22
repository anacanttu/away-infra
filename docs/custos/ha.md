# Custo da proposta de alta disponibilidade

## Método

Os valores unitários vêm da **estimativa oficial da Entrega 1** (AWS Pricing Calculator, `sa-east-1`, operação contínua de 730 h por mês; ver `estimativa.pdf` nesta pasta): NAT US$ 68,82, RDS US$ 29,20, ALB US$ 25,14, EC2 de aplicação US$ 22,60 e EC2 do bastion US$ 6,11. A proposta apenas **multiplica** esses itens pelas quantidades do desenho.

> **A conferir antes da entrega:** montar a proposta na calculadora oficial e colar o link em `custos/ha-calculadora.md`. Os valores abaixo seguem o mesmo método e devem coincidir com o resultado dela, exceto pelo tráfego entre zonas e o armazenamento do Multi-AZ, que a calculadora cobra à parte e que aqui foram considerados desprezíveis.

## Comparação com o cenário A da Entrega 1 (operação contínua)

| Item | Entrega 1 (implantada) | Proposta de HA | Como foi calculado |
|---|---|---|---|
| NAT Gateway | 68,82 | **137,64** | 2 NATs (um por zona) |
| RDS PostgreSQL | 29,20 | **58,40** | Multi-AZ cobra a instância e o armazenamento em dobro |
| Application Load Balancer | 25,14 | 25,14 | O mesmo ALB já cobria as duas zonas |
| EC2 da aplicação | 22,60 | **45,20** | 2 instâncias `t4g.small` |
| EC2 do bastion | 6,11 | 6,11 | Continua 1 instância (Auto Scaling de 1) |
| **Total mensal (USD)** | **151,87** | **272,49** | |
| **Variação** | — | **+120,62 (+79,4%)** | |
| Total em 12 meses | 1.822,44 | 3.269,88 | |

### Itens que mais contribuem para o aumento

1. **Segundo NAT Gateway: +US$ 68,82 por mês (57% do aumento).** É a escolha mais cara e a de menor benefício para este perfil, porque a saída para a internet só serve para atualizações.
2. **RDS Multi-AZ: +US$ 29,20 por mês (24%).**
3. **Segunda instância da aplicação: +US$ 22,60 por mês (19%).**

## Variante econômica: HA sem o segundo NAT

Mantém as duas instâncias e o Multi-AZ, mas com **um NAT compartilhado** (a escolha alternativa de H3):

| | Mensal (USD) | Variação sobre a Entrega 1 |
|---|---|---|
| NAT compartilhado + RDS Multi-AZ + 2 instâncias | **203,67** | **+51,80 (+34,1%)** |

Perde-se a saída para a internet se a zona do NAT cair, mas os usuários seguem atendidos.

## O custo se justifica?

**Não, para o perfil de uso deste sistema.** A seção 5.1 da Entrega 1 descreve:

- uso interno, de 5 a 15 usuários simultâneos, em horário comercial de segunda a sexta;
- sem usuário público e sem atendimento ao cidadão;
- dados que podem ser redigitados a partir de documentos de origem;
- RTO de 4 horas e RPO de 24 horas (ver [`../backup.md`](../backup.md)).

A proposta completa custa **US$ 120,62 a mais por mês (US$ 1.447 por ano)** para evitar indisponibilidades que, para esse perfil, são toleráveis: se a zona cair, o ambiente pode ser **recriado em cerca de 30 minutos** (`terraform apply` + Ansible), dentro do RTO de 4 horas. A queda de uma zona inteira é um evento raro. O custo, por outro lado, é **certo e mensal**.

**Recomendação do grupo:** manter a arquitetura **Single-AZ** da Entrega 1 e investir em **backup** (política GFS, menos de US$ 2 por mês) e em **reprodutibilidade** (Terraform + Ansible). A HA só passa a se justificar se o sistema se tornar crítico (por exemplo, atender a audiências judiciais com horário marcado) ou se o horário de uso passar a ser contínuo. Nesse caso, o primeiro passo seria a **variante econômica** (+34%), e não a proposta completa.

Para a HA se pagar, a indisponibilidade teria de custar à instituição **mais de US$ 120 por mês** em prejuízo. O grupo não tem esse dado, mas o perfil de uso descrito acima sugere que não.
