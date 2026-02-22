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
- 🔑 **Pra você (via SSH):** `sudo porteiro-on`. Acesso liberado na hora em todas as rotas.
- ⏱️ **Depois do tempo configurado:** `porteiro-off`. A porta tranca sozinha, mesmo que você esqueça.

**Zero dependência externa. Zero banco de dados. Zero token obrigatório. O SSH já é sua identidade.**

**Desenvolvido por:** Carlos Henrique Tourinho Santana

---

## ✨ Funcionalidades

- **🔍 Detecção Automática de IP:** Lê seu IP direto da sessão SSH via `$SSH_CLIENT`. Sem digitar nada.
- **🌍 Isolamento Total:** Bloqueia as rotas com `deny all` para o resto da internet. O `/phpmyadmin/` simplesmente não existe.
- **⚡ Liberação Instantânea:** Um comando (`sudo porteiro-on`) e seu navegador já acessa. Nginx recarrega na hora.
- **⏱️ Tempo Configurável:** `sudo porteiro-on 30m`, `sudo porteiro-on 2h` — você define quanto tempo quer de acesso por sessão.
- **⏱️ Auto-Off Inteligente:** Fecha automaticamente quando o tempo acabar. Anti-esquecimento nativo.
- **🔒 Fechamento Manual:** Terminou antes? `sudo porteiro-off` tranca na hora, sem esperar o timer.
- **📊 Status em Tempo Real:** `sudo porteiro-status` mostra se a porta está aberta, qual IP está ativo, quais rotas estão protegidas e o log recente — e notifica via Telegram se configurado.
- **📋 Log de Auditoria:** Cada abertura e fechamento é registrado em `/var/log/porteiro.log` com timestamp, IP, rotas e hostname.
- **📣 Notificação via Telegram:** Receba uma mensagem no celular sempre que a porta abrir, fechar ou o status for consultado. Totalmente opcional — configurado com wizard durante a instalação.
- **🛣️ Multi-rota:** Proteja `/phpmyadmin/`, `/adminer/`, `/wp-admin/` ou qualquer rota sensível. Um `porteiro-on` libera tudo, um `porteiro-off` bloqueia tudo. Rotas escolhidas interativamente durante a instalação.
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

O instalador guia você por dois wizards interativos antes de criar qualquer arquivo:

**Wizard 1 — Rotas protegidas:**
```
🛣️  Rotas Protegidas (Multi-rota)
==============================
   ✅ /phpmyadmin/ — adicionada por padrão.

   Deseja proteger mais rotas? Selecione pelos números
   separados por espaço (ex: 1 3) ou pressione Enter para pular.

   [1] /adminer/
   [2] /wp-admin/
   [3] /wp-login.php
   [4] /panel/
   [5] Digitar manualmente

   Opções (ex: 1 2): 1 2
   ✅ '/adminer/' adicionada.
   ✅ '/wp-admin/' adicionada.

   Rotas que serão protegidas:
   → /phpmyadmin/
   → /adminer/
   → /wp-admin/
```

**Wizard 2 — Telegram (opcional):**
```
📣 Notificações via Telegram (opcional)
==============================
   Deseja configurar o Telegram agora? (s/N): s
   Token do bot: SEU_TOKEN
   Chat ID:      SEU_CHAT_ID
   ✅ Bot validado! Notificações ativadas.
```

Após os wizards, o instalador também cuida de:
- Instalar o `at` (se não estiver presente)
- Criar o diretório `/opt/porteiro/` com os scripts
- Criar o arquivo de configuração `/opt/porteiro/porteiro.conf` com as rotas escolhidas
- Criar o arquivo `/etc/nginx/porteiro_ips.conf`
- Criar o log em `/var/log/porteiro.log`
- Aplicar permissões corretas (`755`, `root:root`)
- Registrar os comandos globais `porteiro-on`, `porteiro-off` e `porteiro-status`
- Gerar os **blocos Nginx prontos** para cada rota escolhida

### 3. Configurar o Nginx (único passo manual)

Ao final da instalação, o script exibe os blocos Nginx prontos para copiar — um para cada rota escolhida no wizard. Exemplo para `/phpmyadmin/` e `/adminer/`:

```nginx
# --- PHPMYADMIN ---
location ^~ /phpmyadmin/ {
    include /etc/nginx/porteiro_ips.conf;
    deny all;

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }
}

# --- ADMINER ---
location ^~ /adminer/ {
    include /etc/nginx/porteiro_ips.conf;
    deny all;

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }
}
```

> 💡 **Multi-rota:** todas as rotas compartilham o mesmo `/etc/nginx/porteiro_ips.conf`. Um `porteiro-on` libera tudo. Um `porteiro-off` bloqueia tudo.

Abra o arquivo do Nginx, cole os blocos e recarregue:

```bash
sudo nano /etc/nginx/sites-available/default
sudo nginx -t && sudo systemctl reload nginx
```

A partir daqui, as rotas retornam **403 Forbidden** para o mundo inteiro. O Porteiro assumiu o plantão.

### 4. (Opcional) Reconfigurar Telegram depois

Se pulou o Telegram durante a instalação, edite o `porteiro.conf`:

```bash
sudo nano /opt/porteiro/porteiro.conf
```

```bash
TELEGRAM_TOKEN="seu_token_aqui"
TELEGRAM_CHAT_ID="seu_chat_id_aqui"
```

**Como obter:**
- **TOKEN** → Fale com `@BotFather` no Telegram e crie um bot.
- **CHAT_ID** → Fale com `@userinfobot` no Telegram.

**Testar manualmente:**
```bash
curl "https://api.telegram.org/botSEU_TOKEN/getMe"
```

---

## 🗑️ Como Desinstalar

```bash
sudo bash uninstall.sh
```

O desinstalador também é interativo:
- Fecha o acesso e limpa o Nginx antes de remover qualquer coisa
- Cancela agendamentos do Auto-Off
- Remove scripts, links simbólicos e arquivos de configuração
- Pergunta se deseja remover o log de auditoria
- Lista as rotas que estavam protegidas e oferece abrir o Nginx para remover os blocos manualmente

---

## 📁 Estrutura do Projeto

```
porteiro/
├── install.sh        # Instalador automático com wizards interativos
├── uninstall.sh      # Desinstalador interativo (remove tudo limpo)
├── README.md         # Este arquivo
└── LICENSE           # MIT

# Após instalar, os scripts ficam em:
/opt/porteiro/
├── porteiro-on            # Libera seu IP em todas as rotas protegidas
├── porteiro-off           # Bloqueia todas as rotas para todo mundo
├── porteiro-status        # Mostra estado, rotas ativas e log recente
└── porteiro.conf     # Configurações (tempo, rotas, Telegram)

# Comandos globais registrados em:
/usr/local/bin/porteiro-on
/usr/local/bin/porteiro-off
/usr/local/bin/porteiro-status

# Arquivos gerados no servidor:
/etc/nginx/porteiro_ips.conf   # IP injetado dinamicamente (compartilhado por todas as rotas)
/var/log/porteiro.log     # Log de auditoria
```

---

## 🛠️ Como Usar

No dia a dia, é só isso:

### Abrir o acesso

```bash
sudo porteiro-on          # Usa o tempo padrão (porteiro.conf)
sudo porteiro-on 30m      # Libera por 30 minutos
sudo porteiro-on 2h       # Libera por 2 horas
```

Saída esperada:
```
✅ Acesso liberado!
   IP autorizado : 189.x.x.x
   Duração       : 2 hora(s)
   Auto-Off em   : 120 minuto(s)
   Rotas ativas  : /phpmyadmin/ /adminer/
```

### Fechar o acesso manualmente

```bash
sudo porteiro-off
```

Saída esperada:
```
🔒 Acesso bloqueado!
   Rotas isoladas: /phpmyadmin/ /adminer/
```

### Verificar o status

```bash
sudo porteiro-status
```

Saída esperada:
```
🚪 Porteiro — Status
========================
   Estado  : 🟢 ABERTO
   IP ativo: 189.x.x.x
   Rotas   : /phpmyadmin/ /adminer/
   Auto-Off: 22:45:00

📋 Últimas 10 entradas do log:
------------------------
[2026-02-22 21:45:12] ABERTO  | IP: 189.x.x.x | Duração: 1 hora(s) | Rotas: /phpmyadmin/,/adminer/ | Host: meuservidor
[2026-02-22 20:10:03] FECHADO | Rotas: /phpmyadmin/,/adminer/ | Host: meuservidor
```

---

## ⚙️ Como Funciona por Dentro

```
[Você faz SSH no servidor]
      ↓
[porteiro-on lê $SSH_CLIENT e extrai seu IP]
      ↓
[Processa argumento de tempo (ou usa DEFAULT_TIME do porteiro.conf)]
      ↓
[Injeta "allow SEU_IP;" em /etc/nginx/porteiro_ips.conf]
      ↓
[Nginx recarrega — todas as rotas com include porteiro_ips.conf liberam seu IP]
      ↓
[Registra no /var/log/porteiro.log com IP e rotas]
      ↓
[Envia notificação no Telegram com IP, rotas e duração (se configurado)]
      ↓
[at agenda porteiro-off para daqui X minutos]
      ↓
[Tempo esgotado: porteiro_ips.conf é limpo → 403 em todas as rotas de novo]
```

A mágica do multi-rota está no arquivo `/etc/nginx/porteiro_ips.conf` — compartilhado por todos os blocos `location`. Alterar esse arquivo uma vez afeta todas as rotas simultaneamente. O Porteiro nunca toca diretamente na configuração do Nginx.

---

## 📊 Comparativo de Segurança

| Cenário | Sem Porteiro | Com Porteiro |
|---|---|---|
| Rotas sensíveis expostas na internet | ✅ Sim (vulnerável) | ❌ Não (403 pra todos) |
| Ataques de força bruta | ✅ Possível | ❌ Impossível (porta fechada) |
| Acesso do administrador | ✅ Sim | ✅ Sim (via SSH + porteiro-on) |
| Esqueceu a porta aberta | ✅ Problema seu | ❌ Auto-Off resolve |
| Controle do tempo de acesso | ❌ Não | ✅ porteiro-on 30m / 2h |
| Proteger múltiplas rotas | ❌ Configuração manual | ✅ Multi-rota com wizard |
| Auditoria de acessos | ❌ Não | ✅ /var/log/porteiro.log |
| Alerta no celular | ❌ Não | ✅ Telegram (opcional) |
| Configuração necessária | — | ~5 minutos |
| Dependências externas | — | Zero |

---

## ✅ Checklist de Segurança

### Proteção ✅
- [x] Rotas inacessíveis por padrão (403)
- [x] Liberação apenas para IP autenticado via SSH
- [x] Auto-Off configurável (anti-esquecimento)
- [x] Fechamento manual disponível
- [x] Sem credenciais armazenadas em disco
- [x] Multi-rota com arquivo compartilhado

### Monitoramento ✅
- [x] Log de auditoria com IP e rotas em `/var/log/porteiro.log`
- [x] `porteiro-status` com estado e rotas em tempo real
- [x] Notificação Telegram no `porteiro-on`, `porteiro-off` e `porteiro-status` (opcional)

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
- [x] Qualquer rota sensível

---

## 🔧 Configurações e Personalização

O arquivo `/opt/porteiro/porteiro.conf` centraliza tudo:

```bash
# Tempo padrão em minutos (quando nenhum argumento é passado)
DEFAULT_TIME=60

# Rotas protegidas (separadas por espaço)
# Cada rota deve ter um bloco location no Nginx com:
#   include /etc/nginx/porteiro_ips.conf;
#   deny all;
ROTAS="/phpmyadmin/ /adminer/ /wp-admin/"

# Telegram (deixe vazio para desativar)
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""
```

### Adicionar uma nova rota depois da instalação

**1. Edite o `porteiro.conf`:**
```bash
sudo nano /opt/porteiro/porteiro.conf
# Adicione a nova rota em ROTAS:
ROTAS="/phpmyadmin/ /adminer/"
```

**2. Adicione o bloco no Nginx:**
```nginx
location ^~ /adminer/ {
    include /etc/nginx/porteiro_ips.conf;
    deny all;
}
```

**3. Recarregue o Nginx:**
```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Mudar o tempo padrão do Auto-Off

Edite `DEFAULT_TIME` no `porteiro.conf` ou passe direto no comando:

```bash
sudo porteiro-on 30m   # 30 minutos
sudo porteiro-on 2h    # 2 horas
```

### Usar no servidor local (sem SSH remoto)

O `porteiro-on` depende da variável `$SSH_CLIENT`, que só existe em sessões SSH remotas. Se estiver no próprio servidor:

```bash
sudo SSH_CLIENT='SEU_IP 0 0' porteiro-on
```

---

## 🚀 Roadmap (v3.0) — Próximas Melhorias

- **Suporte a Apache** — Versão equivalente para `.htaccess`
- **Rotação de log** — Integração com `logrotate`
- **Suporte a IPv6** — Para servidores modernos
- **`porteiro-off` com delay** — `porteiro-off 10m` fecha em 10 minutos

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

Sim! O `porteiro-on` sempre lê o IP atual da sessão SSH ativa. Cada vez que você rodar, ele atualiza automaticamente.

### E se eu fechar o terminal antes de rodar porteiro-off?

O Auto-Off cuida disso. Após o tempo configurado, o acesso é bloqueado automaticamente em todas as rotas.

### O Telegram é obrigatório?

Não. Deixe `TELEGRAM_TOKEN` e `TELEGRAM_CHAT_ID` em branco no `porteiro.conf` e as notificações são ignoradas silenciosamente.

### Como funciona o multi-rota na prática?

O arquivo `/etc/nginx/porteiro_ips.conf` é compartilhado por todos os blocos `location` que você configurar no Nginx. Quando o `porteiro-on` injeta seu IP e recarrega o Nginx, todas as rotas com `include /etc/nginx/porteiro_ips.conf` são liberadas de uma vez. Um `porteiro-off` limpa o arquivo e bloqueia tudo simultaneamente.

### Posso adicionar rotas depois da instalação?

Sim! Edite `ROTAS` no `porteiro.conf`, adicione o bloco correspondente no Nginx e recarregue. Veja a seção **Configurações e Personalização** acima.

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