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

# --- Carrega configuração para ler as rotas ---
CONFIG_FILE="/opt/porteiro/porteiro.conf"
ROTAS="/phpmyadmin/"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE" 2>/dev/null
fi

# --- 1. Fechar o acesso antes de remover ---
echo "🔒 Fechando acesso e limpando IPs do Nginx..."
NGINX_CONF="/etc/nginx/porteiro_ips.conf"
if [ -f "$NGINX_CONF" ]; then
    echo "" > "$NGINX_CONF"
    if nginx -t 2>/dev/null; then
        systemctl reload nginx 2>/dev/null
        echo "✅ Nginx limpo e recarregado."
    else
        echo "   ⚠️  nginx -t falhou. Recarregue manualmente após corrigir a config."
    fi
else
    echo "   Arquivo $NGINX_CONF não encontrado. Pulando."
fi

# --- 2. Cancelar agendamentos do Auto-Off ---
echo "⏱️  Cancelando agendamentos do Auto-Off..."
atq 2>/dev/null | grep -i "porteiro" | awk '{print $1}' | xargs -r atrm 2>/dev/null
echo "✅ Agendamentos cancelados."

# --- 3. Remover links simbólicos globais ---
echo "🔗 Removendo comandos globais..."
for CMD in porteiro-on porteiro-off porteiro-status porteiro-list porteiro-revoke; do
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

# --- 4b. Remover logrotate ---
if [ -f "/etc/logrotate.d/porteiro" ]; then
    rm -f "/etc/logrotate.d/porteiro"
    echo "✅ Logrotate removido."
fi

# --- 5. Remover arquivo de IPs do Nginx ---
echo "🗑️  Removendo /etc/nginx/porteiro_ips.conf..."
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

# --- 7. Wizard de limpeza do Nginx ---
echo ""
echo "=============================="
echo "✅ Porteiro desinstalado com sucesso!"
echo ""
echo "🧹 Limpeza do Nginx"
echo "-------------------------------"
echo "   As seguintes rotas estavam protegidas pelo Porteiro:"
echo ""

NGINX_FILE="/etc/nginx/sites-available/default"
ROTAS_ARRAY=($ROTAS)

for ROTA in "${ROTAS_ARRAY[@]}"; do
    echo "   → $ROTA"
done

echo ""
read -p "   Deseja abrir o arquivo do Nginx agora para remover os blocos? (s/N): " ABRIR_NGINX

if [[ "$ABRIR_NGINX" == "s" || "$ABRIR_NGINX" == "S" ]]; then
    echo ""
    echo "   Para cada rota acima, remova o bloco correspondente:"
    echo ""
    for ROTA in "${ROTAS_ARRAY[@]}"; do
        echo "   location ^~ $ROTA {"
        echo "       include /etc/nginx/porteiro_ips.conf;  ← remova"
        echo "       deny all;                               ← remova"
        echo "       ..."
        echo "   }"
        echo ""
    done

    read -p "   Informe o caminho do arquivo Nginx [$NGINX_FILE]: " NGINX_INPUT
    NGINX_FILE="${NGINX_INPUT:-$NGINX_FILE}"

    if [ -f "$NGINX_FILE" ]; then
        nano "$NGINX_FILE"
        echo ""
        echo "   Validando e recarregando o Nginx..."
        if nginx -t 2>/dev/null; then
            systemctl reload nginx
            echo "   ✅ Nginx recarregado com sucesso."
        else
            echo "   ❌ Erro na configuração do Nginx. Verifique o arquivo manualmente."
        fi
    else
        echo "   ⚠️  Arquivo não encontrado: $NGINX_FILE"
        echo "   Edite manualmente e rode: sudo nginx -t && sudo systemctl reload nginx"
    fi
else
    echo ""
    echo "   Lembre-se de remover os blocos manualmente:"
    echo "   sudo nano $NGINX_FILE"
    echo ""
    for ROTA in "${ROTAS_ARRAY[@]}"; do
        echo "   location ^~ $ROTA {"
        echo "       include /etc/nginx/porteiro_ips.conf;  ← remova"
        echo "       deny all;                               ← remova"
        echo "   }"
        echo ""
    done
    echo "   Após editar, rode:"
    echo "   sudo nginx -t && sudo systemctl reload nginx"
fi

echo ""
echo "   Até a próxima. 🚪"
echo ""