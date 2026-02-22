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

# --- 1. Instalar dependência: at ---
echo "📦 Verificando dependência: at"
if ! command -v at &> /dev/null; then
    apt-get update -qq && apt-get install at -y -qq
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
NGINX_CONF="/etc/nginx/pma_ips.conf"
LOG_FILE="/var/log/porteiro.log"

# --- 4. Wizard interativo do Telegram ---
echo ""
echo "📣 Notificações via Telegram (opcional)"
echo "   Receba um aviso no celular sempre que pma-on ou pma-off for executado."
echo ""
read -p "   Deseja configurar o Telegram agora? (s/N): " QUER_TELEGRAM

TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""

if [[ "$QUER_TELEGRAM" == "s" || "$QUER_TELEGRAM" == "S" ]]; then
    echo ""
    echo "   Como obter as credenciais:"
    echo "   → TOKEN   : Fale com @BotFather no Telegram e crie um bot"
    echo "   → CHAT_ID : Fale com @userinfobot no Telegram para descobrir seu ID"
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

# --- 5. Criar arquivo de configuração ---
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOF
# ======================================================================
# PORTEIRO — Arquivo de Configuração
# ======================================================================

# Tempo padrão de acesso em minutos (usado quando nenhum argumento é passado)
DEFAULT_TIME=60

# Rotas protegidas pelo Porteiro (separadas por espaço)
# Exemplo: ROTAS="/phpmyadmin/ /adminer/ /wp-admin/"
ROTAS="/phpmyadmin/"

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
    echo "✅ Configuração já existe: $CONFIG_FILE (mantida)"
fi

# --- 6. Criar arquivo de IPs do Nginx ---
if [ ! -f "$NGINX_CONF" ]; then
    touch "$NGINX_CONF"
    echo "✅ Arquivo criado: $NGINX_CONF"
else
    echo "✅ Arquivo já existe: $NGINX_CONF"
fi

# --- 7. Criar arquivo de log ---
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
    echo "✅ Log criado: $LOG_FILE"
else
    echo "✅ Log já existe: $LOG_FILE"
fi

# --- 8. Criar o script pma-on ---
cat << 'EOF' > "$INSTALL_DIR/pma-on"
#!/bin/bash

# ======================================================================
# pma-on — Abre o acesso ao phpMyAdmin para o seu IP
# Uso: pma-on [tempo]
#   Exemplos: pma-on        (usa o tempo padrão definido em porteiro.conf)
#             pma-on 30m    (libera por 30 minutos)
#             pma-on 2h     (libera por 2 horas)
# ======================================================================

CONFIG_FILE="/opt/porteiro/porteiro.conf"
NGINX_CONF="/etc/nginx/pma_ips.conf"
LOG_FILE="/var/log/porteiro.log"

source "$CONFIG_FILE"

# --- Detecta o IP da sessão SSH ---
MEU_IP=$(echo "$SSH_CLIENT" | awk '{ print $1 }')

if [ -z "$MEU_IP" ]; then
    echo ""
    echo "❌ Erro: IP da sessão SSH não detectado."
    echo ""
    echo "   Este comando deve ser executado dentro de uma sessão SSH remota."
    echo "   Exemplo: conecte ao servidor com 'ssh usuario@ip-do-servidor'"
    echo "   e então rode 'sudo pma-on'."
    echo ""
    echo "   Se você está no servidor local (sem SSH), defina o IP manualmente:"
    echo "   sudo SSH_CLIENT='SEU_IP 0 0' pma-on"
    echo ""
    exit 1
fi

# --- Processa o argumento de tempo ---
TEMPO_ARG="$1"
TEMPO_MINUTOS="$DEFAULT_TIME"
TEMPO_LABEL="${DEFAULT_TIME} minuto(s)"

if [ -n "$TEMPO_ARG" ]; then
    NUMERO=$(echo "$TEMPO_ARG" | grep -o '[0-9]*')
    UNIDADE=$(echo "$TEMPO_ARG" | grep -o '[a-zA-Z]*')

    case "$UNIDADE" in
        m|min|minutos)
            TEMPO_MINUTOS="$NUMERO"
            TEMPO_LABEL="${NUMERO} minuto(s)"
            ;;
        h|hora|horas)
            TEMPO_MINUTOS=$((NUMERO * 60))
            TEMPO_LABEL="${NUMERO} hora(s)"
            ;;
        *)
            echo "⚠️  Unidade inválida: '$UNIDADE'. Use 'm' para minutos ou 'h' para horas."
            echo "   Usando tempo padrão: ${DEFAULT_TIME} minutos."
            ;;
    esac
fi

# --- Injeta o IP no Nginx ---
echo "allow $MEU_IP;" > "$NGINX_CONF"
systemctl reload nginx

# --- Cancela agendamentos anteriores e agenda o Auto-Off ---
for job in $(atq | awk '{print $1}'); do atrm "$job"; done 2>/dev/null
echo "/usr/local/bin/pma-off > /dev/null 2>&1" | at now + ${TEMPO_MINUTOS} minutes 2>/dev/null

# --- Registra no log ---
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
echo "[$TIMESTAMP] ABERTO  | IP: $MEU_IP | Duração: $TEMPO_LABEL | Host: $HOSTNAME" >> "$LOG_FILE"

# --- Notificação Telegram (opcional) ---
if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    MENSAGEM="🚪 *Porteiro — Acesso Liberado*%0A%0A🖥 Host: $HOSTNAME%0A🌍 IP autorizado: \`$MEU_IP\`%0A⏱ Duração: $TEMPO_LABEL%0A🕐 Horário: $TIMESTAMP"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${MENSAGEM}" \
        -d "parse_mode=Markdown" > /dev/null 2>&1
fi

# --- Saída ---
echo ""
echo "✅ Acesso liberado!"
echo "   IP autorizado : $MEU_IP"
echo "   Duração       : $TEMPO_LABEL"
echo "   Auto-Off em   : ${TEMPO_MINUTOS} minuto(s)"
echo ""
EOF

# --- 9. Criar o script pma-off ---
cat << 'EOF' > "$INSTALL_DIR/pma-off"
#!/bin/bash

# ======================================================================
# pma-off — Fecha o acesso e bloqueia o phpMyAdmin para todos
# ======================================================================

CONFIG_FILE="/opt/porteiro/porteiro.conf"
NGINX_CONF="/etc/nginx/pma_ips.conf"
LOG_FILE="/var/log/porteiro.log"

source "$CONFIG_FILE"

# --- Limpa o arquivo de IPs ---
echo "" > "$NGINX_CONF"
systemctl reload nginx

# --- Registra no log ---
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
echo "[$TIMESTAMP] FECHADO | Host: $HOSTNAME" >> "$LOG_FILE"

# --- Notificação Telegram (opcional) ---
if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    MENSAGEM="🔒 *Porteiro — Acesso Bloqueado*%0A%0A🖥 Host: $HOSTNAME%0A🕐 Horário: $TIMESTAMP"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${MENSAGEM}" \
        -d "parse_mode=Markdown" > /dev/null 2>&1
fi

# --- Saída ---
echo ""
echo "🔒 Acesso bloqueado!"
echo "   O phpMyAdmin está isolado da internet."
echo ""
EOF

# --- 10. Criar o script pma-status ---
cat << 'EOF' > "$INSTALL_DIR/pma-status"
#!/bin/bash

# ======================================================================
# pma-status — Mostra o estado atual do Porteiro
# ======================================================================

NGINX_CONF="/etc/nginx/pma_ips.conf"
LOG_FILE="/var/log/porteiro.log"

echo ""
echo "🚪 Porteiro — Status"
echo "========================"

# --- Verifica se há IP autorizado ---
IP_ATUAL=$(grep -oP '(?<=allow )[^;]+' "$NGINX_CONF" 2>/dev/null)

if [ -n "$IP_ATUAL" ]; then
    echo "   Estado  : 🟢 ABERTO"
    echo "   IP ativo: $IP_ATUAL"

    # Mostra quando o Auto-Off está agendado
    PROXIMO_JOB=$(atq 2>/dev/null | head -1)
    if [ -n "$PROXIMO_JOB" ]; then
        HORA_OFF=$(echo "$PROXIMO_JOB" | awk '{print $3, $4}')
        echo "   Auto-Off: $HORA_OFF"
    fi
else
    echo "   Estado  : 🔴 FECHADO"
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
EOF

# --- 11. Permissões corretas ---
# 755 nos scripts para que qualquer usuário possa executar (root ainda é necessário para systemctl)
chmod 755 "$INSTALL_DIR/pma-on"
chmod 755 "$INSTALL_DIR/pma-off"
chmod 755 "$INSTALL_DIR/pma-status"
chmod 640 "$CONFIG_FILE"
chown root:root "$INSTALL_DIR/pma-on"
chown root:root "$INSTALL_DIR/pma-off"
chown root:root "$INSTALL_DIR/pma-status"

echo "🔐 Permissões aplicadas (755, root:root)"

# --- 12. Criar links simbólicos globais ---
ln -sf "$INSTALL_DIR/pma-on"     /usr/local/bin/pma-on
ln -sf "$INSTALL_DIR/pma-off"    /usr/local/bin/pma-off
ln -sf "$INSTALL_DIR/pma-status" /usr/local/bin/pma-status

echo "🔗 Comandos globais registrados: pma-on | pma-off | pma-status"

# --- 13. Instrução final ---
echo ""
echo "=============================="
echo "🚪 Porteiro v2.0 instalado com sucesso!"
echo ""
echo "⚙️  Configure em: /opt/porteiro/porteiro.conf"
echo "   → Ajuste o tempo padrão e as rotas protegidas"
if [ -z "$TELEGRAM_TOKEN" ]; then
echo "   → Ative o Telegram adicionando TOKEN e CHAT_ID (opcional)"
fi
echo ""
echo "⚠️  PASSO FINAL (manual): Adicione o bloco abaixo no seu Nginx."
echo "   Arquivo sugerido: /etc/nginx/sites-available/default"
echo ""
echo "----------------------------------------------------------------------"
cat << 'NGINX_BLOCK'
    # ======================================================================
    # PORTEIRO — Proteção do phpMyAdmin (Liberação Dinâmica por IP)
    # ======================================================================
    location ^~ /phpmyadmin/ {
        include /etc/nginx/pma_ips.conf;
        deny all;

        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php-fpm.sock; # Ajuste para sua versão do PHP
        }
    }
NGINX_BLOCK
echo "----------------------------------------------------------------------"
echo ""
echo "   Após editar o Nginx, rode:"
echo "   sudo nginx -t && sudo systemctl reload nginx"
echo ""
echo "   Comandos disponíveis:"
echo "   sudo pma-on [tempo]  → Abre a porta (ex: sudo pma-on | sudo pma-on 30m | sudo pma-on 2h)"
echo "   sudo pma-off         → Fecha a porta imediatamente"
echo "   sudo pma-status      → Mostra estado atual e log recente"
echo ""
echo "   ⚠️  Use sempre 'sudo' — os comandos precisam de root para recarregar o Nginx."
echo ""