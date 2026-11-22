# Estado & Handoff — AIOps Control Node

## Decisões Arquiteturais
- Control Node Ubuntu 26.04 (WSL2) gerenciando 5 distros WSL2 via SSH + Ansible (portas 2220–2260).
- DNS determinístico: `generateResolvConf = false` em `/etc/wsl.conf` dos hosts.
- HITL: playbooks somente-leitura sem `become`; alterações exigem `--check --diff --ask-become-pass`.
- `ssh-hardening.yml` usa `become: true` apenas em `ubuntu_nodes` para `sshd_config.d` e `getty@tty1` maskado em 4 hosts (não em `awslinux`).
- `/etc/shadow` modo `000` mantido (padrão seguro nativo RHEL/CentOS/Amazon Linux). Porta `11434` (Ollama) mantida sem alteração de bind.
- Hostnames validados (`centos10`, `amazonlinux-2023`) — `hostname-correction.yml` descartado.

## Concluído & Validado
- [x] Conectividade SSH validada nos 5 hosts do `ansible/inventory.ini`.
- [x] Usuário `ansible-ops` com sudo restrito configurado nos hosts.
- [x] Auditoria LPIC-1 (skill `lpic1-audit`) executada nos 5 hosts (somente-leitura, `changed=0`).
- [x] `ansible/playbooks/ssh-hardening.yml` aprovado pelo `ansible-lint` (0 falhas) e aplicado: `PasswordAuthentication no` em `ubuntu`/`agents-lab`; `getty@tty1.service` maskado em 4 hosts; `sshd -t` válido; `ssh` recarregado.
- [x] `docs/ANSIBLE-GUIDE.md` reescrito (sem corrupção de texto). `docs/EMERGENCY-STOP.md` e `docs/IA-BEST-PRACTICES.md` corrigidos (usuário `ansible-ops`, `reboot` removido do sudo, porta SSH `0.0.0.0`).
- [x] Repositório Git publicado: `AlexRabelo/aiops-control-node` (branch `main`, working tree limpo).

## Pendências & Próximos Passos
- Remediação pendente da auditoria LPIC-1: `/etc/shadow` em `000` (rhel10/centos10/awslinux) e serviço `*:11434` exposto em todas as interfaces (5 hosts) — avaliar HITL antes de aplicar.
- Comandos alvo: `ansible-playbook --check --diff --ask-become-pass` para qualquer playbook de remediação futura.
