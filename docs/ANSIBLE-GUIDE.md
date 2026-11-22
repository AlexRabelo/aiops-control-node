# Guia Completo — Ansible no Projeto AIOps Control Node

Este documento explica, em detalhes conceituais e práticos, como o **Ansible** é utilizado no projeto `aiops-control-node`, sua importância no contexto de SRE/DevOps, o fluxo de trabalho obrigatório e exemplos práticos para os hosts gerenciados (`centos10`, `amazonlinux-2023`, `rhel10`, `ubuntu`, `agents-lab`).

---

## Sumário

1. [O que é o Ansible?](#1-o-que-é-o-ansible)
2. [Por que Ansible neste projeto?](#2-por-que-ansible-neste-projeto)
3. [Arquitetura e componentes](#3-arquitetura-e-componentes)
4. [Fluxo de trabalho obrigatório](#4-fluxo-de-trabalho-obrigatório)
5. [Passo a passo: do zero ao primeiro playbook](#5-passo-a-passo-do-zero-ao-primeiro-playbook)
6. [Exemplos práticos por host](#6-exemplos-práticos-por-host)
7. [Ansible Vault: gerenciamento de segredos](#7-ansible-vault-gerenciamento-de-segredos)
8. [Validação antes de aplicar](#8-validação-antes-de-aplicar)
9. [Diagramas e esquemas](#9-diagramas-e-esquemas)
10. [Importância no contexto AIOps/SRE](#10-importância-no-contexto-aiops-sre)
11. [Checklist de boas práticas](#11-checklist-de-boas-práticas)

---

## 1. O que é o Ansible?

O **Ansible** é uma ferramenta de automação de TI open source (Red Hat) para gerenciamento de configuração, implantação de aplicações e orquestração de tarefas. Seus pilares:

| Pilar | Descrição |
|-------|-----------|
| **Agentless** | Não precisa instalar agente nos hosts remotos. Apenas requer SSH e Python. |
| **Declarativo** | Você descreve o *estado desejado* (ex: "o pacote nginx deve estar instalado e iniciado"), não os passos imperativos. |
| **Idempotente** | Executar a mesma tarefa múltiplas vezes produz o mesmo resultado, sem efeitos colaterais após a primeira aplicação. |
| **YAML** | Playbooks e inventários são escritos em YAML, legível por humanos e fácil de versionar em Git. |

---

## 2. Por que Ansible neste projeto?

O `aiops-control-node` gerencia servidores Enterprise Linux distribuídos. Sem automação, cada mudança exigiria acesso manual via SSH a cada host, propenso a erros e sem rastreabilidade. O Ansible resolve:

| Problema manual | Solução com Ansible |
|-----------------|---------------------|
| Alterar `/etc/hostname` em 5 hosts um por um | Um playbook altera todos de forma consistente |
| Esquecer se um serviço foi iniciado em um host | Idempotência garante o estado desejado |
| Sem registro do que foi alterado | Playbooks versionados em Git servem como documentação executável |
| Risco de comandos destrutivos acidentais | `--check --diff` simula antes de aplicar; `policy-validator` bloqueia comandos perigosos |
| Senhas e chaves expostas | `Ansible Vault` criptografa segredos |

---

## 3. Arquitetura e componentes

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTROL NODE (Ubuntu 26.04)                  │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐   │
│  │  Inventário │  │  Playbooks  │  │  Ansible Vault       │   │
│  │  inventory.ini│ │  .yml       │  │  (segredos cript.)  │   │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────┘   │
│         │                │                     │               │
│         └────────────────┴─────────────────────┘               │
│                       SSH (porta 2220-2260)                     │
│                              │                                  │
└──────────────────────────────┼──────────────────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
   ┌────▼────┐            ┌────▼────┐           ┌────▼────┐
   │centos10 │            │rhel10   │           │awslinux │
   │CentOS   │            │RHEL 10  │           │Linux 2023│
   │Stream 10│            │         │           │SSH:2250 │
   │SSH:2260 │            │SSH:2240 │           └────┬────┘
   └────┬────┘            └────┬────┘                │
        │                      │                      │
   ┌────▼────┐            ┌────▼────┐           ┌────▼────┐
   │ubuntu   │            │agents-lab│           │         │
   │Ubuntu   │            │Ubuntu   │           │         │
   │26.04    │            │26.04    │           │         │
   │SSH:2220 │            │SSH:2230 │           │         │
   └─────────┘            └─────────┘           └─────────┘
```

### Componentes principais

| Componente | Função no projeto |
|------------|-------------------|
| **Control Node** | Ubuntu 26.04 onde o Ansible está instalado e os playbooks são executados |
| **Managed Nodes** | Os 5 hosts Linux gerenciados via SSH |
| **Inventory** | Arquivo `ansible/inventory.ini` que lista hosts, grupos, portas e usuários |
| **Playbook** | Arquivo YAML com uma lista de plays e tarefas a serem executadas |
| **Task** | Unidade mínima de trabalho (ex: instalar pacote, copiar arquivo, iniciar serviço) |
| **Module** | Implementação de uma tarefa (ex: `ansible.builtin.package`, `ansible.builtin.service`, `ansible.builtin.lineinfile`) |
| **Handler** | Tarefa executada apenas quando notificada por outra tarefa (ex: reiniciar sshd após mudar `sshd_config`) |
| **Role** | Estrutura de diretórios que organiza playbooks, variáveis, templates e tarefas para reutilização |
| **Fact** | Informações coletadas automaticamente sobre o host remoto (versão do SO, memória, interfaces de rede) |

---

## 4. Fluxo de trabalho obrigatório

Toda alteração persistente na infraestrutura segue este fluxo, conforme definido no `AGENTS.md`:

```
┌─────────────┐
│  1. Diagnóstico  │  ← linux-triage: coleta somente-leitura via SSH
└──────┬──────────┘
       │
       ▼
┌─────────────┐
│  2. Auditoria  │  ← lpic1-audit: verifica hardening e conformidade
└──────┬──────────┘
       │
       ▼
┌─────────────┐
│  3. Playbook  │  ← ansible-remediation: gera playbook idempotente
│    YAML       │     em ansible/playbooks/
└──────┬──────────┘
       │
       ▼
┌─────────────┐
│  4. Validação │  ← policy-validator: regras de segurança
│  (estática)   │     + ansible-lint
└──────┬──────────┘
       │
       ▼
┌─────────────┐
│  5. Simulação │  ← ansible-playbook --check --diff
│   (dry-run)   │     → mostra o que mudaria sem aplicar
└──────┬──────────┘
       │
       ▼
┌─────────────┐
│  6. HITL      │  ← human-in-the-loop: operador aprova/rejeita
│  (aprovação)  │     com base no impacto e reversão
└──────┬──────────┘
       │
       ▼
┌─────────────┐
│  7. Aplicação │  ← ansible-playbook (sem --check)
│   real        │
└──────┬──────────┘
       │
       ▼
┌─────────────┐
│  8. Validação │  ← Critério de validação do relatório técnico
│   pós-aplica  │
└─────────────┘
```

**Regra de ouro:** Nunca pule a etapa 5 (simulação) ou a etapa 6 (aprovação humana).

---

## 5. Passo a passo: do zero ao primeiro playbook

### 5.1 Instalar o Ansible no Control Node

```bash
# No Ubuntu 26.04 (Control Node)
sudo apt update
sudo apt install -y ansible python3-pip sshpass
ansible --version
```

### 5.2 Configurar o inventário

O arquivo `ansible/inventory.ini` já existe no projeto. Exemplo de referência:

```ini
[centos]
centos10 ansible_host=127.0.0.1 ansible_port=2260 ansible_user=ansible-ops ansible_ssh_private_key_file=~/.ssh/id_linux-mcp-server

[amazonlinux]
awslinux ansible_host=127.0.0.1 ansible_port=2250 ansible_user=ansible-ops ansible_ssh_private_key_file=~/.ssh/id_linux-mcp-server

[rhel]
rhel10 ansible_host=127.0.0.1 ansible_port=2240 ansible_user=ansible-ops ansible_ssh_private_key_file=~/.ssh/id_linux-mcp-server

[ubuntu_nodes]
ubuntu ansible_host=127.0.0.1 ansible_port=2220 ansible_user=ansible-ops ansible_ssh_private_key_file=~/.ssh/id_linux-mcp-server
agents-lab ansible_host=127.0.0.1 ansible_port=2230 ansible_user=ansible-ops ansible_ssh_private_key_file=~/.ssh/id_linux-mcp-server

[linux:children]
centos
amazonlinux
rhel
ubuntu_nodes

[linux:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o ServerAliveInterval=30 -o ServerAliveCountMax=3'
```

### 5.3 Testar conectividade

```bash
# Teste com todos os hosts
ansible all -i ansible/inventory.ini -m ping

# Teste apenas um grupo
ansible centos -i ansible/inventory.ini -m ping

# Teste com comando arbitrário
ansible all -i ansible/inventory.ini -a "hostnamectl --static"
```

### 5.4 Criar o primeiro playbook

Exemplo: garantir que o serviço SSH esteja iniciado e habilitado em todos os hosts Linux.

```yaml
---
- name: Garantir serviço SSH ativo e habilitado
  hosts: linux
  become: true
  become_method: ansible.builtin.sudo
  tasks:
    - name: Garantir que o sshd esteja iniciado e habilitado
      ansible.builtin.service:
        name: ssh
        state: started
        enabled: yes

    - name: Aplicar hardening do sshd_config
      ansible.builtin.lineinfile:
        path: /etc/ssh/sshd_config.d/99-hardening.conf
        regexp: '^#?PermitRootLogin'
        line: 'PermitRootLogin no'
        state: present
        mode: '0644'
      notify: reiniciar sshd

  handlers:
    - name: reiniciar sshd
      ansible.builtin.service:
        name: ssh
        state: restarted
```

Salve como `ansible/playbooks/hardening-sshd.yml`.

### 5.5 Validar com ansible-lint

```bash
ansible-lint ansible/playbooks/hardening-sshd.yml
```

Se não houver erros, prossiga. Caso houver, corrija o YAML ou as regras antes de continuar.

### 5.6 Simular aplicação (dry-run)

```bash
ansible-playbook -i ansible/inventory.ini --check --diff \
  ansible/playbooks/hardening-sshd.yml
```

O `--check` não aplica mudanças. O `--diff` mostra o que seria alterado em cada arquivo.

### 5.7 Solicitar aprovação (HITL)

Apresente ao operador:

```
## 🛑 HITL — Pedido de Aprovação

### Ação solicitada
Aplicar playbook hardening-sshd.yml em todos os hosts Linux.

### Host(s) alvo
ubuntu, agents-lab, rhel10, awslinux, centos10

### Impacto esperado
- sshd_config será alterado (PermitRootLogin no)
- Serviço ssh será reiniciado se a configuração mudar
- Breve interrupção de SSH durante o restart (reconectar imediatamente)

### Plano de reversão
Restaurar /etc/ssh/sshd_config do backup e reiniciar sshd.

### Janela de execução
Imediato, com operador disponível para reconectar via SSH.

### Confiança do agente
Alta
```

O operador responde `aprovar`, `rejeitar`, `ajustar` ou `adiar`.

### 5.8 Aplicar (somente após aprovação)

```bash
ansible-playbook -i ansible/inventory.ini \
  ansible/playbooks/hardening-sshd.yml
```

### 5.9 Validar pós-aplicação

```bash
# Verificar se o sshd está rodando em todos os hosts
ansible all -i ansible/inventory.ini -a "systemctl is-active ssh"

# Verificar se a configuração foi aplicada
ansible all -i ansible/inventory.ini -a "grep '^PermitRootLogin' /etc/ssh/sshd_config.d/99-hardening.conf"
```

---

## 6. Exemplos práticos por host

### 6.1 Definir hostname (centos10, rhel10, awslinux)

```yaml
---
- name: Definir hostname persistente nos hosts Linux
  hosts: centos,rhel,amazonlinux
  become: true
  become_method: ansible.builtin.sudo
  tasks:
    - name: Definir hostname estático
      ansible.builtin.hostname:
        name: "{{ inventory_hostname }}"
      when: ansible_hostname != inventory_hostname

    - name: Garantir /etc/hostname correspondente
      ansible.builtin.copy:
        content: "{{ inventory_hostname }}\n"
        dest: /etc/hostname
        owner: root
        group: root
        mode: '0644'
```

### 6.2 Configurar /etc/wsl.conf (hosts WSL2)

```yaml
---
- name: Configurar /etc/wsl.conf para WSL2
  hosts: ubuntu_nodes,centos,rhel,amazonlinux
  become: true
  become_method: ansible.builtin.sudo
  tasks:
    - name: Escrever /etc/wsl.conf
      ansible.builtin.copy:
        content: |
          [boot]
          systemd=true

          [user]
          default=arabelo

          [network]
          hostname = {{ inventory_hostname }}
          generateHosts = false
          generateResolvConf = true
        dest: /etc/wsl.conf
        owner: root
        group: root
        mode: '0644'
```

### 6.3 Mascarar getty@tty1 em containers WSL2

```yaml
---
- name: Mascarar getty@tty1 em containers WSL2
  hosts: ubuntu,agents-lab,rhel10,centos10
  become: true
  become_method: ansible.builtin.sudo
  tasks:
    - name: Mascarar getty@tty1.service
      ansible.builtin.systemd:
        name: getty@tty1.service
        masked: true
        state: stopped
```

---

## 7. Ansible Vault: gerenciamento de segredos

Nunca armazene senhas, tokens ou chaves privadas em texto claro nos playbooks. Use o **Ansible Vault** para criptografar arquivos de variáveis sensíveis.

### Criar arquivo criptografado

```bash
ansible-vault create ansible/group_vars/linux/vault.yml
```

Conteúdo exemplo (`vault.yml`):

```yaml
vault_ssh_password: "senha-secreta-aqui"
vault_api_token: "token-de-api-confidencial"
```

### Usar no playbook

```yaml
---
- name: Exemplo com vault
  hosts: linux
  become: true
  become_method: ansible.builtin.sudo
  vars_files:
    - ansible/group_vars/linux/vault.yml
  tasks:
    - name: Exibir apenas o nome da variável (não o valor)
      ansible.builtin.debug:
        msg: "Token configurado (valor oculto por segurança)"
      no_log: true
```

### Executar playbook com vault

```bash
ansible-playbook -i ansible/inventory.ini \
  --ask-vault-pass \
  ansible/playbooks/meu-playbook.yml
```

Ou armazene a senha do vault em um arquivo de senha:

```bash
echo "senha-do-vault" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

ansible-playbook -i ansible/inventory.ini \
  --vault-password-file ~/.ansible_vault_pass \
  ansible/playbooks/meu-playbook.yml
```

---

## 8. Validação antes de aplicar

### 8.1 ansible-lint

```bash
# Instalar se necessário
pip3 install ansible-lint

# Validar um playbook
ansible-lint ansible/playbooks/meu-playbook.yml

# Validar todos os playbooks
ansible-lint ansible/playbooks/
```

### 8.2 --check --diff (simulação)

```bash
ansible-playbook -i ansible/inventory.ini \
  --check --diff \
  ansible/playbooks/meu-playbook.yml
```

- `--check`: não faz mudanças reais
- `--diff`: mostra as diferenças que seriam aplicadas em arquivos

### 8.3 policy-validator

Antes de aplicar, rode a skill `policy-validator` para verificar:
- Ausência de comandos destrutivos (`rm -rf`, `mkfs`, `dd`, `wipefs`, `reboot`)
- Ausência de credenciais em texto claro
- Idempotência das tarefas

---

## 9. Diagramas e esquemas

### Fluxo de decisão (mermaid)

```mermaid
flowchart TD
    A[Início: Diagnóstico via linux-triage] --> B[Auditoria via lpic1-audit]
    B --> C[Gerar playbook via ansible-remediation]
    C --> D[policy-validator: regras de segurança]
    D -->|Reprovado| C
    D -->|Aprovado| E[ansible-lint + --check --diff]
    E -->|Erro| C
    E -->|OK| F[HITL: aprovação humana]
    F -->|Rejeitado| G[Fim: ação não executada]
    F -->|Aprovado| H[ansible-playbook aplicação real]
    H --> I[Validação pós-aplicação]
    I --> Fim[Fim: relatório técnico]
```

### Camadas de segurança

```mermaid
graph TD
    subgraph "Camada 1: Prevenção"
        A[policy-validator: bloquear playbooks inseguros]
    end
    subgraph "Camada 2: Detecção"
        B[ansible-lint: erros de YAML e boas práticas]
        C[--check --diff: simulação de impacto]
    end
    subgraph "Camada 3: Autorização"
        D[human-in-the-loop: aprovação explícita do operador]
    end
    subgraph "Camada 4: Auditoria"
        E[logs/approvals: registro de decisões]
        F[MEMORY.md: histórico do projeto]
    end

    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
```

### Hierarquia de arquivos do projeto

```
aiops-control-node/
├── AGENTS.md                    # Papel e guardrails do agente
├── MEMORY.md                    # Memória do projeto (este contexto)
├── README.md                    # Visão geral do projeto
├── docs/
│   ├── ANSIBLE-GUIDE.md         # Este documento
│   └── EMERGENCY-STOP.md        # Procedimento de parada de emergência
├── ansible/
│   ├── inventory.ini            # Inventário de hosts
│   ├── group_vars/
│   │   └── linux/
│   │       └── vault.yml        # Variáveis criptografadas (Ansible Vault)
│   └── playbooks/
│       ├── hardening-sshd.yml
│       ├── set-hostnames.yml
│       └── wsl-conf.yml
├── scripts/
│   └── set-hostname-ubuntu.sh
└── logs/
    ├── approvals/               # Log de decisões HITL
    └── incidents/               # Log de incidentes
```

---

## 10. Importância no contexto AIOps/SRE

No contexto de **AIOps (Artificial Intelligence for Operations)** e **SRE (Site Reliability Engineering)**, o Ansible desempenha papéis críticos:

| Dimensão | Contribuição do Ansible |
|----------|------------------------|
| **Confiabilidade** | Garante que todos os hosts tenham a mesma configuração, reduzindo "configuração drift" |
| **Escalabilidade** | A mesma tarefa se aplica a 5 ou 500 hosts com o mesmo esforço |
| **Recuperação de desastres** | Playbooks versionados permitem recriar ambientes rapidamente |
| **Segurança** | Hardening consistente (sshd, firewall, usuários) em todos os hosts |
| **Observabilidade** | Coleta de facts do Ansible fornece inventário atualizado do estado dos hosts |
| **Resposta a incidentes** | Playbooks pré-aprovados podem ser aplicados rapidamente após incidente validado |

### O loop AIOps com Ansible

```
Observação (linux-triage + observability-collect)
        │
        ▼
Detecção de anomalia (lpic1-audit + métricas)
        │
        ▼
Decisão (gerar playbook via ansible-remediation)
        │
        ▼
Validação (policy-validator + --check --diff + HITL)
        │
        ▼
Execução (ansible-playbook aplicação)
        │
        ▼
Verificação (pós-aplicação + critério de validação)
        │
        └──────────────────────► volta à Observação
```

---

## 11. Checklist de boas práticas

Antes de considerar um playbook pronto para produção:

- [ ] O playbook está em `ansible/playbooks/` com nome descritivo
- [ ] Todas as tarefas são idempotentes (`state: present/absent/started/stopped`)
- [ ] Não há comandos destrutivos (`rm -rf`, `mkfs`, `dd`, `wipefs`, `reboot`)
- [ ] Não há credenciais em texto claro (use Ansible Vault)
- [ ] `ansible-lint` passou sem erros
- [ ] `ansible-playbook --check --diff` executado com sucesso
- [ ] Aprovação via `human-in-the-loop` registrada em `logs/approvals/`
- [ ] Plano de reversão documentado
- [ ] Critério de validação definido no relatório técnico

---

## Referências

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_best_practices.html)
- [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html)
- [Event-Driven Ansible](https://docs.ansible.com/ansible-eda/)
- [Red Hat: AIOps and Ansible Automation Platform](https://redhat.com/en/blog/aiops-and-ansible-automation-platform-where-ai-intelligence-meets-trusted-execution)
