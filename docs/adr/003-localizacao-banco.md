# ADR-003: Localização do banco de dados

No contexto de o AWAY precisar de um banco PostgreSQL para persistir dados de assistidos, usuários e comparecimentos, com backups e proteção contra perda de dados,

diante da restrição de orçamento do grupo (a instituição não oferece créditos de nuvem, o custo é pago do próprio bolso) e da necessidade de não gastar tempo do semestre administrando infraestrutura de banco de dados manualmente,

decidimos usar o **Amazon RDS para PostgreSQL** (`db.t4g.micro`, single-AZ, 20 GB gp3, na sub-rede privada, sem IP público),

e descartamos rodar o PostgreSQL em uma **instância EC2 própria** na sub-rede privada — opção que seria mais barata em compute (poderia até dividir a mesma instância `app-away`, evitando o custo adicional do RDS) e daria acesso root total ao sistema operacional do banco, mas exigiria do grupo configurar e testar backup manualmente, aplicar patches de segurança do SO e do próprio PostgreSQL, e montar de forma manual qualquer recuperação de desastre,

para que o banco tenha backup automático, patch de segurança gerenciado pela AWS e menor esforço operacional do grupo durante o semestre — tempo que pode ser direcionado à aplicação em si e não à manutenção de infraestrutura,

aceitando que o RDS custa mais por mês do que rodar Postgres na mesma instância EC2 já paga para a aplicação (29,20 USD/mês adicionais nesta arquitetura, ver seção 5.9), e que o grupo perde acesso direto ao sistema operacional do banco para depuração de baixo nível (ex.: não é possível instalar extensões do SO ou inspecionar processos do Postgres diretamente via SSH).
