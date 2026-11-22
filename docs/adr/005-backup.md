# ADR-005: Estratégia de backup (política GFS e política mínima)

No contexto de o AWAY guardar dados de assistidos e comparecimentos em um RDS PostgreSQL e de a Entrega 2 pedir uma política de backup, mas **configurar apenas uma política mínima** para não gerar custo durante meses,

diante de um RPO de 24 horas e um RTO de 4 horas (uso interno, horário comercial, dados que podem ser redigitados), e de um orçamento pago pelo próprio grupo,

decidimos recomendar a política **Grandfather-Father-Son** com dump lógico (`pg_dump`) gravado em um bucket S3 de outra região, em prefixos `diario/` (7 dias, S3 Standard), `semanal/` (4 semanas, Standard-IA) e `mensal/` (12 meses, Standard-IA), com regras de ciclo de vida por prefixo, criptografia e acesso por *instance profile* **sem permissão de apagar**; e **configurar agora apenas o backup automático do RDS com 1 dia de retenção** (a geração Son), por Terraform,

e descartamos snapshots de disco da EC2 (o banco é gerenciado, não há disco de banco a capturar), manter só os backups automáticos do RDS com 35 dias de retenção (ficam presos à instância e se perdem se ela for apagada) e guardar os backups na própria `sa-east-1` sem outra região (mais caro e menos resiliente),

para que o grupo consiga voltar a qualquer dia da última semana, a qualquer semana do último mês e a qualquer mês do último ano, a um custo estimado de **US$ 15,49 em 12 meses**, e para que o mecanismo de backup seja exercitado na prática pela política mínima, a custo próximo de zero,

aceitando que a política mínima **não protege** contra um erro descoberto depois de 1 dia, não gera cópia em outra região, apaga os backups junto com a instância, não cobre os usuários criados no Keycloak e **não teve a restauração testada**; e que o dump diário depende de uma rotina que o grupo ainda não automatizou.

**Status:** Política conservadora proposta; política mínima implementada. Detalhes em [`docs/backup.md`](../backup.md).
