# Estado & Handoff — AIOps Control Node

## Decisões Arquiteturais
- Control Node Ubuntu 26.04 (WSL2) gerenciando 5 distros WSL2 via SSH + Ansible (portas 2220–2260).
- DNS determinístico: `generateResolvConf = false` em `/etc/wsl.conf` dos hosts.
- HITL: playbooks somente-leitura sem `become`; alterações exigem `--check --diff --ask-become-pass`.

## Concluído & Validado
- [x] Conectividade SSH validada nos 5 hosts do `ansible/inventory.ini`.
- [x] `ansible/playbooks/diagnostico-somente-leitura.yml` validado com `ansible-lint` e executado (`changed=0` nos 5 hosts).
- [x] Sudo restrito configurado nos hosts gerenciados.
- [x] Falhas `getty@tty1`/`user-runtime-dir@0` em WSL2 tratadas como falso positivo esperado.

## Pendências & Próximos Passos
1. Corrigir e aplicar `ansible/playbooks/hostname-correction.yml` para `centos10` (atual: `host-fisico`) e `amazonlinux-2023` (atual: `awslinux`): validar com `ansible-playbook -i ansible/inventory.ini ansible/playbooks/hostname-correction.yml --check --diff --ask-become-pass` antes de aplicar.
2. Executar auditoria inicial com a skill `lpic1-audit` nos 5 hosts acessíveis.
