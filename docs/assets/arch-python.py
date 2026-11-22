#!/usr/bin/env python3
# Arquitetura aiops-control-node — Diagrama Python diagrams (Mingrammer)
# Executar com: python3 arch-python.py  (gera arch-python.png)

from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.compute import Server
from diagrams.onprem.security import Firewall
from diagrams.programming.language import Python
from diagrams.custom import Custom
from diagrams.aws.compute import EC2 as AWSNode
from diagrams.onprem.inventory import Inventory as Ansible

graph_attr = {
    "fontname": "Inter, -apple-system, sans-serif",
    "fontsize": "14",
    "bgcolor": "white",
    "rankdir": "LR",
    "pad": "0.5",
    "splines": "ortho",
    "nodesep": "0.6",
    "ranksep": "1.2",
}

node_attr = {
    "fontname": "Inter, -apple-system, sans-serif",
    "fontsize": "12",
    "style": "filled,rounded",
    "shape": "box",
}

with Diagram(
    "Arquitetura aiops-control-node",
    filename="arch-python",
    show=False,
    format="png",
    graph_attr=graph_attr,
    node_attr=node_attr,
):
    with Cluster("Control Node — agents-lab\nUbuntu 26.04", graph_attr={"style": "filled,rounded", "color": "#2c3e50", "fillcolor": "#f0f4f8"}):
        ansible = Ansible("Ansible\nControl Node")

    with Cluster("Managed Nodes\n(via SSH)", graph_attr={"style": "dashed", "color": "#2c3e50"}):
        ubuntu = Server("ubuntu\n:2220\nUbuntu 26.04")
        agentslab = Server("agents-lab\n:2230\nUbuntu 26.04")
        rhel10 = Server("rhel10\n:2240\nRHEL 10.2")
        awslinux = AWSNode("awslinux\n:2250\nAmazon Linux 2023")
        centos10 = Server("centos10\n:2260\nCentOS Stream 10")

    hitl = Firewall("HITL\nAprovação\nHumana")
    loop = Python("Loop AIOps\nDiagnóstico →\nAuditoria →\nValidação →\nAplicação")

    ansible >> Edge(color="#1565c0", style="bold") >> [ubuntu, agentslab, rhel10, awslinux, centos10]
    [ubuntu, agentslab, rhel10, awslinux, centos10] >> Edge(color="#f9a825", style="bold") >> hitl
    hitl >> Edge(color="#2e7d32", style="bold") >> loop
    loop >> Edge(color="#2e7d32", style="dashed") >> ansible
