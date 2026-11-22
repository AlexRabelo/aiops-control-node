# AIOps Control Node — SRE & DevOps

[![Ubuntu 26.04](https://img.shields.io/badge/Ubuntu-26.04%20LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Ansible](https://img.shields.io/badge/Ansible-Idempotent-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![OpenCode](https://img.shields.io/badge/OpenCode-AIOps-22D3EE)](https://opencode.ai/)
[![SRE / DevOps](https://img.shields.io/badge/Focus-SRE%20%26%20DevOps-3B82F6)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Control Node **Ubuntu 26.04 (WSL 2)** dedicado a gerenciar servidores **Enterprise Linux** via **SSH**, **Ansible** e **observabilidade**, aplicando guardrails de segurança para agentes de IA (*Human-in-the-Loop*, *DLP* e validação estática).

> Os nós gerenciados (`rhel10`, `centos10`, `amazonlinux-2023`) são provisionados pelo projeto irmão [wsl2-enterprise-linux-lab](https://github.com/AlexRabelo/wsl2-enterprise-linux-lab).

---

## Arquitetura

```text
aiops-control-node/ (Ubuntu 26.04 — WSL 2)
├── AGENTS.md                        # Papel, hosts e guardrails do analista SRE/DevOps
├── MEMORY.md                        # Estado persistente e handoff entre sessões
├── README.md                        # Este arquivo
├── .gitignore                       # Bloqueio de chaves privadas, .env e caches
├── LICENSE                          # Licença MIT
├── ansible/
│   ├── inventory.ini                # Inventário dos 5 hosts gerenciados
│   ├── vars/hostnames.yml           # Hostnames padronizados por host
│   └── playbooks/                   # Playbooks Ansible idempotentes
├── docs/
│   ├── ANSIBLE-GUIDE.md             # Guia conceitual e operacional de Ansible
│   ├── EMERGENCY-STOP.md            # Procedimento de parada e reversão
│   └── IA-BEST-PRACTICES.md         # Práticas de IA para Infra/SRE/SysOps
└── scripts/
    └── set-hostname-ubuntu.sh       # Script auxiliar de hostname no WSL 2

# Camada Global do Agente (~/.config/opencode/)
# ├── opencode.jsonc                 # Modelo LLM (NVIDIA Nemotron 3.5) + MCPs (fetch, github)
# ├── AGENTS.md                      # Padrões globais, catálogo de docs oficiais e memória
# ├── commands/handoff.md            # Comando /handoff para atualização do MEMORY.md
# └── skills/                        # Skills reutilizáveis sob demanda
