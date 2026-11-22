# ADR-004: Estratégia de alta disponibilidade (proposta)

No contexto de o AWAY rodar hoje em uma única zona de disponibilidade, com uma instância de aplicação, um RDS Single-AZ e um NAT Gateway (pontos únicos de falha listados na seção 5.10 da Entrega 1), e de a Entrega 2 pedir uma proposta de alta disponibilidade que **não será implantada**,

diante de um sistema de uso interno por 5 a 15 pessoas em horário comercial, com RTO de 4 horas e RPO de 24 horas, e do custo de nuvem pago pelo próprio grupo (a proposta completa custaria US$ 272,49 por mês, contra US$ 151,87 da arquitetura implantada),

decidimos propor: instâncias da aplicação em um Auto Scaling de no mínimo 2 em `sa-east-1a` e `sa-east-1b` atrás do ALB, **um NAT Gateway por zona**, **RDS Multi-AZ** com o Keycloak movido para o mesmo RDS, e o bastion como Auto Scaling de uma instância; e **recomendar não implantá-la** para o perfil de uso atual,

e descartamos um NAT Gateway compartilhado entre as zonas (mais barato em US$ 68,82 por mês, mas a queda da zona do NAT cortaria a saída das duas), uma réplica de leitura do RDS no lugar do Multi-AZ (não faz *failover* automático) e PostgreSQL próprio em EC2 com replicação manual (o grupo passaria a operar o banco, contrariando o ADR-003),

para que cada ponto único de falha da Entrega 1 seja eliminado ou aceito de forma explícita, e para que o grupo saiba quanto custaria evoluir quando o sistema se tornar crítico,

aceitando que a proposta completa é 79,4% mais cara, que a arquitetura implantada continua com os pontos únicos de falha (uma zona, uma instância, um banco, um bastion), que a recuperação depende de recriar o ambiente com Terraform e Ansible dentro do RTO de 4 horas, e que o Multi-AZ **não protege contra erro lógico** (um `DELETE` errado é replicado), o que fica a cargo do ADR-005 (backup).

**Status:** Proposta. Não implantada. Detalhes em [`docs/alta-disponibilidade.md`](../alta-disponibilidade.md) e custo em [`docs/custos/ha.md`](../custos/ha.md).
