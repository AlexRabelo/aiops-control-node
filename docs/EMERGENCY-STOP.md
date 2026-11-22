# 🛑 Procedimento de Parada de Emergência (Emergency Stop)

## Quando usar
- Quando o agente de IA executa algo inesperado ou perigoso
- Quando há suspeita de loop infinito ou ação repetitiva destrutiva
- Quando um playbook Ansible causa indisponibilidade em um host
- Quando há risco imediato de perda de dados ou serviço

## Passos imediatos

### 1. Parar o agente
Interrompa a sessão atual do agente. No terminal do OpenCode, envie um comando de cancelamento ou encerre a sessão.

### 2. Verificar o último comando executado
Revise o histórico de comandos SSH e os logs em `logs/approvals/` (se existirem) para entender o que foi alterado.

### 3. Avaliar o impacto
| Pergunta | Resposta |
|----------|----------|
| Qual host foi afetado? | |
| Qual arquivo em `/etc` foi alterado? | |
| Um serviço foi reiniciado ou parado? | |
| Há perda de conectividade SSH? | |

### 4. Reverter alterações (se aplicável)

#### Reverter hostname
```bash
ssh <host> 'sudo hostnamectl set-hostname <nome-anterior>'
echo "<nome-anterior>" | sudo tee /etc/hostname
```

#### Reverter /etc/wsl.conf
```bash
ssh <host> 'sudo cp /etc/wsl.conf.bak /etc/wsl.conf'
# ou recriar com conteúdo anterior
```

#### Reverter playbook Ansible
Se um playbook foi aplicado, execute novamente com o estado anterior ou use o módulo `ansible.builtin.lineinfile` / `copy` para restaurar valores conhecidos.

### 5. Restaurar conectividade SSH
Se o host ficou inacessível:
- Verifique se o container WSL2 está rodando: `wsl --list --running` (Windows)
- Reinicie o container: `wsl --distribution <nome>` ou `wsl --shutdown` + iniciar novamente
- Verifique se o `sshd` está rodando dentro do container

### 6. Registrar o incidente
Adicione entrada em `logs/incidents/`:

```
YYYY-MM-DDTHH-MM-SSZ | host=<nome> | ação=<descrição> | impacto=<descrição> | reversão=<sim|não> | operador=<nome>
```

## Contatos de escalonamento
- Operador principal: `labuser`
- Contato secundário: (definir conforme necessidade)

## Lista de verificação pós-incidente
- [ ] Todos os hosts estão acessíveis via SSH?
- [ ] Nenhum arquivo em `/etc` foi deixado em estado inconsistente?
- [ ] Serviços críticos (`sshd`, `systemd`, `chronyd`) estão rodando?
- [ ] Logs de auditoria foram atualizados?
- <|constraint|>constante de aprendizado foi capturado em MEMORY.md?
