# Melhores Práticas — IA em Infraestrutura TI, Cloud, DevOps, SRE e SysOps

Este documento estabelece padrões para o uso seguro e eficaz de agentes de IA em operações de infraestrutura, alinhado aos guardrails do `AGENTS.md`.

---

## 1. Princípio de Não-Execução Autônoma

A IA **sugere**, o humano **decide** e **executa** (ou autoriza).

| Ação | Pode a IA executar? | Requer HITL? |
|------|---------------------|--------------|
| Coleta somente-leitura via SSH (`hostnamectl`, `df`, `ss`, `journalctl`) | Sim | Não |
| `ansible -m ping`, `ansible-lint`, `--check --diff` | Sim | Não |
| Aplicar playbook (sem `--check`) | Não | Sim — confirmação explícita |
| Comandos destrutivos (`rm -rf`, `mkfs`, `dd`, `reboot`, etc.) | Não | Sim — bloqueado por policy |
| Alterações persistentes em `/etc` | Não | Sim — confirmação explícita |

---

## 2. Ciclo de Operação com IA (SRE Loop)

Toda intervenção de IA em infraestrutura deve seguir as 5 fases:

```
1. DIAGNOSTICAR      → Coleta de evidências reais via SSH (somente-leitura)
2. HIPOTESIZAR       → IA formula causa raiz baseada em evidências
3. PLANEJAR          → IA gera playbook Ansible idempotente
4. VALIDAR           → ansible-lint + --check --diff + revisão humana
5. APLICAR           → Somente após HITL; registro em MEMORY.md
```

---

## 3. Trail de Decisão da IA (Auditoria)

Toda sugestão da IA deve conter:

- **O quê**: mudança proposta (comando, playbook, parâmetro)
- **Por que**: evidência coletada que justifica a mudança
- **Alternativas consideradas**: outras opções avaliadas e por que foram descartadas
- **Risco**: impacto se algo der errado (baixo / médio / alto)
- **Rollback**: como reverter a mudança se necessário
- **Validação**: como confirmar que a mudança funcionou

Exemplo de registro em `MEMORY.md`:

```
- 2026-11-22 | Auditoria LPIC-1 confirmou hostnames válidos: centos10, amazonlinux-2023, rhel10, ubuntu, agents-lab
  Evidência: hostnamectl reportou nomes corretos em todos os 5 hosts
  Playbook: hostname-correction.yml não necessário (hostnames já válidos)
  Status: descartado — sem ação pendente
  Rollback: não aplicável
```

---

## 4. Validação de Playbooks Gerados por IA

Todo playbook gerado por IA deve passar por três portas antes de ser aplicado:

### Porta 1 — Lint estática
```bash
ansible-lint ansible/playbooks/<playbook>.yml
```

### Porta 2 — Simulação (dry-run)
```bash
ansible-playbook -i ansible/inventory.ini --check --diff \
  --private-key ~/.ssh/id_linux-mcp-server ansible/playbooks/<playbook>.yml
```

### Porta 3 — Revisão humana (HITL)
O operador revisa o diff do `--check --diff`, confirma o impacto e autoriza a aplicação.

---

## 5. Sudo Restrito e Gate de Aprovação (HITL)

### 5.1. Princípio de menor privilégio no sudo

Nos hosts gerenciados, o usuário `ansible-ops` deve ter acesso restrito via `sudo` apenas aos comandos estritamente necessários ao Ansible. Nunca usar `NOPASSWD: ALL`.

**Passo a passo em cada host:**

```bash
# 1. Verifique os caminhos reais dos binários
which hostnamectl cp tee chmod chown

# 2. Edite o sudoers
sudo visudo

# 3. Adicione ao final (ajuste os caminhos conforme o output do which):
ansible-ops ALL=(ALL) /usr/bin/hostnamectl, /usr/bin/cp, /usr/bin/tee, /usr/bin/chmod, /usr/bin/chown
```

**Resultado:** o usuário pode executar apenas esses 6 comandos como root, e **sempre requer senha** (não há `NOPASSWD`). Qualquer outro comando como root será negado.

### 5.2. Gate de aprovação antes de aplicar (HITL)

Nenhum playbook com `become: true` é aplicado sem confirmação explícita do operador. O fluxo obrigatório é:

```bash
# 1. Simulação — mostra o que mudaria, não aplica nada
ansible-playbook -i ansible/inventory.ini --check --diff \
  --private-key ~/.ssh/id_linux-mcp-server ansible/playbooks/<playbook>.yml

# 2. Revisão humana do diff (HITL) — operador confirma ou rejeita

# 3. Aplicação — requer senha do sudo (--ask-become-pass)
ansible-playbook -i ansible/inventory.ini \
  --private-key ~/.ssh/id_linux-mcp-server \
  --ask-become-pass \
  ansible/playbooks/<playbook>.yml
```

**Gate de aprovação:** a etapa 2 é o ponto de parada. Sem confirmação explícita do operador, a etapa 3 não é executada.

### 5.3. DLP — senhas nunca em texto puro

Nunca armazene `ansible_become_pass` ou senhas de sudo em arquivos de inventário, playbooks ou variáveis. Use sempre `--ask-become-pass` no momento da execução.

---


A IA nunca deve:

- Exibir ou gravar chaves privadas (`~/.ssh/id_*`, `*.pem`)
- Exibir ou gravar tokens, senhas, variáveis de ambiente sensíveis (`.env`, secrets)
- Exibir conteúdo de `/etc/shadow` ou arquivos equivalentes de credenciais
- Inserir segredos em playbooks, relatórios ou saídas de comando

Se um playbook precisar de credenciais, use Ansible Vault ou variáveis de ambiente — nunca texto puro.

---

## 6. Contexto e Memória entre Sessões

Arquivos que mantêm o contexto da IA:

| Arquivo | Propósito |
|---------|-----------|
| `AGENTS.md` | Papel, guardrails, formato de relatório |
| `MEMORY.md` | Estado persistente: hosts, pendências, decisões, trail de auditoria |

Antes de iniciar qualquer tarefa, a IA deve ler esses três arquivos para recuperar contexto.

---

## 7. Observabilidade antes de Remediação

Nunca remedia sem diagnóstico. Coletar antes de qualquer ação:

- `hostnamectl` — identidade do host
- `uptime` / `w` — carga e sessões
- `free -h` — memória
- `df -hT` e `df -ih` — disco e inodes
- `systemctl --failed` — serviços com falha
- `journalctl -p err -n 25` — erros recentes
- `ss -tulnp` — portas e serviços escutando

---

## 8. Padrões Específicos por Domínio

### Cloud / WSL2
- Todos os hosts são containers WSL2 compartilhando kernel → ponto único de falha no host físico.
- DNS: `generateResolvConf = false` em `/etc/wsl.conf` para controle determinístico.
- SSH: todas as portas (2220–2260) escutam em `0.0.0.0` (todas as interfaces) — confirmado pela auditoria LPIC-1. Avaliar restrição para `127.0.0.1` se necessário.

### DevOps / Ansible
- Playbooks idempotentes (mudança somente se necessário).
- Validação com `--check --diff` antes de aplicar.
- Inventário centralizado em `ansible/inventory.ini`.
- Sudo restrito: apenas comandos específicos permitidos, aplicação usa `--ask-become-pass` (sem `NOPASSWD: ALL`).

### SRE
- Relatório estruturado: Sintoma → Causa Raiz → Evidências → Ação → Validação.
- Critério de validação definido antes de executar.
- Monitoramento de serviços falhados e erros no journal.

### SysOps
- Correção de hostname via `hostnamectl` + `/etc/hostname` + `/etc/wsl.conf`.
- Reinicialização somente após HITL (reboot é destrutivo).
- Auditoria de hardening com `lpic1-audit`.

---

## 9. Checklist Rápido para IA

Antes de sugerir qualquer mudança:

- [ ] Coletamos evidências reais via SSH?
- [ ] O diagnóstico está baseado em saída de comando, não em achismo?
- [ ] O playbook é idempotente?
- [ ] Passou em `ansible-lint`?
- [ ] Passou em `--check --diff`?
- [ ] Há plano de rollback definido?
- [ ] Não expomos credenciais ou chaves privadas?
- [ ] O usuário deu confirmação explícita (HITL)?
- [ ] Registramos a decisão em `MEMORY.md`?

Se qualquer item for "não", pare e revise antes de prosseguir.