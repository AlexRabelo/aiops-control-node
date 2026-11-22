#!/usr/bin/env bash
# =============================================================================
# Script: set-hostname-ubuntu.sh
# Descrição: Altera o hostname do container WSL2 Ubuntu para "ubuntu"
#            e configura /etc/wsl.conf para impedir que o WSL sobrescreva
#            /etc/hostname e /etc/hosts no boot.
#
# Uso: Copie este arquivo para dentro do container Ubuntu (WSL2) e execute:
#      sudo bash set-hostname-ubuntu.sh
#
# Depois de executar, reinicie o WSL do Windows:
#      wsl --shutdown
# =============================================================================

set -euo pipefail

TARGET_HOSTNAME="ubuntu"

echo "============================================================"
echo "  Configurando hostname WSL2 - Ubuntu"
echo "  Destino: ${TARGET_HOSTNAME}"
echo "============================================================"

# 1. Criar /etc/wsl.conf para desabilitar geração automática pelo WSL
echo "[1/4] Gravando /etc/wsl.conf ..."
cat <<EOF | sudo tee /etc/wsl.conf
[network]
generateHosts = false
generateResolvConf = false
EOF
echo "    OK: /etc/wsl.conf criado"
echo ""

# 2. Definir hostname no /etc/hostname
echo "[2/4] Definindo hostname em /etc/hostname ..."
echo "${TARGET_HOSTNAME}" | sudo tee /etc/hostname
echo "    OK: /etc/hostname = ${TARGET_HOSTNAME}"
echo ""

# 3. Aplicar hostname ativo na sessão atual
echo "[3/4] Aplicando hostname ativo ..."
sudo hostnamectl set-hostname "${TARGET_HOSTNAME}"
echo "    OK: hostnamectl definido para ${TARGET_HOSTNAME}"
echo ""

# 4. Atualizar /etc/hosts para mapear 127.0.0.1 ao novo hostname
echo "[4/4] Atualizando /etc/hosts ..."
if grep -q "127.0.0.1.*${TARGET_HOSTNAME}" /etc/hosts 2>/dev/null; then
    sudo sed -i "s/127.0.0.1.*/127.0.0.1 ${TARGET_HOSTNAME}/" /etc/hosts
else
    echo "127.0.0.1 ${TARGET_HOSTNAME}" | sudo tee -a /etc/hosts
fi
echo "    OK: /etc/hosts atualizado"
echo ""

echo "============================================================"
echo "  VALIDAÇÃO"
echo "============================================================"
echo "  /etc/wsl.conf:"
cat /etc/wsl.conf
echo ""
echo "  /etc/hostname:"
cat /etc/hostname
echo ""
echo "  hostnamectl --static:"
hostnamectl --static
echo ""
echo "  hostname:"
hostname
echo ""
echo "  /etc/hosts (primeiras linhas):"
head -5 /etc/hosts
echo ""
echo "============================================================"
echo "  PRÓXIMO PASSO (obrigatório):"
echo "  No Windows (PowerShell), execute:"
echo "      wsl --shutdown"
echo "  Depois inicie o Ubuntu novamente."
echo "============================================================"
