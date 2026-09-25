# ADR-001: Estratégia de acesso administrativo

No contexto da instância de aplicação (`app-away`) ficar na sub-rede privada, sem IP público,

diante da necessidade de a equipe conseguir acessá-la via SSH para manutenção e depuração, sem expor essa porta diretamente à internet,

decidimos usar um **bastion host**: uma instância `t4g.nano` na sub-rede pública, com IP público, aceitando SSH (porta 22) apenas do endereço IP fixo do grupo, e retransmitindo o acesso para a instância privada,

e descartamos (a) dar um IP público diretamente à instância de aplicação e liberar SSH nela, o que exporia a porta 22 do próprio servidor de produção à internet; e (b) usar o AWS Systems Manager Session Manager, que elimina a necessidade de bastion e de porta 22 aberta em qualquer lugar, mas exige configurar um perfil IAM e o agente SSM na instância, e a disciplina exige explicitamente a demonstração de acesso via SSH nesta entrega,

para que a instância de aplicação nunca precise expor a porta 22 à internet, mantendo um único ponto de entrada auditável para acesso administrativo,

aceitando que o bastion é, ele próprio, um ponto único de falha para administração: se ele cair ou a chave SSH for perdida, a equipe perde o único caminho de acesso à sub-rede privada até recriá-lo, e ele exige seu próprio cuidado de patch e monitoramento de segurança, além de gerar um custo mensal recorrente (ainda que baixo, ~6 USD/mês) mesmo quando ninguém está administrando o sistema.
