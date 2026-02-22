# 🚪 Porteiro — Seu Servidor Tem Segurança Agora

[![Status](https://img.shields.io/badge/STATUS-DE%20PLANTÃO-green?style=for-the-badge)](https://github.com/henriquetourinho/porteiro)
[![Versão](https://img.shields.io/badge/VERSÃO-2.0-orange?style=for-the-badge)](https://github.com/henriquetourinho/porteiro)
[![Tech](https://img.shields.io/badge/TECH-SHELL%20SCRIPT%20%2B%20NGINX-blue?style=for-the-badge)](https://github.com/henriquetourinho/porteiro)
[![Local](https://img.shields.io/badge/LOCAL-BAHIA-yellow?style=for-the-badge&labelColor=green)](https://github.com/henriquetourinho/porteiro)
[![Licença](https://img.shields.io/badge/LICEN%C3%87A-MIT-red?style=for-the-badge)](LICENSE)

> "Pode entrar. Você, não." 🚪

---

## 📜 Sobre o Projeto

O **Porteiro** é um Shell Script simples e cirúrgico que resolve um problema clássico de quem sobe um servidor Linux com phpMyAdmin: **a porta de entrada fica escancarada pra internet inteira.**

Enquanto você dorme, bots do mundo todo ficam batendo na porta do seu `/phpmyadmin/` tentando entrar na força bruta. O Porteiro resolve isso do jeito mais elegante possível — ele **tranca tudo** e só abre a porta quando você mesmo aparece via SSH.

A lógica é simples:
- 🌍 **Pra internet:** erro 403. Nem existe.
- 🔑 **Pra você (via SSH):** `pma-on`. Acesso liberado na hora.
- ⏱️ **Depois do tempo configurado:** `pma-off`. A porta tranca sozinha, mesmo que você esqueça.

**Zero dependência externa. Zero banco de dados. Zero token. O SSH já é sua identidade.**

**Desenvolvido por:** Carlos Henrique Tourinho Santana

---

## ✨ Funcionalidades

- **🔍 Detecção Automática de IP:** Lê seu IP direto da sessão SSH via `$SSH_CLIENT`. Sem digitar nada.
- **🌍 Isolamento Total:** Bloqueia a rota com `deny all` para o resto da internet. O `/phpmyadmin/` simplesmente não existe.
- **⚡ Liberação Instantânea:** Um comando (`pma-on`) e seu navegador já acessa. Nginx recarrega na hora.
- **⏱️ Tempo Configurável:** `pma-on 30m`, `pma-on 2h` — você define quanto tempo quer de acesso por sessão.
- **⏱️ Auto-Off Inteligente:** Fecha automaticamente quando o tempo acabar. Anti-esquecimento nativo.
- **🔒 Fechamento Manual:** Terminou antes? `pma-off` tranca na hora, sem esperar o timer.
- **📊 Status em Tempo Real:** `pma-status` mostra se a porta está aberta, qual IP está ativo, quando o Auto-Off vai disparar e o log recente.
- **📋 Log de Auditoria:** Cada abertura e fechamento é registrado em `/var/log/porteiro.log` com timestamp, IP e hostname.
- **📣 Notificação via Telegram:** Receba uma mensagem no celular sempre que a porta abrir ou fechar. Totalmente opcional.
- **🛣️ Multi-rota:** Proteja `/phpmyadmin/`, `/adminer/`, `/wp-admin/` ou qualquer rota sensível — configure em `porteiro.conf`.
- **🪶 Levíssimo:** Shell Script puro. Zero dependências externas. Funciona até em VPS de R$15/mês.

---

## 🛠️ Tecnologias Usadas

A stack mais enxuta possível — porque segurança não precisa ser complicada:

- **Shell Script (Bash)** — A lógica toda. Sem framework, sem runtime.
- **Nginx** — O portão. Lê o IP injetado e decide quem passa.
- **`at`** — O reloginho que tranca a porta sozinho após o tempo definido.
- **`$SSH_CLIENT`** — A variável nativa do SSH que entrega seu IP de bandeja.
- **Telegram Bot API** — Notificações opcionais via `curl`. Zero biblioteca externa.

---

## 🚀 Como Instalar

Sem `npm install`. Sem `docker-compose up`. Um único script faz tudo.

### 1. Clonar o repositório

```bash
git clone https://github.com/henriquetourinho/porteiro.git
cd porteiro
```

### 2. Rodar o instalador

```bash
sudo bash install.sh
```

O instalador cuida de tudo automaticamente:
- Instala o `at` (se não estiver presente)
- Cria o diretório `/opt/porteiro/` com os scripts
- Cria o arquivo de configuração `/opt/porteiro/porteiro.conf`
- Cria o arquivo `/etc/nginx/pma_ips.conf`
- Cria o log em `/var/log/porteiro.log`
- Aplica permissões corretas (`750`, `root:root`)
- Registra os comandos globais `pma-on`, `pma-off` e `pma-status`

### 3. Configurar o Nginx (único passo manual)

Abra a configuração do seu Nginx (ex: `/etc/nginx/sites-available/default`) e adicione o bloco abaixo antes das configurações gerais do PHP:

```nginx
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
```

Valide e recarregue o Nginx:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

A partir daqui, `/phpmyadmin/` retorna **403 Forbidden** para o mundo inteiro. O Porteiro assumiu o plantão.

### 4. (Opcional) Configurar Telegram

Edite o arquivo de configuração:

```bash
sudo nano /opt/porteiro/porteiro.conf
```

Preencha as duas variáveis:

```bash
TELEGRAM_TOKEN="seu_token_aqui"
TELEGRAM_CHAT_ID="seu_chat_id_aqui"
```

**Como obter:**
- **TOKEN** → Abra o Telegram, fale com `@BotFather` e crie um novo bot. Ele te entrega o token.
- **CHAT_ID** → Fale com `@userinfobot` no Telegram. Ele responde com seu ID numérico.

Salve o arquivo. A partir do próximo `pma-on` ou `pma-off`, você receberá notificações no celular.

---

## 📁 Estrutura do Projeto

```
porteiro/
├── install.sh        # Instalador automático (rode isso e acabou)
├── README.md         # Este arquivo
└── LICENSE           # MIT

# Após instalar, os scripts ficam em:
/opt/porteiro/
├── pma-on            # Abre a porta para o seu IP
├── pma-off           # Fecha a porta para todo mundo
├── pma-status        # Mostra o estado atual
└── porteiro.conf     # Configurações (tempo, rotas, Telegram)

# Comandos globais registrados em:
/usr/local/bin/pma-on
/usr/local/bin/pma-off
/usr/local/bin/pma-status

# Arquivos gerados no servidor:
/etc/nginx/pma_ips.conf   # IP injetado dinamicamente
/var/log/porteiro.log     # Log de auditoria
```

---

## 🛠️ Como Usar

No dia a dia, é só isso:

### Abrir o acesso

```bash
pma-on          # Usa o tempo padrão (porteiro.conf)
pma-on 30m      # Libera por 30 minutos
pma-on 2h       # Libera por 2 horas
```

Saída esperada:
```
✅ Acesso liberado!
   IP autorizado : 189.x.x.x
   Duração       : 2 hora(s)
   Auto-Off em   : 120 minuto(s)
```

### Fechar o acesso manualmente

```bash
pma-off
```

Saída esperada:
```
🔒 Acesso bloqueado!
   O phpMyAdmin está isolado da internet.
```

### Verificar o status

```bash
pma-status
```

Saída esperada:
```
🚪 Porteiro — Status
========================
   Estado  : 🟢 ABERTO
   IP ativo: 189.x.x.x
   Auto-Off: 22:45:00

📋 Últimas 10 entradas do log:
------------------------
[2026-02-22 21:45:12] ABERTO  | IP: 189.x.x.x | Duração: 1 hora(s) | Host: meuservidor
[2026-02-22 20:10:03] FECHADO | Host: meuservidor
```

---

## ⚙️ Como Funciona por Dentro

```
[Você faz SSH]
      ↓
[pma-on lê $SSH_CLIENT e extrai seu IP]
      ↓
[Processa argumento de tempo (ou usa DEFAULT_TIME do porteiro.conf)]
      ↓
[Injeta "allow SEU_IP;" em /etc/nginx/pma_ips.conf]
      ↓
[Nginx recarrega — só você passa. Mundo leva 403.]
      ↓
[Registra no /var/log/porteiro.log]
      ↓
[Envia notificação no Telegram (se configurado)]
      ↓
[at agenda pma-off para daqui X minutos]
      ↓
[Tempo esgotado: pma_ips.conf é limpo → 403 pra todo mundo de novo]
```

A mágica está na variável nativa `$SSH_CLIENT` do Linux, que expõe o IP, porta de origem e porta de destino da conexão SSH ativa. O Porteiro pega apenas o primeiro campo (o IP) e o usa como chave de acesso temporária.

---

## 📊 Comparativo de Segurança

| Cenário | Sem Porteiro | Com Porteiro |
|---|---|---|
| `/phpmyadmin/` exposto na internet | ✅ Sim (vulnerável) | ❌ Não (403 pra todos) |
| Ataques de força bruta | ✅ Possível | ❌ Impossível (porta fechada) |
| Acesso do administrador | ✅ Sim | ✅ Sim (via SSH + pma-on) |
| Esqueceu a porta aberta | ✅ Problema seu | ❌ Auto-Off resolve |
| Controle do tempo de acesso | ❌ Não | ✅ pma-on 30m / 2h |
| Auditoria de acessos | ❌ Não | ✅ /var/log/porteiro.log |
| Alerta no celular | ❌ Não | ✅ Telegram (opcional) |
| Dependências externas | — | Zero |
| Configuração necessária | — | ~5 minutos |

---

## ✅ Checklist de Segurança

### Proteção ✅
- [x] Rota `/phpmyadmin/` inacessível por padrão (403)
- [x] Liberação apenas para IP autenticado via SSH
- [x] Auto-Off configurável (anti-esquecimento)
- [x] Fechamento manual disponível
- [x] Sem credenciais armazenadas em disco

### Monitoramento ✅
- [x] Log de auditoria em `/var/log/porteiro.log`
- [x] `pma-status` com estado em tempo real
- [x] Notificação Telegram (opcional)

### Leveza ✅
- [x] Zero dependências npm/pip/gem
- [x] Zero banco de dados
- [x] Zero tokens obrigatórios
- [x] Shell Script puro
- [x] Funciona em qualquer VPS com Nginx

### Compatibilidade ✅
- [x] Ubuntu / Debian
- [x] Qualquer versão do PHP-FPM (ajuste o socket)
- [x] Nginx (qualquer versão recente)
- [x] Adaptável para qualquer rota sensível

---

## 🔧 Configurações e Personalização

O arquivo `/opt/porteiro/porteiro.conf` centraliza tudo:

```bash
# Tempo padrão em minutos (quando nenhum argumento é passado)
DEFAULT_TIME=60

# Rotas protegidas (separadas por espaço)
ROTAS="/phpmyadmin/ /adminer/ /wp-admin/"

# Telegram (deixe vazio para desativar)
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""
```

### Mudar o tempo do Auto-Off padrão

Edite `DEFAULT_TIME` no `porteiro.conf`. Ou passe diretamente no comando:

```bash
pma-on 30m   # 30 minutos
pma-on 2h    # 2 horas
```

### Liberar múltiplos IPs

Edite o `pma-on` para adicionar IPs fixos além do seu dinâmico:

```bash
echo "allow $MEU_IP;" > "$NGINX_CONF"
echo "allow IP_DO_SEU_ESCRITORIO;" >> "$NGINX_CONF"
```

---

## 🚀 Roadmap (v3.0) — Próximas Melhorias

- **Suporte a Apache** — Versão equivalente para `.htaccess`
- **`uninstall.sh`** — Remove tudo limpo do servidor
- **Tempo via argumento no pma-off** — `pma-off` com delay opcional
- **Rotação de log** — Integração com `logrotate`
- **Suporte a IPv6** — Para servidores modernos

---

## ⚖️ Disclaimer

O **Porteiro** é uma ferramenta de segurança legítima desenvolvida para administradores de servidores protegerem seus próprios ambientes.

- ✅ Use apenas em servidores que você administra
- ✅ Compatível com qualquer VPS ou servidor dedicado
- ❌ Não nos responsabilizamos pelo uso indevido
- ❌ Não substitui outras boas práticas de segurança (senhas fortes, atualizações, firewall)

---

## 🔥 FAQ

### O Porteiro substitui o firewall (UFW/iptables)?

Não — ele age na camada do Nginx (HTTP), enquanto o firewall age na camada de rede. Os dois se complementam. Use ambos.

### Funciona se meu IP residencial muda toda hora?

Sim! O `pma-on` sempre lê o IP atual da sessão SSH ativa. Cada vez que você rodar, ele atualiza automaticamente.

### E se eu fechar o terminal antes de rodar pma-off?

O Auto-Off cuida disso. Após o tempo configurado, o acesso é bloqueado automaticamente.

### O Telegram é obrigatório?

Não. Deixe `TELEGRAM_TOKEN` e `TELEGRAM_CHAT_ID` em branco no `porteiro.conf` e as notificações são ignoradas silenciosamente.

### Posso usar com Apache?

A versão atual é exclusiva para Nginx. O suporte ao Apache está no Roadmap v3.0.

### Funciona em qualquer VPS?

Sim, desde que rode Ubuntu/Debian com Nginx. Testado em VPS de entrada (1vCPU, 1GB RAM).

---

## 📄 Licença

Este projeto está sob a licença **MIT** — veja o arquivo [LICENSE](LICENSE) para detalhes.

**TL;DR:** Pode usar, modificar, distribuir. Só dê os créditos.

---

## 👤 Autor

**Carlos Henrique Tourinho Santana**

*"Segurança boa é a que funciona enquanto você dorme."*

### 📫 Contato

- 📧 Email: [henriquetourinho@riseup.net](mailto:henriquetourinho@riseup.net)
- 📱 Instagram: [@henrique.ntxa](https://www.instagram.com/henrique.ntxa/)
- 💻 GitHub: [henriquetourinho](https://github.com/henriquetourinho)
- 🐧 Wiki Debian: [henriquetourinho](https://wiki.debian.org/henriquetourinho)

### ⭐ Apoie o Projeto

Se o Porteiro salvou seu servidor de algum ataque:

- ⭐ Dê uma **star** no repositório
- 🐛 **Reporte bugs** ou sugira melhorias
- 🤝 **Contribua** com código
- 📢 **Compartilhe** com outros sysadmins

---

## 🙏 Agradecimentos

- À comunidade **open source** que inspira soluções simples para problemas sérios
- A todo **sysadmin** que já ficou com o coração na mão vendo o log do Nginx cheio de tentativas de invasão
- Aos bots de força bruta — sem vocês, o Porteiro não existiria

---

**Feito com paranoia saudável e café em Salvador, Bahia 🌴☕**

Código aberto. Porta fechada.

---

> Este projeto não tem afiliação com Nginx Inc. ou qualquer distribuição Linux.
> © 2026 Carlos Henrique Tourinho Santana — MIT License