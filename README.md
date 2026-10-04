# AWAY - Infraestrutura em Nuvem

Projeto Integrador | Uniamérica Descomplica | Disciplina: Projeto Integrador | Professor: Gildomiro Bairros

## Grupo

| Integrante | GitHub |
|---|---|
| Ana Luisa Cantu | [@anacanttu](https://github.com/anacanttu) |
| Pablo | @ |

> Substituir/completar esta tabela com todos os integrantes do grupo antes da entrega.

## Visão geral

Este repositório documenta o projeto de arquitetura e as decisões de infraestrutura em nuvem (AWS) para implantar o **AWAY**, sistema de gestão de patronato penitenciário já existente do grupo:

- Frontend: [Frontend-AWAY](https://github.com/anacanttu/Frontend-AWAY) (Angular)
- Backend: [Backend-AWAY](https://github.com/anacanttu/Backend-AWAY) (Spring Boot + PostgreSQL)

Nesta entrega (Entrega 1) nenhuma infraestrutura é criada — o conteúdo é o projeto: diagrama, plano de rede, regras de segurança, dimensionamento, decisões arquiteturais (ADRs) e estimativa de custo. A implantação de fato ocorre na Entrega 2.

## Estrutura do repositório

```
/
├── README.md                          # Este arquivo
├── IA.md                              # Declaração de uso de IA
├── docs/
│   ├── arquitetura.md                 # Descrição, diagrama, endereçamento, rotas, segurança, tecnologias, dimensionamento, custos, riscos
│   ├── adr/
│   │   ├── 001-acesso-administrativo.md
│   │   ├── 002-saida-internet-subrede-privada.md
│   │   └── 003-localizacao-banco.md
│   ├── diagramas/
│   │   ├── arquitetura.drawio         # Fonte editável (draw.io/diagrams.net)
│   │   └── arquitetura.png            # Imagem exportada
│   └── custos/
│       └── estimativa.pdf             # Exportação da AWS Pricing Calculator
└── infra/                             # Vazio nesta entrega; Terraform/OpenTofu na Entrega 2
```

