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

---

# Entrega 2: uso de IA

## Ferramenta utilizada

Claude Code (Anthropic), como assistente de programação e de redação técnica, executando comandos na máquina de um integrante do grupo.

## Em quais partes foi usada

- **Código Terraform** (`infra/*.tf`): rede, grupos de segurança com saída restrita, instâncias, RDS, ALB com HTTPS, alerta de orçamento. Redigido e ajustado com a IA a partir do projeto da Entrega 1 e do enunciado.
- **Automação Ansible** (`infra/ansible/`): instalação do Docker, Nginx, backend e Keycloak, importação do realm, scripts de build e de inventário.
- **Ensaio local**: a IA montou e executou, na máquina do grupo, uma cópia local da pilha em Docker para testar login, cadastro e persistência antes de usar a AWS.
- **Varreduras de segurança**: instalação e execução do Trivy, Checkov e Gitleaks, e correção de parte dos achados.
- **Rascunho de documentos**: `seguranca.md`, `alta-disponibilidade.md`, `backup.md`, ADR-004, ADR-005, `errata.md`, o diagrama de alta disponibilidade, as tabelas de custo e este README.
- **Pesquisa**: preços de armazenamento (S3) na região de São Paulo, citados em `backup.md`.
- **Correção no repositório do backend**: remoção de segredos e certificados (pull request nº 1 do `Backend-AWAY`).

## O que a IA NÃO fez

- Não executou `terraform apply` nem criou recursos na AWS pelo grupo. A criação de recursos pela IA foi **bloqueada** pelo ambiente e é feita pelo grupo.
- Não habilitou o MFA, não criou as credenciais e não alterou o DNS do domínio.
- Não validou os preços na calculadora oficial da AWS: os valores de custo da HA foram calculados a partir da estimativa oficial da Entrega 1, e o custo do GFS usa preços de fontes públicas (indicadas) que o grupo deve conferir.

## O que o grupo verificou ou corrigiu

> **PREENCHER pelo grupo antes de entregar.** Esta seção só deve registrar o que cada integrante de fato conferiu.

- [ ] Leitura e compreensão de cada arquivo Terraform e do playbook Ansible pela integrante (o professor pode perguntar sobre qualquer parte).
- [ ] Conferência dos custos na AWS Pricing Calculator.
- [ ] Revisão das decisões de `seguranca.md` (achados aceitos e corrigidos).
- [ ] Preenchimento da revogação das credenciais antigas em `errata.md`.
- [ ] Teste do ambiente na AWS a partir do código da tag `entrega-2`.

Pontos que a IA errou ou que exigiram correção durante o trabalho, e que o grupo pode citar: a IA importou um key pair pela CLI (criação manual, depois corrigida para o Terraform); presumiu que o backend gerava um JAR, mas o projeto gera um WAR; e, durante o ensaio local, alterou a senha de um usuário de teste e chegou a explicar o erro de login de forma incorreta antes de corrigir.
