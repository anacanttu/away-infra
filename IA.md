# Declaração de uso de IA

## Ferramenta utilizada

Claude (Anthropic), no papel de assistente de redação e pesquisa técnica.
ChatGPT (Open Ai), pesquisa técnica.

## Em quais partes foi usada

- **Redação inicial de todo o conteúdo** deste repositório: `docs/arquitetura.md`, os três ADRs em `docs/adr/`, este `IA.md` e o `README.md`.
- **Pesquisa de preços e comportamento de serviços da AWS** (ex.: descoberta de que o NAT Gateway é mais caro em `sa-east-1` do que em `us-east-1`, e de que existe uma seção "Gateway NAT regional" separada na calculadora que precisa ficar zerada/no mínimo para não inflar o custo por engano — isso de fato aconteceu uma vez durante o trabalho, gerando um PDF com estimativa de 356,95 USD/mês que foi descartado por estar incorreto).
- **Revisão do diagrama/documento** apontando duas exigências estruturais da AWS que a primeira versão da arquitetura não atendia: o Application Load Balancer precisa de subnets em pelo menos duas zonas de disponibilidade, e o DB Subnet Group do RDS também. O documento foi corrigido para incluir `pub-b`/`priv-b` sem transformar a arquitetura em alta disponibilidade real.

## O que o grupo verificou ou corrigiu


- **Exigências de rede da AWS**: o grupo verificou, com apoio de outra IA e da documentação oficial da AWS, que a primeira versão do diagrama estava tecnicamente incorreta (ALB e DB Subnet Group exigem pelo menos duas zonas de disponibilidade). A correção foi aplicada e o documento deixa explícito que isso não é alta disponibilidade real.
- **Decisões arquiteturais**: as três decisões registradas nos ADRs (bastion para acesso administrativo, NAT Gateway gerenciado, RDS gerenciado) foram discutidas e aprovadas pelo grupo antes de serem escritas; as alternativas descartadas e as consequências aceitas refletem entendimento real do trade-off, não apenas texto gerado.
- **Dimensionamento das instâncias**: os tamanhos escolhidos (t4g.small para aplicação, t4g.nano para bastion, db.t4g.micro para o banco) foram revisados considerando a carga real esperada do sistema (uso interno de uma instituição, poucos usuários simultâneos), não aceitos automaticamente da sugestão padrão da calculadora.
- **CIDR e segmentação de rede**: o plano de endereçamento foi revisado para garantir que não há sobreposição entre sub-redes e que o tamanho `/24` deixa margem para a expansão prevista na Entrega 2 (segunda zona de disponibilidade).
- **Diagrama**: a imagem gerada foi inspecionada visualmente para confirmar a presença de todos os elementos obrigatórios (CIDRs, zona de disponibilidade, grupos de segurança, três fluxos numerados) antes de ser aceita.

Nenhum conteúdo gerado pela IA foi incluído sem revisão do grupo.
