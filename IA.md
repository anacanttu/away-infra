# Declaração de uso de IA

## Ferramenta utilizada

Claude (Anthropic), via Claude Code, no papel de assistente de redação e pesquisa técnica.

## Em quais partes foi usada

- **Redação inicial de todo o conteúdo** deste repositório: `docs/arquitetura.md`, os três ADRs em `docs/adr/`, este `IA.md` e o `README.md`.
- **Geração do diagrama de arquitetura** (`docs/diagramas/arquitetura.py`), usando a biblioteca Python `diagrams` (diagrams-as-code), a partir da descrição da arquitetura decidida em conversa com o grupo.
- **Preenchimento da estimativa de custo** na AWS Pricing Calculator (interação direta com a calculadora oficial via navegador), incluindo a escolha de tipos de instância, região e parâmetros de uso.
- **Pesquisa de preços e comportamento de serviços da AWS** (ex.: descoberta de que o NAT Gateway é mais caro em `sa-east-1` do que em `us-east-1`, e de que existe uma seção "Gateway NAT regional" separada na calculadora que precisou ser zerada para não inflar o custo).

## O que o grupo verificou ou corrigiu

- **Preços da calculadora**: todos os valores de custo apresentados em `docs/arquitetura.md` foram conferidos manualmente contra a exportação em `docs/custos/estimativa.csv`, gerada diretamente pela AWS Pricing Calculator (não são valores inventados pela IA).
- **Decisões arquiteturais**: as três decisões registradas nos ADRs (bastion para acesso administrativo, NAT Gateway gerenciado, RDS gerenciado) foram discutidas e aprovadas pelo grupo antes de serem escritas; as alternativas descartadas e as consequências aceitas refletem entendimento real do trade-off, não apenas texto gerado.
- **Dimensionamento das instâncias**: os tamanhos escolhidos (t4g.small para aplicação, t4g.nano para bastion, db.t4g.micro para o banco) foram revisados considerando a carga real esperada do sistema (uso interno de uma instituição, poucos usuários simultâneos), não aceitos automaticamente da sugestão padrão da calculadora.
- **CIDR e segmentação de rede**: o plano de endereçamento foi revisado para garantir que não há sobreposição entre sub-redes e que o tamanho `/24` deixa margem para a expansão prevista na Entrega 2 (segunda zona de disponibilidade).
- **Diagrama**: a imagem gerada foi inspecionada visualmente para confirmar a presença de todos os elementos obrigatórios (CIDRs, zona de disponibilidade, grupos de segurança, três fluxos numerados) antes de ser aceita.

Nenhum conteúdo gerado pela IA foi incluído sem revisão do grupo.
