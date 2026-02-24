#!/bin/bash

# ======================================================================
# PORTEIRO — Instalador Oficial v2.0
# Autor: Carlos Henrique Tourinho Santana
# Email: henriquetourinho@riseup.net
# GitHub: https://github.com/henriquetourinho/porteiro
# ======================================================================

# --- Verificação de Root ---
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute como root: sudo bash install.sh"
    exit 1
fi

echo ""
echo "🚪 Porteiro v2.0 — Instalando..."
echo "=============================="

# --- 0. Verificar dependência crítica: nginx ---
NGINX_AUSENTE=0
if ! command -v nginx &> /dev/null; then
    NGINX_AUSENTE=1
    echo ""
    echo "⚠️  Nginx não encontrado neste servidor."
    echo "   O Porteiro depende do Nginx para funcionar."
    echo "   Instale o Nginx antes de continuar:"
    echo ""
    echo "   sudo apt-get install nginx    (Debian/Ubuntu)"
    echo "   sudo dnf install nginx        (Rocky/Alma/CentOS)"
    echo ""
    read -p "   Deseja continuar mesmo assim? (s/N): " CONTINUAR_SEM_NGINX
    if [[ "$CONTINUAR_SEM_NGINX" != "s" && "$CONTINUAR_SEM_NGINX" != "S" ]]; then
        echo "   Instalação cancelada."
        exit 1
    fi
fi

# --- 1. Instalar dependência: at ---
echo "📦 Verificando dependência: at"
if ! command -v at &> /dev/null; then
    if command -v apt-get &> /dev/null; then
        apt-get update -qq && apt-get install at -y -qq
    elif command -v dnf &> /dev/null; then
        dnf install -y at -q
    elif command -v yum &> /dev/null; then
        yum install -y at -q
    else
        echo "❌ Gerenciador de pacotes não reconhecido. Instale o 'at' manualmente e rode novamente."
        exit 1
    fi
    systemctl enable --now atd
    echo "✅ 'at' instalado e ativado."
else
    echo "✅ 'at' já está instalado."
fi

# --- 2. Criar diretório do projeto ---
INSTALL_DIR="/opt/porteiro"
mkdir -p "$INSTALL_DIR"
echo "📁 Diretório criado: $INSTALL_DIR"

# --- 3. Definir caminhos globais ---
CONFIG_FILE="$INSTALL_DIR/porteiro.conf"
NGINX_CONF="/etc/nginx/porteiro_ips.conf"
LOG_FILE="/var/log/porteiro.log"

# ======================================================================
# WIZARD — Rotas protegidas
# ======================================================================
echo ""
echo "🛣️  Rotas Protegidas (Multi-rota)"
echo "=============================="
echo "   O Porteiro bloqueia rotas sensíveis do Nginx para a internet."
echo "   Você pode proteger várias rotas ao mesmo tempo — um único"
echo "   'porteiro-on' libera todas, um 'porteiro-off' bloqueia todas."
echo ""
echo "   ⚠️  Para cada rota escolhida aqui, você precisará adicionar"
echo "   um bloco location no seu Nginx depois (o instalador mostrará"
echo "   o bloco exato ao final)."
echo ""

# Começa sempre com /phpmyadmin/ como padrão
ROTAS="/phpmyadmin/"
echo "   ✅ /phpmyadmin/ — adicionada por padrão."
echo ""
echo "   Deseja proteger mais rotas? Selecione pelos números"
echo "   separados por espaço (ex: 1 3) ou pressione Enter para pular."
echo ""
echo "   [1] /adminer/"
echo "   [2] /wp-admin/"
echo "   [3] /wp-login.php"
echo "   [4] /panel/"
echo "   [5] Digitar manualmente"
echo ""
read -p "   Opções (ex: 1 2): " OPCOES_ROTAS

for OPCAO in $OPCOES_ROTAS; do
    case "$OPCAO" in
        1) NOVA_ROTA="/adminer/" ;;
        2) NOVA_ROTA="/wp-admin/" ;;
        3) NOVA_ROTA="/wp-login.php" ;;
        4) NOVA_ROTA="/panel/" ;;
        5)
            read -p "   Digite a rota (ex: /meupainel/): " NOVA_ROTA
            # Garante barra inicial
            [[ "$NOVA_ROTA" != /* ]] && NOVA_ROTA="/$NOVA_ROTA"
            # Garante barra final se não terminar com extensão de arquivo
            [[ "$NOVA_ROTA" != *"."* && "$NOVA_ROTA" != */ ]] && NOVA_ROTA="$NOVA_ROTA/"
            ;;
        *)
            echo "   ⚠️  Opção '$OPCAO' inválida. Ignorada."
            continue
            ;;
    esac

    if echo "$ROTAS" | grep -Fq "$NOVA_ROTA"; then
        echo "   ⚠️  '$NOVA_ROTA' já está na lista."
    else
        ROTAS=$(echo "$ROTAS $NOVA_ROTA" | xargs)
        echo "   ✅ '$NOVA_ROTA' adicionada."
    fi
done

echo ""
echo "   Rotas que serão protegidas:"
for ROTA in $ROTAS; do
    echo "   → $ROTA"
done
echo ""

# ======================================================================
# WIZARD — Telegram
# ======================================================================
echo "📣 Notificações via Telegram (opcional)"
echo "=============================="

# Verifica se curl está disponível (necessário para Telegram)
if ! command -v curl &> /dev/null; then
    echo "   ⚠️  curl não encontrado. Notificações Telegram não funcionarão."
    echo "   Instale com: sudo apt-get install curl"
    echo ""
fi
echo "   Receba um aviso no celular sempre que porteiro-on, porteiro-off"
echo "   ou porteiro-status for executado."
echo ""
read -p "   Deseja configurar o Telegram agora? (s/N): " QUER_TELEGRAM

TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""

if [[ "$QUER_TELEGRAM" == "s" || "$QUER_TELEGRAM" == "S" ]]; then
    echo ""
    echo "   Como obter as credenciais:"
    echo "   → TOKEN   : Fale com @BotFather no Telegram e crie um bot"
    echo "   → CHAT_ID : Fale com @userinfobot no Telegram para saber seu ID"
    echo ""
    read -p "   Token do bot: " TELEGRAM_TOKEN
    read -p "   Chat ID:      " TELEGRAM_CHAT_ID

    if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        echo ""
        echo "   🔔 Testando conexão com o Telegram..."
        TESTE=$(curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getMe")
        if echo "$TESTE" | grep -q '"ok":true'; then
            echo "   ✅ Bot validado! Notificações ativadas."
        else
            echo "   ⚠️  Não foi possível validar o token. Verifique e edite depois em:"
            echo "   $CONFIG_FILE"
        fi
    else
        echo "   ⚠️  Credenciais em branco. Telegram desativado."
        TELEGRAM_TOKEN=""
        TELEGRAM_CHAT_ID=""
    fi
else
    echo "   Telegram desativado. Você pode ativar depois em:"
    echo "   $CONFIG_FILE"
fi

echo ""

# ======================================================================
# CRIAÇÃO DOS ARQUIVOS
# ======================================================================

# --- 5. Criar arquivo de configuração ---
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOF
# ======================================================================
# PORTEIRO — Arquivo de Configuração
# ======================================================================

# Tempo padrão de acesso em minutos (usado quando nenhum argumento é passado)
DEFAULT_TIME=60

# ── Multi-rota ─────────────────────────────────────────────────────────
# Rotas protegidas pelo Porteiro (separadas por espaço).
# O porteiro-on libera o seu IP em TODAS as rotas listadas de uma vez.
# Para cada rota, adicione um bloco location no seu Nginx com:
#   include /etc/nginx/porteiro_ips.conf;
#   deny all;
#
# Exemplos:
#   ROTAS="/phpmyadmin/"
#   ROTAS="/phpmyadmin/ /adminer/ /wp-admin/"
#
ROTAS="${ROTAS}"

# ── Notificação via Telegram (opcional) ────────────────────────────────
# Deixe em branco para desativar.
# Para ativar: informe o token do seu bot e o seu chat ID.
#
# Como obter:
#   TOKEN     → Fale com @BotFather no Telegram e crie um bot
#   CHAT_ID   → Fale com @userinfobot no Telegram para descobrir seu ID
#
TELEGRAM_TOKEN="${TELEGRAM_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"
EOF
    echo "✅ Configuração criada: $CONFIG_FILE"
else
    echo "✅ Configuração já existe: $CONFIG_FILE (mantida — suas credenciais foram preservadas)"
fi

# --- 6. Criar arquivo de IPs do Nginx ---
if [ ! -f "$NGINX_CONF" ]; then
    touch "$NGINX_CONF"
    chmod 640 "$NGINX_CONF"
    chown root:root "$NGINX_CONF"
    echo "✅ Arquivo criado: $NGINX_CONF"
else
    echo "✅ Arquivo já existe: $NGINX_CONF"
fi

# --- 7. Criar arquivo de log ---
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
    chown root:root "$LOG_FILE"
    echo "✅ Log criado: $LOG_FILE"
else
    echo "✅ Log já existe: $LOG_FILE"
fi

# --- 7b. Configurar logrotate ---
cat > /etc/logrotate.d/porteiro << 'LOGROTATE'
/var/log/porteiro.log {
    monthly
    rotate 6
    compress
    missingok
    notifempty
    create 640 root root
}
LOGROTATE
echo "✅ Logrotate configurado: /etc/logrotate.d/porteiro"

# --- 8. Criar o script porteiro-on ---
cat << 'EOF' > "$INSTALL_DIR/porteiro-on"
#!/bin/bash
set -euo pipefail

# ======================================================================
# porteiro-on — Libera o seu IP em todas as rotas protegidas
# Uso: porteiro-on [tempo]
#   Exemplos: porteiro-on        (usa o tempo padrão definido em porteiro.conf)
#             porteiro-on 30m    (libera por 30 minutos)
#             porteiro-on 2h     (libera por 2 horas)
#
# Multi-rota: o IP é injetado em /etc/nginx/porteiro_ips.conf — arquivo
# compartilhado por todas as rotas configuradas no Nginx com
# "include /etc/nginx/porteiro_ips.conf". Basta adicionar o include em
# cada bloco location que quiser proteger.
# ======================================================================

CONFIG_FILE="/opt/porteiro/porteiro.conf"
NGINX_CONF="/etc/nginx/porteiro_ips.conf"
LOG_FILE="/var/log/porteiro.log"

source "$CONFIG_FILE"

# --- Detecta o IP da sessão SSH ---
MEU_IP="${SSH_CLIENT:-}"
MEU_IP="${MEU_IP%% *}"

# Fallback: tmux, screen, sudo su, jump hosts
if [ -z "$MEU_IP" ]; then
    MEU_IP=$(who am i 2>/dev/null | awk '{print $5}' | tr -d '()')
fi

if [ -z "$MEU_IP" ]; then
    echo ""
    echo "❌ Erro: IP da sessão SSH não detectado."
    echo ""
    echo "   Este comando deve ser executado dentro de uma sessão SSH remota."
    echo "   Exemplo: conecte ao servidor com 'ssh usuario@ip-do-servidor'"
    echo "   e então rode 'sudo porteiro-on'."
    echo ""
    echo "   Se você está no servidor local (sem SSH), defina o IP manualmente:"
    echo "   sudo SSH_CLIENT='SEU_IP 0 0' porteiro-on"
    echo ""
    exit 1
fi

# --- Processa o argumento de tempo ---
TEMPO_ARG="${1:-}"
TEMPO_MINUTOS="$DEFAULT_TIME"
TEMPO_LABEL="${DEFAULT_TIME} minuto(s)"

if [ -n "$TEMPO_ARG" ]; then
    # Valida formato: número puro (minutos), ou número + sufixo m/h
    if [[ ! "$TEMPO_ARG" =~ ^[0-9]+(m|min|minutos|h|hora|horas)?$ ]]; then
        echo "❌ Formato de tempo inválido: '$TEMPO_ARG'"
        echo "   Use: porteiro-on 30     (30 minutos)"
        echo "        porteiro-on 30m    (30 minutos)"
        echo "        porteiro-on 2h     (2 horas)"
        exit 1
    fi

    NUMERO=$(echo "$TEMPO_ARG" | grep -o '^[0-9]\+')
    UNIDADE=$(echo "$TEMPO_ARG" | grep -o '[a-zA-Z]*$')

    case "$UNIDADE" in
        m|min|minutos|"")
            TEMPO_MINUTOS="$NUMERO"
            TEMPO_LABEL="${NUMERO} minuto(s)"
            ;;
        h|hora|horas)
            TEMPO_MINUTOS=$((NUMERO * 60))
            TEMPO_LABEL="${NUMERO} hora(s)"
            ;;
    esac
fi

# --- Injeta o IP no arquivo compartilhado do Nginx (multi-IP) ---
# Adiciona o IP apenas se ainda não estiver na lista
grep -q "^allow $MEU_IP;" "$NGINX_CONF" 2>/dev/null || \
    flock "$NGINX_CONF" -c "echo 'allow $MEU_IP;' >> '$NGINX_CONF'"

# --- Valida a config do Nginx antes de recarregar ---
if nginx -t 2>/dev/null; then
    systemctl reload nginx
else
    echo "❌ Erro na configuração do Nginx. Acesso NÃO foi liberado."
    echo "   Verifique: sudo nginx -t"
    exit 1
fi

# --- Cancela job anterior deste IP específico (inspeciona tag real) ---
atq 2>/dev/null | while read -r JOB; do
    ID=$(echo "$JOB" | awk '{print $1}')
    if at -c "$ID" 2>/dev/null | grep -q "#porteiro-$MEU_IP"; then
        atrm "$ID" 2>/dev/null
    fi
done
echo "/usr/local/bin/porteiro-revoke $MEU_IP > /dev/null 2>&1 #porteiro-$MEU_IP" | at now + ${TEMPO_MINUTOS} minutes 2>/dev/null

# --- Registra no log ---
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
ROTAS_LOG=$(echo "$ROTAS" | tr ' ' ',')
echo "[$TIMESTAMP] ABERTO  | IP: $MEU_IP | Duração: $TEMPO_LABEL | Rotas: $ROTAS_LOG | Host: $HOSTNAME" >> "$LOG_FILE"

# --- Notificação Telegram (opcional) ---
if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    # Escapa caracteres especiais para MarkdownV2 (sed encadeado — mais portátil)
    escape_md2() {
        echo "$1" | sed \
            -e 's/\\/\\\\/g' \
            -e 's/\./\\./g'  \
            -e 's/-/\\-/g'   \
            -e 's/(/\\(/g'   \
            -e 's/)/\\)/g'   \
            -e 's/!/\\!/g'   \
            -e 's/|/\\|/g'   \
            -e 's/{/\\{/g'   \
            -e 's/}/\\}/g'   \
            -e 's/+/\\+/g'   \
            -e 's/=/\\=/g'   \
            -e 's/~/\\~/g'   \
            -e 's/>/\\>/g'   \
            -e 's/#/\\#/g'   \
            -e 's/_/\\_/g'
    }
    HOSTNAME_ESC=$(escape_md2 "$HOSTNAME")
    MEU_IP_ESC=$(escape_md2 "$MEU_IP")
    TEMPO_LABEL_ESC=$(escape_md2 "$TEMPO_LABEL")
    TIMESTAMP_ESC=$(escape_md2 "$TIMESTAMP")
    ROTAS_MSG=$(echo "$ROTAS" | tr ' ' '\n' | sed 's/^/  •  /' | while read -r l; do escape_md2 "$l"; done | tr '\n' '%0A')
    MENSAGEM="🚪 *Porteiro — Acesso Liberado*%0A%0A🖥 Host: ${HOSTNAME_ESC}%0A🌍 IP autorizado: \`${MEU_IP_ESC}\`%0A🛣 Rotas:%0A${ROTAS_MSG}%0A⏱ Duração: ${TEMPO_LABEL_ESC}%0A🕐 Horário: ${TIMESTAMP_ESC}"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${MENSAGEM}" \
        -d "parse_mode=MarkdownV2" > /dev/null 2>&1
fi

# --- Saída ---
echo ""
echo "✅ Acesso liberado!"
echo "   IP autorizado : $MEU_IP"
echo "   Duração       : $TEMPO_LABEL"
echo "   Auto-Off em   : ${TEMPO_MINUTOS} minuto(s)"
echo "   Rotas ativas  : $ROTAS"
echo ""
EOF

# --- 9. Criar o script porteiro-off ---
cat << 'EOF' > "$INSTALL_DIR/porteiro-off"
#!/bin/bash
set -euo pipefail

# ======================================================================
# porteiro-off — Revoga o acesso e bloqueia todas as rotas protegidas
# Nota: fecha todos os IPs de uma vez.
# Para revogar apenas o seu IP, use: sudo porteiro-revoke <IP>
# ======================================================================

CONFIG_FILE="/opt/porteiro/porteiro.conf"
NGINX_CONF="/etc/nginx/porteiro_ips.conf"
LOG_FILE="/var/log/porteiro.log"

source "$CONFIG_FILE"

# --- Limpa o arquivo de IPs compartilhado ---
: > "$NGINX_CONF"

# --- Valida config do Nginx antes de recarregar ---
if nginx -t 2>/dev/null; then
    systemctl reload nginx
else
    echo "❌ Erro na configuração do Nginx. Verifique: sudo nginx -t"
    exit 1
fi

# --- Cancela apenas jobs realmente criados pelo Porteiro ---
atq 2>/dev/null | while read -r JOB; do
    ID=$(echo "$JOB" | awk '{print $1}')
    if at -c "$ID" 2>/dev/null | grep -q "#porteiro-"; then
        atrm "$ID" 2>/dev/null
    fi
done

# --- Registra no log ---
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
ROTAS_LOG=$(echo "$ROTAS" | tr ' ' ',')
echo "[$TIMESTAMP] FECHADO | Rotas: $ROTAS_LOG | Host: $HOSTNAME" >> "$LOG_FILE"

# --- Notificação Telegram (opcional) ---
if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    escape_md2() {
        echo "$1" | sed \
            -e 's/\\/\\\\/g' \
            -e 's/\./\\./g'  \
            -e 's/-/\\-/g'   \
            -e 's/(/\\(/g'   \
            -e 's/)/\\)/g'   \
            -e 's/!/\\!/g'   \
            -e 's/|/\\|/g'   \
            -e 's/{/\\{/g'   \
            -e 's/}/\\}/g'   \
            -e 's/+/\\+/g'   \
            -e 's/=/\\=/g'   \
            -e 's/~/\\~/g'   \
            -e 's/>/\\>/g'   \
            -e 's/#/\\#/g'   \
            -e 's/_/\\_/g'
    }
    HOSTNAME_ESC=$(escape_md2 "$HOSTNAME")
    TIMESTAMP_ESC=$(escape_md2 "$TIMESTAMP")
    ROTAS_MSG=$(echo "$ROTAS" | tr ' ' '\n' | sed 's/^/  •  /' | while read -r l; do escape_md2 "$l"; done | tr '\n' '%0A')
    MENSAGEM="🔒 *Porteiro — Acesso Bloqueado*%0A%0A🖥 Host: ${HOSTNAME_ESC}%0A🛣 Rotas:%0A${ROTAS_MSG}%0A🕐 Horário: ${TIMESTAMP_ESC}"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${MENSAGEM}" \
        -d "parse_mode=MarkdownV2" > /dev/null 2>&1
fi

# --- Saída ---
echo ""
echo "🔒 Acesso bloqueado!"
echo "   Rotas isoladas: $ROTAS"
echo ""
EOF

# --- 10. Criar o script porteiro-status ---
cat << 'EOF' > "$INSTALL_DIR/porteiro-status"
#!/bin/bash
set -euo pipefail

# ======================================================================
# porteiro-status — Mostra o estado atual do Porteiro
# ======================================================================

CONFIG_FILE="/opt/porteiro/porteiro.conf"
NGINX_CONF="/etc/nginx/porteiro_ips.conf"
LOG_FILE="/var/log/porteiro.log"

source "$CONFIG_FILE"

echo ""
echo "🚪 Porteiro — Status"
echo "========================"

# --- Verifica se há IPs autorizados ---
IP_ATUAL=$(awk '/allow/ {gsub("allow |;",""); print}' "$NGINX_CONF" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

if [ -n "$IP_ATUAL" ]; then
    echo "   Estado  : 🟢 ABERTO"
    echo "   IPs ativos:"
    awk '/allow/ {gsub("allow |;",""); print "             → " $0}' "$NGINX_CONF" 2>/dev/null
    echo "   Rotas   : $ROTAS"

    # Mostra jobs do porteiro por IP (inspeciona tag real via at -c, sem subshell)
    PRINTED_HEADER=0
    while read -r JOB; do
        ID=$(echo "$JOB" | awk '{print $1}')
        HORA=$(echo "$JOB" | awk '{print $3, $4}')
        TAG=$(at -c "$ID" 2>/dev/null | grep "#porteiro-" | awk -F'#porteiro-' '{print $2}' | awk '{print $1}')
        if [ -n "$TAG" ]; then
            [ "$PRINTED_HEADER" -eq 0 ] && echo "   Auto-Off :" && PRINTED_HEADER=1
            echo "             → $TAG às $HORA"
        fi
    done < <(atq 2>/dev/null)
else
    echo "   Estado  : 🔴 FECHADO"
    echo "   Rotas   : $ROTAS"
    echo "   Nenhum IP autorizado no momento."
fi

echo ""
echo "📋 Últimas 10 entradas do log:"
echo "------------------------"
if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
    tail -10 "$LOG_FILE"
else
    echo "   Log vazio."
fi
echo ""

# --- Notificação Telegram (opcional) ---
if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    HOSTNAME=$(hostname)
    escape_md2() {
        echo "$1" | sed \
            -e 's/\\/\\\\/g' \
            -e 's/\./\\./g'  \
            -e 's/-/\\-/g'   \
            -e 's/(/\\(/g'   \
            -e 's/)/\\)/g'   \
            -e 's/!/\\!/g'   \
            -e 's/|/\\|/g'   \
            -e 's/{/\\{/g'   \
            -e 's/}/\\}/g'   \
            -e 's/+/\\+/g'   \
            -e 's/=/\\=/g'   \
            -e 's/~/\\~/g'   \
            -e 's/>/\\>/g'   \
            -e 's/#/\\#/g'   \
            -e 's/_/\\_/g'
    }
    HOSTNAME_ESC=$(escape_md2 "$HOSTNAME")
    TIMESTAMP_ESC=$(escape_md2 "$TIMESTAMP")
    if [ -n "$IP_ATUAL" ]; then
        IPS_ESC=$(echo "$IP_ATUAL" | tr ',' '\n' | while read -r l; do escape_md2 "$l"; done | sed 's/^/`/' | sed 's/$/`/' | tr '\n' ' ')
        ESTADO="🟢 ABERTO | IPs: ${IPS_ESC}"
    else
        ESTADO="🔴 FECHADO"
    fi
    ROTAS_MSG=$(echo "$ROTAS" | tr ' ' '\n' | sed 's/^/  •  /' | while read -r l; do escape_md2 "$l"; done | tr '\n' '%0A')
    MENSAGEM="📊 *Porteiro — Status*%0A%0A🖥 Host: ${HOSTNAME_ESC}%0A🔑 Estado: ${ESTADO}%0A🛣 Rotas:%0A${ROTAS_MSG}%0A🕐 Horário: ${TIMESTAMP_ESC}"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${MENSAGEM}" \
        -d "parse_mode=MarkdownV2" > /dev/null 2>&1
fi
EOF

# --- 11. Criar o script porteiro-list ---
cat << 'EOF' > "$INSTALL_DIR/porteiro-list"
#!/bin/bash
set -euo pipefail

# ======================================================================
# porteiro-list — Lista todos os IPs ativos e rotas protegidas
# ======================================================================

CONFIG_FILE="/opt/porteiro/porteiro.conf"
NGINX_CONF="/etc/nginx/porteiro_ips.conf"
LOG_FILE="/var/log/porteiro.log"

source "$CONFIG_FILE"

echo ""
echo "🚪 Porteiro — IPs Ativos"
echo "=============================="

if [ ! -s "$NGINX_CONF" ]; then
    echo "   🔴 Nenhum IP autorizado no momento."
    echo "   Rotas protegidas: $ROTAS"
    echo ""
    exit 0
fi

echo "   🟢 IPs atualmente autorizados:"
echo ""

IPS=$(awk '/allow/ {gsub("allow |;",""); print}' "$NGINX_CONF")

for IP in $IPS; do
    ULTIMO=$(grep "ABERTO" "$LOG_FILE" 2>/dev/null | grep -F "IP: $IP " | tail -1)
    if [ -n "$ULTIMO" ]; then
        DATA=$(echo "$ULTIMO" | awk '{print $1, $2}' | tr -d '[]')
        echo "   → $IP  (aberto em $DATA)"
    else
        echo "   → $IP"
    fi
done

echo ""
echo "   Rotas protegidas:"
for ROTA in $ROTAS; do
    echo "   • $ROTA"
done
echo ""
EOF

# --- 12. Criar o script porteiro-revoke ---
cat << 'EOF' > "$INSTALL_DIR/porteiro-revoke"
#!/bin/bash
set -euo pipefail

# ======================================================================
# porteiro-revoke — Revoga o acesso de um IP específico
# Uso: sudo porteiro-revoke <IP>
# Exemplo: sudo porteiro-revoke 189.x.x.x
# ======================================================================

CONFIG_FILE="/opt/porteiro/porteiro.conf"
NGINX_CONF="/etc/nginx/porteiro_ips.conf"
LOG_FILE="/var/log/porteiro.log"

source "$CONFIG_FILE"

IP_ALVO="$1"

if [ -z "$IP_ALVO" ]; then
    echo ""
    echo "❌ IP não informado."
    echo "   Uso: sudo porteiro-revoke <IP>"
    echo "   Exemplo: sudo porteiro-revoke 189.x.x.x"
    echo ""
    echo "   IPs ativos no momento:"
    awk '/allow/ {gsub("allow |;",""); print "   → " $0}' "$NGINX_CONF" 2>/dev/null || echo "   Nenhum."
    echo ""
    exit 1
fi

# --- Fix: Valida formato E faixa do IP antes de qualquer operação ---
if ! [[ "$IP_ALVO" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || \
   ! awk -F. '$1<=255 && $2<=255 && $3<=255 && $4<=255' <<< "$IP_ALVO" > /dev/null 2>&1; then
    echo ""
    echo "❌ IP inválido: $IP_ALVO"
    echo "   Use um IPv4 válido. Exemplo: 189.10.20.30"
    echo ""
    exit 1
fi

if ! grep -q "^allow $IP_ALVO;" "$NGINX_CONF" 2>/dev/null; then
    echo ""
    echo "⚠️  IP não encontrado na lista de autorizados: $IP_ALVO"
    echo ""
    echo "   IPs ativos no momento:"
    awk '/allow/ {gsub("allow |;",""); print "   → " $0}' "$NGINX_CONF" 2>/dev/null || echo "   Nenhum."
    echo ""
    exit 1
fi

# Remove apenas a linha do IP alvo (IP já validado como IPv4)
IP_ESCAPED=$(echo "$IP_ALVO" | sed 's/\./\\./g')
sed -i "/allow $IP_ESCAPED;/d" "$NGINX_CONF"

# Valida nginx antes de recarregar
if nginx -t 2>/dev/null; then
    systemctl reload nginx
else
    echo "❌ Erro na configuração do Nginx. Revogação abortada."
    exit 1
fi

# Registra no log
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
ROTAS_LOG=$(echo "$ROTAS" | tr ' ' ',')
echo "[$TIMESTAMP] REVOGADO | IP: $IP_ALVO | Rotas: $ROTAS_LOG | Host: $HOSTNAME" >> "$LOG_FILE"

# Notificação Telegram (opcional)
if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    escape_md2() {
        echo "$1" | sed \
            -e 's/\\/\\\\/g' \
            -e 's/\./\\./g'  \
            -e 's/-/\\-/g'   \
            -e 's/(/\\(/g'   \
            -e 's/)/\\)/g'   \
            -e 's/!/\\!/g'   \
            -e 's/|/\\|/g'   \
            -e 's/{/\\{/g'   \
            -e 's/}/\\}/g'   \
            -e 's/+/\\+/g'   \
            -e 's/=/\\=/g'   \
            -e 's/~/\\~/g'   \
            -e 's/>/\\>/g'   \
            -e 's/#/\\#/g'   \
            -e 's/_/\\_/g'
    }
    HOSTNAME_ESC=$(escape_md2 "$HOSTNAME")
    IP_ALVO_ESC=$(escape_md2 "$IP_ALVO")
    TIMESTAMP_ESC=$(escape_md2 "$TIMESTAMP")
    ROTAS_MSG=$(echo "$ROTAS" | tr ' ' '\n' | sed 's/^/  •  /' | while read -r l; do escape_md2 "$l"; done | tr '\n' '%0A')
    MENSAGEM="🔒 *Porteiro — IP Revogado*%0A%0A🖥 Host: ${HOSTNAME_ESC}%0A🚫 IP removido: \`${IP_ALVO_ESC}\`%0A🛣 Rotas:%0A${ROTAS_MSG}%0A🕐 Horário: ${TIMESTAMP_ESC}"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${MENSAGEM}" \
        -d "parse_mode=MarkdownV2" > /dev/null 2>&1
fi

echo ""
echo "🔒 Acesso revogado: $IP_ALVO"
echo ""
EOF

# --- 13. Permissões corretas ---
chmod 755 "$INSTALL_DIR/porteiro-on"
chmod 755 "$INSTALL_DIR/porteiro-off"
chmod 755 "$INSTALL_DIR/porteiro-status"
chmod 755 "$INSTALL_DIR/porteiro-list"
chmod 755 "$INSTALL_DIR/porteiro-revoke"
chmod 640 "$CONFIG_FILE"
chown root:root "$INSTALL_DIR/porteiro-on"
chown root:root "$INSTALL_DIR/porteiro-off"
chown root:root "$INSTALL_DIR/porteiro-status"
chown root:root "$INSTALL_DIR/porteiro-list"
chown root:root "$INSTALL_DIR/porteiro-revoke"
chown root:root "$CONFIG_FILE"

echo "🔐 Permissões aplicadas (755, root:root)"

# --- 14. Criar links simbólicos globais ---
ln -sf "$INSTALL_DIR/porteiro-on"     /usr/local/bin/porteiro-on
ln -sf "$INSTALL_DIR/porteiro-off"    /usr/local/bin/porteiro-off
ln -sf "$INSTALL_DIR/porteiro-status" /usr/local/bin/porteiro-status
ln -sf "$INSTALL_DIR/porteiro-list"   /usr/local/bin/porteiro-list
ln -sf "$INSTALL_DIR/porteiro-revoke" /usr/local/bin/porteiro-revoke

echo "🔗 Comandos globais registrados: porteiro-on | porteiro-off | porteiro-status | porteiro-list | porteiro-revoke"

# ======================================================================
# INSTRUÇÃO FINAL — Blocos Nginx para cada rota configurada
# ======================================================================
echo ""
echo "=============================="
echo "🚪 Porteiro v2.0 instalado com sucesso!"
echo ""
echo "⚙️  Configuração salva em: /opt/porteiro/porteiro.conf"
echo ""
echo "⚠️  PASSO FINAL (manual): Adicione os blocos abaixo no seu Nginx."
echo "   Arquivo sugerido: /etc/nginx/sites-available/default"
echo ""
echo "----------------------------------------------------------------------"

for ROTA in $ROTAS; do
    # Remove barras para criar nome limpo do comentário
    NOME=$(echo "$ROTA" | tr -d '/' | tr '[:lower:]' '[:upper:]')
    echo ""
    echo "    # --- $NOME ---"
    echo "    location ^~ $ROTA {"
    echo "        include /etc/nginx/porteiro_ips.conf;"
    echo "        deny all;"
    echo ""
    echo "        location ~ \\.php\$ {"
    echo "            include snippets/fastcgi-php.conf;"
    echo "            # Ajuste o socket conforme sua versão do PHP:"
    echo "            # fastcgi_pass unix:/run/php/php8.1-fpm.sock;"
    echo "            # fastcgi_pass unix:/run/php/php8.2-fpm.sock;"
    echo "            # fastcgi_pass unix:/run/php/php8.3-fpm.sock;"
    echo "            fastcgi_pass unix:/run/php/php-fpm.sock;"
    echo "        }"
    echo "    }"
done

echo ""
echo "----------------------------------------------------------------------"
echo ""
echo "   💡 Todas as rotas acima compartilham o mesmo arquivo de IPs."
echo "   Um único 'porteiro-on' libera tudo. Um 'porteiro-off' bloqueia tudo."
echo ""
echo "   Após editar o Nginx, rode:"
echo "   sudo nginx -t && sudo systemctl reload nginx"
echo ""
echo "   Comandos disponíveis:"
echo "   sudo porteiro-on [tempo]       → Libera seu IP em todas as rotas (ex: sudo porteiro-on 30m)"
echo "   sudo porteiro-off              → Bloqueia todas as rotas imediatamente"
echo "   sudo porteiro-status           → Mostra estado atual, rotas e log recente"
echo "   sudo porteiro-list             → Lista todos os IPs ativos com data de abertura"
echo "   sudo porteiro-revoke <IP>      → Revoga acesso de um IP específico"
echo ""
echo "   ⚠️  Use sempre 'sudo' — os comandos precisam de root para recarregar o Nginx."
echo ""

# --- Aviso final se nginx não foi encontrado durante a instalação ---
if [ "$NGINX_AUSENTE" -eq 1 ]; then
    echo "=============================="
    echo "🚨 ATENÇÃO: Nginx não detectado."
    echo "   O Porteiro foi instalado, mas NÃO funcionará até que o Nginx esteja"
    echo "   instalado e configurado com os blocos location corretos."
    echo ""
    echo "   Instale o Nginx e rode 'sudo nginx -t' antes de usar qualquer comando."
    echo "=============================="
    echo ""
fi