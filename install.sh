#!/bin/bash

# ======================================================================
# PORTEIRO — Instalador Oficial
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
echo "🚪 Porteiro — Instalando..."
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

# --- 3. Criar o arquivo de IPs do Nginx ---
NGINX_CONF="/etc/nginx/pma_ips.conf"
if [ ! -f "$NGINX_CONF" ]; then
    touch "$NGINX_CONF"
    echo "✅ Arquivo criado: $NGINX_CONF"
else
    echo "✅ Arquivo já existe: $NGINX_CONF"
fi

# --- 4. Criar o script pma-on ---
cat << 'EOF' > "$INSTALL_DIR/pma-on"
#!/bin/bash

# Captura o IP da sessão SSH ativa
MEU_IP=$(echo "$SSH_CLIENT" | awk '{ print $1 }')

if [ -z "$MEU_IP" ]; then
    echo "❌ Erro: Não foi possível detectar o IP da conexão SSH."
    echo "   Certifique-se de estar conectado via SSH antes de rodar este comando."
    exit 1
fi

NGINX_CONF="/etc/nginx/pma_ips.conf"

# Injeta o IP no arquivo de configuração do Nginx
echo "allow $MEU_IP;" > "$NGINX_CONF"

# Recarrega o Nginx para aplicar a mudança
systemctl reload nginx

echo ""
echo "✅ Acesso liberado!"
echo "   IP autorizado: $MEU_IP"
echo ""

# Cancela agendamentos anteriores do pma-off para evitar conflitos
for job in $(atq | awk '{print $1}'); do atrm "$job"; done 2>/dev/null

# Agenda o fechamento automático em 1 hora
echo "/usr/local/bin/pma-off > /dev/null 2>&1" | at now + 1 hour 2>/dev/null

echo "⏱️  Auto-Off ativado: a porta será trancada automaticamente em 1 hora."
echo ""
EOF

# --- 5. Criar o script pma-off ---
cat << 'EOF' > "$INSTALL_DIR/pma-off"
#!/bin/bash

NGINX_CONF="/etc/nginx/pma_ips.conf"

# Limpa o arquivo de IPs (sem "allow", o Nginx aplica apenas o "deny all")
echo "" > "$NGINX_CONF"

# Recarrega o Nginx para aplicar o bloqueio
systemctl reload nginx

echo ""
echo "🔒 Acesso bloqueado!"
echo "   O phpMyAdmin está isolado da internet."
echo ""
EOF

# --- 6. Permissões corretas ---
chmod 750 "$INSTALL_DIR/pma-on"
chmod 750 "$INSTALL_DIR/pma-off"
# Apenas root pode ler e executar (segurança extra)
chown root:root "$INSTALL_DIR/pma-on"
chown root:root "$INSTALL_DIR/pma-off"

echo "🔐 Permissões aplicadas (750, root:root)"

# --- 7. Criar links simbólicos globais ---
ln -sf "$INSTALL_DIR/pma-on"  /usr/local/bin/pma-on
ln -sf "$INSTALL_DIR/pma-off" /usr/local/bin/pma-off

echo "🔗 Comandos globais registrados: pma-on | pma-off"

# --- 8. Instrução final para o Nginx ---
echo ""
echo "=============================="
echo "🚪 Porteiro instalado com sucesso!"
echo ""
echo "⚠️  PASSO FINAL (manual): Configure o bloco abaixo no seu Nginx."
echo "   Arquivo sugerido: /etc/nginx/sites-available/default"
echo ""
echo "----------------------------------------------------------------------"
cat << 'NGINX_BLOCK'
    # ======================================================================
    # PORTEIRO — Proteção do phpMyAdmin (Liberação Dinâmica por IP)
    # ======================================================================
    location ^~ /phpmyadmin/ {

        # Lê o IP injetado pelo Porteiro
        include /etc/nginx/pma_ips.conf;

        # Bloqueia qualquer outro acesso
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
echo "   Depois é só usar:"
echo "   pma-on   → Abre a porta para o seu IP"
echo "   pma-off  → Fecha a porta para todo mundo"
echo ""