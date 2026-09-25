"""
Diagrama de arquitetura do sistema AWAY na AWS - Entrega 1.

Gera docs/diagramas/arquitetura.png a partir deste codigo-fonte
(diagrams-as-code, biblioteca `diagrams` + Graphviz).

Executar:
    pip install diagrams
    brew install graphviz   # ou apt-get install graphviz
    python3 arquitetura.py
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import EC2
from diagrams.aws.database import RDS
from diagrams.aws.network import ALB, InternetGateway, NATGateway
from diagrams.aws.general import Users
from diagrams.aws.security import IdentityAndAccessManagementIamPermissions as SGIcon

graph_attr = {
    "fontsize": "20",
    "bgcolor": "white",
    "pad": "0.5",
    "splines": "ortho",
}

with Diagram(
    "AWAY - Arquitetura AWS (Entrega 1)",
    filename="arquitetura",
    show=False,
    direction="TB",
    graph_attr=graph_attr,
):
    usuario = Users("Usuario final")
    admin = Users("Administrador\n(SSH)")

    with Cluster("AWS - Regiao sa-east-1 (Sao Paulo)"):
        igw = InternetGateway("Internet Gateway")

        with Cluster("VPC vpc-away  |  CIDR 10.20.0.0/16"):

            with Cluster("Zona de disponibilidade: sa-east-1a"):

                with Cluster("Subnet publica  pub-a  |  10.20.1.0/24"):
                    alb = ALB("ALB\nsg-alb\n(HTTPS 443)")
                    bastion = EC2("Bastion\nsg-bastion\nIP publico\n(SSH 22)")
                    nat = NATGateway("NAT Gateway")

                with Cluster("Subnet privada  priv-a  |  10.20.10.0/24"):
                    app = EC2(
                        "app-away\nsg-app\nsem IP publico\n"
                        "Nginx + Angular\n+ Spring Boot + Keycloak"
                    )
                    db = RDS("db-away\nsg-db\nPostgreSQL\nsem IP publico")

        # Fluxo 1: usuario final acessando a aplicacao
        usuario >> Edge(label="1. HTTPS 443", color="#1a73e8", penwidth="2") >> igw
        igw >> Edge(color="#1a73e8", penwidth="2") >> alb
        alb >> Edge(label="80 (interno)", color="#1a73e8", penwidth="2") >> app

        # Fluxo 2: administrador via SSH pelo bastion
        admin >> Edge(label="2. SSH 22", color="#e8710a", penwidth="2", style="dashed") >> igw
        igw >> Edge(color="#e8710a", penwidth="2", style="dashed") >> bastion
        bastion >> Edge(label="SSH 22", color="#e8710a", penwidth="2", style="dashed") >> app

        # Fluxo 3: instancia privada acessando a internet pelo NAT
        app >> Edge(label="3. saida internet", color="#188038", penwidth="2", style="dotted") >> nat
        nat >> Edge(color="#188038", penwidth="2", style="dotted") >> igw

        # Trafego interno app -> banco
        app >> Edge(label="5432", color="#5f6368") >> db
