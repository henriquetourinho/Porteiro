#!/bin/bash

# ======================================================================
# PORTEIRO — Desinstalador Oficial v2.0
# Autor: Carlos Henrique Tourinho Santana
# Email: henriquetourinho@riseup.net
# GitHub: https://github.com/henriquetourinho/porteiro
# ======================================================================

# --- Verificação de Root ---
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute como root: sudo bash uninstall.sh"
    exit 1
fi

echo ""
echo "🚪 Porteiro — Desinstalador"
echo "=============================="
echo "⚠️  Isso removerá todos os arquivos do Porteiro do servidor."
echo ""
read -p "   Tem certeza? (s/N): " CONFIRMACAO

if [[ "$CONFIRMACAO" != "s" && "$CONFIRMACAO" != "S" ]]; then
    echo ""
    echo "   Operação cancelada. O Porteiro continua de plantão. 🚪"
    echo ""
    exit 0
fi

echo ""

# --- 1. Fechar o acesso antes de remover ---
echo "🔒 Fechando acesso e limpando IPs do Nginx..."
NGINX_CONF="/etc/nginx/pma_ips.conf"
if [ -f "$NGINX_CONF" ]; then
    echo "" > "$NGINX_CONF"
    systemctl reload nginx 2>/dev/null
    echo "✅ Nginx limpo e recarregado."
else
    echo "   Arquivo $NGINX_CONF não encontrado. Pulando."
fi

# --- 2. Cancelar agendamentos do at ---
echo "⏱️  Cancelando agendamentos do Auto-Off..."
for job in $(atq | awk '{print $1}'); do atrm "$job"; done 2>/dev/null
echo "✅ Agendamentos cancelados."

# --- 3. Remover links simbólicos globais ---
echo "🔗 Removendo comandos globais..."
for CMD in pma-on pma-off pma-status; do
    if [ -L "/usr/local/bin/$CMD" ]; then
        rm -f "/usr/local/bin/$CMD"
        echo "   ✅ Removido: /usr/local/bin/$CMD"
    else
        echo "   ⚠️  Não encontrado: /usr/local/bin/$CMD"
    fi
done

# --- 4. Remover diretório principal ---
echo "📁 Removendo /opt/porteiro/..."
if [ -d "/opt/porteiro" ]; then
    rm -rf "/opt/porteiro"
    echo "✅ Diretório removido."
else
    echo "   ⚠️  Diretório /opt/porteiro não encontrado."
fi

# --- 5. Remover arquivo de IPs do Nginx ---
echo "🗑️  Removendo /etc/nginx/pma_ips.conf..."
if [ -f "$NGINX_CONF" ]; then
    rm -f "$NGINX_CONF"
    echo "✅ Arquivo removido."
else
    echo "   ⚠️  Arquivo não encontrado."
fi

# --- 6. Perguntar sobre o log ---
echo ""
LOG_FILE="/var/log/porteiro.log"
if [ -f "$LOG_FILE" ]; then
    read -p "📋 Deseja remover o log de auditoria ($LOG_FILE)? (s/N): " REMOVE_LOG
    if [[ "$REMOVE_LOG" == "s" || "$REMOVE_LOG" == "S" ]]; then
        rm -f "$LOG_FILE"
        echo "✅ Log removido."
    else
        echo "   Log mantido em: $LOG_FILE"
    fi
fi

# --- 7. Lembrete sobre o bloco do Nginx ---
echo ""
echo "=============================="
echo "✅ Porteiro desinstalado com sucesso!"
echo ""
echo "⚠️  ATENÇÃO: Um passo manual ainda é necessário."
echo "   Remova o bloco do Porteiro da sua configuração do Nginx:"
echo "   Arquivo: /etc/nginx/sites-available/default (ou equivalente)"
echo ""
echo "   Procure e remova o bloco:"
echo ""
echo "   # PORTEIRO — Proteção do phpMyAdmin"
echo "   location ^~ /phpmyadmin/ {"
echo "       include /etc/nginx/pma_ips.conf;"
echo "       deny all;"
echo "       ..."
echo "   }"
echo ""
echo "   Após remover, recarregue o Nginx:"
echo "   sudo nginx -t && sudo systemctl reload nginx"
echo ""
echo "   Até a próxima. 🚪"
echo ""