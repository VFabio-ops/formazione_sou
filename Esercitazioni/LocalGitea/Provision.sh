#!/usr/bin/env bash
# Andiamo a definire le variabili per il nostro progetto

GITEA_VERSION="1.22.1"
RUNNER_VERSION="0.2.11"
GITEA_USER="gitea"
GITEA_HOME="/home/gitea"
GITEA_DATA="/opt/gitea"
GITEA_PORT=3000
GITEA_SSH_PORT=2201
DOMAIN="192.168.56.10"

ADMIN_USER="admin"
ADMIN_PASSWORD="Admin123"
ADMIN_EMAIL="admin@local.dev"


# 1 Aggiornamento pacchetti e installazione dipendenze
echo "[1/7] Aggiornamento pacchetti di sistema..."
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget git sqlite3 openssh-server supervisor

# 2 Creazione utente di sistema dedicato
echo "[2/7] Creazione utente di sistema 'gitea'..."
adduser \
    --system \
    --shell /bin/bash \
    --gecos "Gitea" \
    --group \
    --disabled-password \
    --home /home/gitea \
    gitea


# 3 Creazione directory per Gitea
echo "[3/7] Creazione struttura directory..."
mkdir -p /opt/gitea/{custom,data,log,repos}
mkdir -p /etc/gitea
chown -R gitea:gitea /opt/gitea
chown -R root:gitea /etc/gitea
chmod 770 /etc/gitea

# Generazione chiavi casuali
SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
INTERNAL_TOKEN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)

# 4 Download binary da Gitea e lo rende eseguibile
echo "[4/7] Download Gitea v${GITEA_VERSION}..."
wget -q "https://dl.gitea.com/gitea/1.22.1/gitea-1.22.1-linux-amd64" -O /usr/local/bin/gitea
chmod +x /usr/local/bin/gitea

# Viene generato e configurato il file /etc/gitea/app.ini insieme al servizio systemd per avviare Gitea all'avvio del sistema.
# Configurazione app.ini (heredoc con 'EOF' quotato per bloccare l'espansione,
# poi sostituzione separata per le variabili shell)
touch /etc/gitea/app.ini
cat > /etc/gitea/app.ini << EOF
[DEFAULT]
RUN_USER = ${GITEA_USER}
RUN_MODE = prod
 
[server]
DOMAIN           = ${DOMAIN}
HTTP_PORT        = ${GITEA_PORT}
ROOT_URL         = http://${DOMAIN}:${GITEA_PORT}/
SSH_PORT         = ${GITEA_SSH_PORT}
SSH_LISTEN_PORT  = ${GITEA_SSH_PORT}
DISABLE_SSH      = false
START_SSH_SERVER = true
LFS_START_SERVER = true
 
[database]
DB_TYPE  = sqlite3
PATH     = ${GITEA_DATA}/data/gitea.db
 
[repository]
ROOT = ${GITEA_DATA}/repos
 
[log]
ROOT_PATH = ${GITEA_DATA}/log
LEVEL     = Info
 
[security]
INSTALL_LOCK       = true
SECRET_KEY         = ${SECRET_KEY}
INTERNAL_TOKEN     = ${INTERNAL_TOKEN}
PASSWORD_HASH_ALGO = pbkdf2
 
[service]
DISABLE_REGISTRATION             = false
REQUIRE_SIGNIN_VIEW              = false
REGISTER_EMAIL_CONFIRM           = false
ENABLE_NOTIFY_MAIL               = false
ALLOW_ONLY_EXTERNAL_REGISTRATION = false
DEFAULT_KEEP_EMAIL_PRIVATE       = true
 
[actions]
ENABLED = true
 
[picture]
DISABLE_GRAVATAR = true
 
[ui]
DEFAULT_THEME = gitea-dark
EOF
 
chown "${GITEA_USER}":"${GITEA_USER}" /etc/gitea/app.ini
chmod 640 /etc/gitea/app.ini

GITEA_SERVICE_FILE="/etc/systemd/system/gitea.service"
printf '[Unit]\n' > "${GITEA_SERVICE_FILE}"
printf 'Description=Gitea (Git with a cup of tea)\n' >> "${GITEA_SERVICE_FILE}"
printf 'After=network.target\n\n' >> "${GITEA_SERVICE_FILE}"
printf '[Service]\n' >> "${GITEA_SERVICE_FILE}"
printf 'RestartSec=2s\n' >> "${GITEA_SERVICE_FILE}"
printf 'Type=simple\n' >> "${GITEA_SERVICE_FILE}"
printf "User=%s\n" "${GITEA_USER}" >> "${GITEA_SERVICE_FILE}"
printf "Group=%s\n" "${GITEA_USER}" >> "${GITEA_SERVICE_FILE}"
printf "WorkingDirectory=%s\n" "${GITEA_HOME}" >> "${GITEA_SERVICE_FILE}"
printf 'ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini\n' >> "${GITEA_SERVICE_FILE}"
printf 'Restart=always\n' >> "${GITEA_SERVICE_FILE}"
printf "Environment=USER=%s HOME=%s GITEA_WORK_DIR=%s\n\n" \
    "${GITEA_USER}" "${GITEA_HOME}" "${GITEA_DATA}" >> "${GITEA_SERVICE_FILE}"
printf '[Install]\n' >> "${GITEA_SERVICE_FILE}"
printf 'WantedBy=multi-user.target\n' >> "${GITEA_SERVICE_FILE}"

systemctl daemon-reload
systemctl enable gitea
systemctl start gitea

# 5 Creazione admin tramite CLI all'avvio di Gitea
echo "[5/7] Creazione utente amministratore..."
sudo -u gitea fitea admin user create \
--config /etc/gitea/app.ini \
--username admin \
--password Admin123 \
--email admin@local.dev \
--admin \
--must-change-password=false

# 6 Installazione e configurazione runner
# Download binary del runner e lo rende eseguibile
echo "[6/7] Download Gitea Actions Runner v${RUNNER_VERSION}..."
wget -q "https://dl.gitea.com/act_runner/0.2.11/act_runner-0.2.11-linux-amd64" -O /usr/local/bin/act_runner
chmod +x /usr/local/bin/act_runner

# Recupero token del runner

RUNNER_TOKEN=$(curl -s -X POST "http://127.0.0.1:3000/api/v1/user/actions/runners/registration-token" -u "admin:Admin@123" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

# Registra il runner
act_runner register \
    --no-interactive \
    --instance "http://127.0.0.1:3000" \ 
    --token "$RUNNER_TOKEN" \
    --name "local-runner" \
    --labels "ubuntu-latest:docker://node:16-bullseye"


# Servizio systemd per il runner

RUNNER_SERVICE_FILE="/etc/systemd/system/gitea-runner.service"
printf '[Unit]\n' > "${RUNNER_SERVICE_FILE}"
printf 'Description=Gitea Actions Runner\n' >> "${RUNNER_SERVICE_FILE}"
printf 'After=gitea.service\n' >> "${RUNNER_SERVICE_FILE}"
printf 'Requires=gitea.service\n\n' >> "${RUNNER_SERVICE_FILE}"
printf '[Service]\n' >> "${RUNNER_SERVICE_FILE}"
printf 'Type=simple\n' >> "${RUNNER_SERVICE_FILE}"
printf "User=%s\n" "${GITEA_USER}" >> "${RUNNER_SERVICE_FILE}"
printf "Group=%s\n" "${GITEA_USER}" >> "${RUNNER_SERVICE_FILE}"
printf "WorkingDirectory=%s\n" "${RUNNER_DIR}" >> "${RUNNER_SERVICE_FILE}"
printf 'ExecStart=/usr/local/bin/act_runner daemon\n' >> "${RUNNER_SERVICE_FILE}"
printf 'Restart=always\n' >> "${RUNNER_SERVICE_FILE}"
printf 'RestartSec=5s\n\n' >> "${RUNNER_SERVICE_FILE}"
printf '[Install]\n' >> "${RUNNER_SERVICE_FILE}"
printf 'WantedBy=multi-user.target\n' >> "${RUNNER_SERVICE_FILE}"
 
systemctl daemon-reload
systemctl enable gitea-runner
systemctl start gitea-runner
 

# 7 Installazione Docker
echo "[7/7] Installazione Docker per Gitea Actions..."
apt-get install -y docker.io
usermod -aG docker gitea
systemctl enable docker && systemctl start docker

# ---------------------------------------------------------------------------
# Riepilogo
# ---------------------------------------------------------------------------
echo ""
echo "======================================================================"
echo "  Installazione completata."
echo "======================================================================"
echo ""
echo "  Interfaccia web : http://localhost:3000"
echo "  SSH Git          : ssh://git@localhost:2201"
echo ""
echo "  Credenziali amministratore:"
echo "    Username : ${ADMIN_USER}"
echo "    Password : ${ADMIN_PASSWORD}"
echo ""
echo "  Gitea Actions Runner: abilitato (label: ubuntu-latest)"
echo ""
echo "  Per accedere alla VM:"
echo "    vagrant ssh"
echo ""
echo "  Per verificare i servizi:"
echo "    sudo systemctl status gitea"
echo "    sudo systemctl status gitea-runner"
echo "======================================================================"