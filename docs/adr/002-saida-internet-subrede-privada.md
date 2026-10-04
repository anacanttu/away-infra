# ADR-002: Saída para a internet da sub-rede privada

No contexto de a instância de aplicação (`app-away`) rodar na sub-rede privada e precisar baixar atualizações de pacotes do sistema operacional, imagens Docker (backend e Keycloak) e eventualmente se comunicar com serviços externos, sem ter um IP público próprio,

diante da exigência da disciplina de que a Entrega 2 tenha, obrigatoriamente, um NAT gerenciado, e da necessidade real de a instância privada conseguir iniciar conexões de saída,

decidimos usar o NAT Gateway gerenciado da AWS, provisionado na sub-rede pública, com a rota `0.0.0.0/0` da sub-rede privada apontando para ele,

e descartamos duas alternativas: (a) uma NAT instance** — uma EC2 comum configurada manualmente para rotear tráfego, que custaria uma fração do NAT Gateway gerenciado (~6 USD/mês contra ~69 USD/mês nesta arquitetura, já que o NAT Gateway em `sa-east-1` é cobrado por hora e por dado processado), mas exigiria que o próprio grupo aplicasse patches de segurança no SO da instância, monitorasse sua saúde e aceitasse que ela é um ponto único de falha sem qualquer redundância automática; e (b) ausência total de saída para internet, que eliminaria esse custo por completo, mas inviabilizaria qualquer atualização de pacotes ou pull de imagem Docker na instância, decisão descartada porque tornaria a manutenção do servidor impraticável,

para que a instância privada tenha saída para a internet sem exigir do grupo nenhuma administração de sistema operacional dedicada a NAT, e sem abrir mão da segurança de não ter IP público na instância de aplicação,

aceitando que o NAT Gateway gerenciado é, disparadamente, o item mais caro de toda a arquitetura (68,82 USD/mês), cobrado por hora de existência mesmo em períodos de baixíssimo tráfego, o que é um custo real e desproporcional ao uso de dados de fato.
