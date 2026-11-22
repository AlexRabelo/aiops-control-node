# Estado & Handoff — AIOps Control Node

## Decisões Arquiteturais
- Control Node Ubuntu 26.04 (WSL2) gerenciando 5 distros WSL2 via SSH + Ansible (portas 2220–2260).
- DNS determinístico: `generateResolvConf = false` em `/etc/wsl.conf` dos hosts.
- HITL: playbooks somente-leitura sem `become`; alterações exigem `--check --diff --ask-become-pass`.
- `ssh-hardening.yml` usa `become: true` (ansible.builtin.sudo) apenas em `ubuntu_nodes` para `sshd_config.d` e `getty@tty1` maskado em 4 hosts (não em `awslinux` — fora do escopo).
- `/etc/shadow` em modo `000` mantido (padrão seguro nativo RHEL/CentOS/Amazon Linux) — não aplicar `chmod`.
- Porta `11434` mantida (Ollama compartilhado via loopback NAT do WSL2) — não aplicar alteração de bind.
- Hostnames validados na coleta LPIC-1: `centos10` e `amazonlinux-2023` — não aplicar `hostname-correction.yml`.

## Concluído & Validado
- [x] Conectividade SSH validada nos 5 hosts do `ansible/inventory.ini`.
- [x] Usuário de serviço `ansible-ops` com sudo restrito configurado nos hosts gerenciados.
- [x] Auditoria LPIC-1 (skill `lpic1-audit`) executada nos 5 hosts (somente-leitura, `changed=0`).
- [x] `ansible/playbooks/ssh-hardening.yml` aprovado pelo `ansible-lint` (0 falhas) e aplicado com sucesso: `PasswordAuthentication no` em `ubuntu`/`agents-lab`; `getty@tty1.service` maskado em `ubuntu`, `agents-lab`, `rhel10`, `centos10`; `sshd -t` válido; `ssh` recarregado onde houve alteração.
- [x] Correção de hostnames (`hostname-correction.yml`) desnecessária — hostnames já válidos na coleta.

## Próximo Passo Único
- Inicializar o repositório Git (`git init -b main`) e publicar no GitHub (`AlexRabelo/aiops-control-node`).
