# 🚪 Porteiro — Seu Servidor Tem Segurança Agora

[![Status](https://img.shields.io/badge/STATUS-DE%20PLANTÃO-green?style=for-the-badge)](https://github.com/henriquetourinho/porteiro)
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
- ⏱️ **Depois de 1 hora:** `pma-off`. A porta tranca sozinha, mesmo que você esqueça.

**Zero dependência externa. Zero banco de dados. Zero token. O SSH já é sua identidade.**

**Desenvolvido por:** Carlos Henrique Tourinho Santana

---

## ✨ Funcionalidades

- **🔍 Detecção Automática de IP:** Lê seu IP direto da sessão SSH via `$SSH_CLIENT`. Sem digitar nada.
- **🌍 Isolamento Total:** Bloqueia a rota com `deny all` para o resto da internet. O `/phpmyadmin/` simplesmente não existe.
- **⚡ Liberação Instantânea:** Um comando (`pma-on`) e seu navegador já acessa. Nginx recarrega na hora.
- **⏱️ Auto-Off Inteligente:** Agenda o fechamento automático em 1 hora via `at`. Anti-esquecimento nativo.
- **🔒 Fechamento Manual:** Terminou antes? `pma-off` tranca na hora, sem esperar o timer.
- **🪶 Levíssimo:** Dois arquivos Shell Script. Funciona até em VPS de R$15/mês.

---

## 🛠️ Tecnologias Usadas

A stack mais enxuta possível — porque segurança não precisa ser complicada:

- **Shell Script (Bash)** — A lógica toda. Sem framework, sem runtime.
- **Nginx** — O portão. Lê o IP injetado e decide quem passa.
- **`at`** — O reloginho que tranca a porta sozinho depois de 1 hora.
- **`$SSH_CLIENT`** — A variável nativa do SSH que entrega seu IP de bandeja.

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
- Cria o arquivo `/etc/nginx/pma_ips.conf`
- Aplica permissões corretas (`750`, `root:root`)
- Registra os comandos globais `pma-on` e `pma-off`

### 3. Configurar o Nginx (único passo manual)

Abra a configuração do seu Nginx (ex: `/etc/nginx/sites-available/default`) e adicione o bloco abaixo antes das configurações gerais do PHP:

```nginx
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
```

Valide e recarregue o Nginx:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

A partir daqui, `/phpmyadmin/` retorna **403 Forbidden** para o mundo inteiro. O Porteiro assumiu o plantão.

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
└── pma-off           # Fecha a porta para todo mundo

# Comandos globais registrados em:
/usr/local/bin/pma-on   → link para /opt/porteiro/pma-on
/usr/local/bin/pma-off  → link para /opt/porteiro/pma-off

# Arquivo de IPs injetado no Nginx:
/etc/nginx/pma_ips.conf
```

---

## 🛠️ Como Usar

No dia a dia, é só isso:

### Abrir o acesso

Conecte-se ao servidor via SSH e rode:

```bash
pma-on
```

Saída esperada:
```
✅ Acesso liberado! Nginx aceitando requisições do IP: 189.x.x.x
⏱️  Auto-Off ativado: porta tranca automaticamente em 1 hora.
```

Abra o navegador e acesse normalmente. Só você passa.

### Fechar o acesso manualmente

Terminou antes da hora? Não deixa a porta aberta:

```bash
pma-off
```

Saída esperada:
```
🔒 Acesso bloqueado. O phpMyAdmin está isolado da internet.
```

---

## ⚙️ Como Funciona por Dentro

O fluxo completo do Porteiro em 4 passos:

```
[Você faz SSH] 
      ↓
[pma-on lê $SSH_CLIENT e extrai seu IP]
      ↓
[Injeta "allow SEU_IP;" em /etc/nginx/pma_ips.conf]
      ↓
[Nginx recarrega — só você passa. Mundo leva 403.]
      ↓
[at agenda pma-off para daqui 1 hora]
      ↓
[1 hora depois: pma_ips.conf é limpo → 403 pra todo mundo de novo]
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
| Dependências externas | — | Zero |
| Configuração necessária | — | ~5 minutos |

---

## ✅ Checklist de Segurança

### Proteção ✅
- [x] Rota `/phpmyadmin/` inacessível por padrão (403)
- [x] Liberação apenas para IP autenticado via SSH
- [x] Auto-Off após 1 hora (anti-esquecimento)
- [x] Fechamento manual disponível
- [x] Sem credenciais armazenadas em disco

### Leveza ✅
- [x] Zero dependências npm/pip/gem
- [x] Zero banco de dados
- [x] Zero tokens ou chaves de API
- [x] Dois arquivos Shell Script
- [x] Funciona em qualquer VPS com Nginx

### Compatibilidade ✅
- [x] Ubuntu / Debian
- [x] Qualquer versão do PHP-FPM (ajuste o socket)
- [x] Nginx (qualquer versão recente)
- [x] Adaptável para qualquer rota sensível (não só `/phpmyadmin/`)

---

## 🔧 Configurações e Personalização

### Mudar o tempo do Auto-Off

Edite a linha do `at` dentro do `pma-on`:

```bash
# Para 2 horas:
echo "/usr/local/bin/pma-off > /dev/null 2>&1" | at now + 2 hours

# Para 30 minutos:
echo "/usr/local/bin/pma-off > /dev/null 2>&1" | at now + 30 minutes
```

### Proteger outra rota (não só phpMyAdmin)

O Porteiro funciona para qualquer rota sensível. Basta adaptar o bloco do Nginx:

```nginx
location ^~ /sua-rota-secreta/ {
    include /etc/nginx/pma_ips.conf;
    deny all;
    # ...
}
```

### Liberar múltiplos IPs

Edite o `pma-on` para adicionar IPs fixos além do seu dinâmico:

```bash
echo "allow $MEU_IP;" > /etc/nginx/pma_ips.conf
echo "allow IP_DO_SEU_ESCRITORIO;" >> /etc/nginx/pma_ips.conf
```

---

## 🚀 Roadmap (v2.0) — Próximas Melhorias

- **Log de acessos** — Registrar quem abriu e fechou a porta, com timestamp
- **Notificação por e-mail/Telegram** — Aviso quando `pma-on` é executado
- **Multi-rota** — Gerenciar múltiplas rotas sensíveis com um só script
- **Tempo configurável via argumento** — `pma-on 2h` para liberar por 2 horas
- **Suporte a Apache** — Versão equivalente para `.htaccess`
- **Desinstalador** — `uninstall.sh` que remove tudo limpo

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

Sim! O `pma-on` sempre lê o IP atual da sessão SSH ativa. Cada vez que você rodar, ele atualiza o IP automaticamente.

### E se eu fechar o terminal antes de rodar pma-off?

O Auto-Off cuida disso. Em no máximo 1 hora, o acesso é bloqueado automaticamente.

### Posso usar com Apache?

A versão atual é exclusiva para Nginx. O suporte ao Apache está no Roadmap v2.0.

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