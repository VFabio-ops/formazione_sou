# Gitea Local — Gestionale Git Self-Hosted con CI/CD

Ambiente Git self-hosted completo basato su **Gitea** e **Gitea Actions**, orchestrato da Vagrant
e virtualizzato tramite VirtualBox. Il progetto e' composto da soli due file e non richiede alcuna
configurazione manuale: un singolo comando avvia l'intera infrastruttura.

---

## Caratteristiche

- Interfaccia web completa per la gestione di repository Git
- Gestione utenti, organizzazioni e permessi granulari per team
- Pipeline CI/CD nativa tramite Gitea Actions (sintassi compatibile con GitHub Actions)
- Runner locale che esegue i job in container Docker isolati
- Database SQLite embedded: nessun servizio esterno richiesto
- Provisioning completamente automatizzato tramite shell script
- Portabile: l'intero ambiente e' definito da due file

---

## Requisiti

| Strumento  | Versione minima | Riferimento                               |
|------------|-----------------|-------------------------------------------|
| VirtualBox | 6.1             | https://www.virtualbox.org                |
| Vagrant    | 2.3             | https://developer.hashicorp.com/vagrant   |

RAM disponibile sull'host: almeno **3 GB** (2 GB allocati alla VM, il resto per il sistema host).

---

## Struttura del progetto

```
gitea-local/
├── Vagrantfile       # Definisce la VM: risorse, rete, port forwarding
└── Provision.sh      # Provisioning automatico: Gitea, Actions Runner, Docker
```

---

## Vagrantfile — spiegazione

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "gitea-local"
    vb.memory = "2048"
    vb.cpus   = 2
  end

  config.vm.hostname = "gitea"
  config.vm.network "private_network", ip: "192.168.56.10"

  config.vm.network "forwarded_port", guest: 3000, host: 3000, host_ip: "127.0.0.1"
  config.vm.network "forwarded_port", guest: 2222, host: 2201, host_ip: "127.0.0.1"

  config.vm.provision "shell", path: "Provision.sh"
end
```

| Direttiva | Scopo |
|-----------|-------|
| `config.vm.box` | Immagine base della VM: Ubuntu 22.04 LTS dal catalogo Bento (ufficiale HashiCorp). |
| `vb.memory / vb.cpus` | Alloca 2 GB di RAM e 2 CPU virtuali alla VM. |
| `vb.name` | Nome visualizzato in VirtualBox Manager. |
| `private_network ip: "192.168.56.10"` | Crea una rete privata tra host e VM con IP fisso. La VM e' raggiungibile a questo indirizzo dalla macchina host. |
| `forwarded_port guest: 3000, host: 3000` | Mappa la porta 3000 della VM (interfaccia web Gitea) su `localhost:3000` dell'host. |
| `forwarded_port guest: 2222, host: 2201` | Mappa la porta SSH interna di Gitea (2222) su `localhost:2201` dell'host. La porta interna e' 2222, quella esposta all'host e' 2201. |
| `host_ip: "127.0.0.1"` | Limita il binding delle porte solo all'interfaccia di loopback: le porte non sono esposte sulla rete locale dell'host. |
| `provision "shell", path: "Provision.sh"` | Indica a Vagrant di eseguire `Provision.sh` come root nella VM al primo `vagrant up`. |

---

## Provision.sh — spiegazione blocco per blocco

Lo script viene eseguito automaticamente come utente `root` nella VM durante il primo avvio.
Di seguito ogni blocco viene mostrato con il codice corrispondente e la spiegazione di cosa fa e perche'.

---

### Shebang e variabili

```bash
#!/usr/bin/env bash

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
```

La prima riga (`#!/usr/bin/env bash`) indica al sistema di eseguire lo script con bash.
Le variabili centralizzano tutti i parametri configurabili in un unico punto: versioni dei
software, percorsi, porte e credenziali. Per adattare l'ambiente basta modificare questa
sezione senza toccare il resto dello script.

> **Importante:** non usare `!`, `$`, `` ` `` o `\` nella password. Bash li interpreta
> prima di passarli al comando, causando una mancata corrispondenza tra la password impostata
> e quella salvata nel database di Gitea.

---

### Blocco 1 — Aggiornamento sistema e dipendenze

```bash
echo "[1/7] Aggiornamento pacchetti di sistema..."
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget git sqlite3 openssh-server supervisor
```

Aggiorna l'indice dei pacchetti e porta il sistema alla versione piu' recente, poi installa
le dipendenze necessarie all'intero stack.

| Pacchetto | Motivo |
|-----------|--------|
| `curl` | Chiamate HTTP verso le API REST di Gitea (recupero token runner). |
| `wget` | Download dei binari di Gitea e del runner. |
| `git` | Librerie Git richieste da Gitea per le operazioni sui repository. |
| `sqlite3` | Database embedded: Gitea lo usa per memorizzare utenti, repository e configurazioni senza bisogno di un server database esterno. |
| `openssh-server` | Server SSH della VM (distinto dall'SSH interno di Gitea). |
| `supervisor` | Process manager incluso per usi futuri; non attivamente usato in questo setup. |

---

### Blocco 2 — Utente di sistema

```bash
echo "[2/7] Creazione utente di sistema 'gitea'..."
adduser \
    --system \
    --shell /bin/bash \
    --gecos "Gitea" \
    --group \
    --disabled-password \
    --home /home/gitea \
    gitea
```

Crea un utente di sistema dedicato chiamato `gitea`. Gitea non deve mai girare come `root`:
in caso di vulnerabilita', un processo con privilegi minimi limita il danno potenziale.

| Flag | Effetto |
|------|---------|
| `--system` | Crea un utente di sistema (UID basso, non appare nel login). |
| `--shell /bin/bash` | Assegna una shell: necessaria per i comandi `sudo -u gitea ...` usati piu' avanti. |
| `--group` | Crea automaticamente un gruppo con lo stesso nome. |
| `--disabled-password` | Nessuna password: l'utente non puo' fare login interattivo. |
| `--home /home/gitea` | Directory home dove Gitea scrive file temporanei e di stato. |

---

### Blocco 3 — Struttura directory e chiavi

```bash
echo "[3/7] Creazione struttura directory..."
mkdir -p /opt/gitea/{custom,data,log,repos}
mkdir -p /etc/gitea
chown -R gitea:gitea /opt/gitea
chown -R root:gitea /etc/gitea
chmod 770 /etc/gitea

SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
INTERNAL_TOKEN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
```

Crea l'albero di directory dove Gitea salvera' tutti i suoi dati, poi genera due chiavi
crittografiche casuali da 64 caratteri che verranno inserite nel file di configurazione.

| Percorso | Contenuto |
|----------|-----------|
| `/opt/gitea/repos` | Repository Git degli utenti. |
| `/opt/gitea/data` | Database SQLite (`gitea.db`) e allegati. |
| `/opt/gitea/log` | File di log dell'applicazione. |
| `/opt/gitea/custom` | File di personalizzazione (template, temi). |
| `/etc/gitea` | File di configurazione `app.ini`. Permessi `770`: scrivibile solo da `root` e dal gruppo `gitea`. |
| `SECRET_KEY` | Chiave per la cifratura dei cookie di sessione. |
| `INTERNAL_TOKEN` | Token per le comunicazioni interne tra i componenti di Gitea. |

---

### Blocco 4 — Download Gitea e configurazione

```bash
echo "[4/7] Download Gitea v${GITEA_VERSION}..."
wget -q "https://dl.gitea.com/gitea/1.22.1/gitea-1.22.1-linux-amd64" \
    -O /usr/local/bin/gitea
chmod +x /usr/local/bin/gitea
```

Scarica il binario precompilato di Gitea per Linux a 64 bit direttamente dal sito ufficiale
e lo posiziona in `/usr/local/bin/gitea`, rendendolo eseguibile a livello di sistema.
L'uso di un binario singolo (nessuna dipendenza runtime) semplifica l'installazione e
l'aggiornamento futuro.

---

### Blocco 4a — File di configurazione app.ini

```bash
touch /etc/gitea/app.ini
cat > /etc/gitea/app.ini << EOF
[DEFAULT]
RUN_USER = gitea
RUN_MODE = prod

[server]
DOMAIN           = 192.168.56.10
HTTP_PORT        = 3000
ROOT_URL         = http://192.168.56.10:3000/
SSH_PORT         = 2201
SSH_LISTEN_PORT  = 2201
DISABLE_SSH      = false
START_SSH_SERVER = true
LFS_START_SERVER = true

[database]
DB_TYPE  = sqlite3
PATH     = /opt/gitea/data/gitea.db

[repository]
ROOT = /opt/gitea/repos

[log]
ROOT_PATH = /opt/gitea/log
LEVEL     = Info

[security]
INSTALL_LOCK       = true
SECRET_KEY         = <generata casualmente>
INTERNAL_TOKEN     = <generata casualmente>
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

chown gitea:gitea /etc/gitea/app.ini
chmod 640 /etc/gitea/app.ini
```

Genera il file di configurazione principale di Gitea. Ogni sezione controlla un aspetto
specifico dell'applicazione.

| Sezione | Scopo |
|---------|-------|
| `[DEFAULT]` | Utente di sistema con cui gira il processo e modalita' di esecuzione (`prod` disabilita i messaggi di debug). |
| `[server]` | Dominio, porta HTTP, URL radice e configurazione SSH. `START_SSH_SERVER = true` fa avviare a Gitea il proprio server SSH interno (separato da quello del sistema). `LFS_START_SERVER = true` abilita il supporto per file binari di grandi dimensioni. |
| `[database]` | Tipo di database (`sqlite3`) e percorso del file. SQLite non richiede un server separato ed e' sufficiente per uso locale. |
| `[repository]` | Percorso radice dove vengono creati i repository Git degli utenti. |
| `[log]` | Directory dei log e livello di verbosita' (`Info`). |
| `[security]` | `INSTALL_LOCK = true` salta la pagina di setup iniziale. `SECRET_KEY` e `INTERNAL_TOKEN` sono le chiavi generate casualmente nel blocco precedente. `pbkdf2` e' l'algoritmo di hashing delle password. |
| `[service]` | `DISABLE_REGISTRATION = false` permette la registrazione di nuovi utenti. `DEFAULT_KEEP_EMAIL_PRIVATE = true` nasconde l'email degli utenti per impostazione predefinita. |
| `[actions]` | `ENABLED = true` attiva il motore CI/CD di Gitea Actions. |
| `[picture]` | `DISABLE_GRAVATAR = true` evita richieste esterne a Gravatar per gli avatar. |
| `[ui]` | Imposta il tema scuro come predefinito per tutti gli utenti. |

Dopo la scrittura, i permessi `640` (leggibile da `gitea`, non da altri utenti) proteggono
le chiavi crittografiche contenute nel file.

---

### Blocco 4b — Servizio systemd per Gitea

```bash
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
```

Registra Gitea come servizio del sistema operativo tramite systemd, in modo che si avvii
automaticamente ad ogni boot della VM e venga riavviato in caso di crash.

Il file viene scritto riga per riga con `printf` anziche' con un heredoc: le sezioni
`[Unit]`, `[Service]` e `[Install]` verrebbero altrimenti interpretate da bash come
comandi di shell, causando errori.

| Direttiva systemd | Effetto |
|-------------------|---------|
| `After=network.target` | Garantisce che la rete sia disponibile prima dell'avvio di Gitea. |
| `User` / `Group` | Gitea gira con i privilegi minimi dell'utente `gitea`. |
| `ExecStart` | Comando di avvio con il percorso del file di configurazione. |
| `Restart=always` | Riavvia il processo automaticamente in caso di crash. |
| `RestartSec=2s` | Attende 2 secondi prima di ogni riavvio automatico. |
| `Environment` | Variabili d'ambiente necessarie a Gitea per trovare home e directory dati. |
| `WantedBy=multi-user.target` | Il servizio si avvia nel normale runlevel multiutente. |

Dopo la scrittura del file, `systemctl daemon-reload` ricarica la configurazione di systemd,
`systemctl enable` attiva l'avvio automatico al boot e `systemctl start` avvia subito il servizio.

---

### Blocco 5 — Creazione utente amministratore

```bash
echo "[5/7] Creazione utente amministratore..."
sudo -u gitea gitea admin user create \
    --config /etc/gitea/app.ini \
    --username admin \
    --password Admin123 \
    --email admin@local.dev \
    --admin \
    --must-change-password=false
```

Crea l'utente amministratore tramite la CLI di Gitea, senza dover passare dall'interfaccia web.
Il comando viene eseguito come utente `gitea` (`sudo -u gitea`) per garantire i permessi corretti
sui file del database.

Il flag `--admin` assegna i privilegi di amministratore completo. Il flag
`--must-change-password=false` permette il primo accesso senza forzare il cambio password.

---

### Blocco 6 — Gitea Actions Runner

```bash
echo "[6/7] Download Gitea Actions Runner v${RUNNER_VERSION}..."
wget -q "https://dl.gitea.com/act_runner/0.2.11/act_runner-0.2.11-linux-amd64" \
    -O /usr/local/bin/act_runner
chmod +x /usr/local/bin/act_runner

RUNNER_TOKEN=$(curl -s -X POST \
    "http://127.0.0.1:3000/api/v1/user/actions/runners/registration-token" \
    -u "admin:Admin123" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

act_runner register \
    --no-interactive \
    --instance "http://127.0.0.1:3000" \
    --token "$RUNNER_TOKEN" \
    --name "local-runner" \
    --labels "ubuntu-latest:docker://node:16-bullseye"
```

Il runner e' il processo che esegue materialmente i job delle pipeline CI/CD. Si registra
presso l'istanza Gitea locale e resta in ascolto di nuovi job da eseguire.

**Download:** il binario `act_runner` viene scaricato dal sito ufficiale e reso eseguibile,
esattamente come Gitea.

**Recupero token:** l'API REST di Gitea restituisce un token di registrazione monouso.
Il token viene estratto dalla risposta JSON con `grep` e `cut` e memorizzato nella variabile
`RUNNER_TOKEN`.

**Registrazione:** il runner si registra presso l'istanza locale con il token appena ottenuto.
Il parametro `--labels` definisce le etichette con cui il runner si annuncia: `ubuntu-latest`
e' il nome usato nei file YAML delle pipeline (`runs-on: ubuntu-latest`); il valore dopo
i due punti indica l'immagine Docker usata per eseguire i job.

---

### Blocco 6b — Servizio systemd per il Runner

```bash
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
```

Registra il runner come servizio systemd con le stesse motivazioni viste per Gitea.

Le direttive `After=gitea.service` e `Requires=gitea.service` garantiscono che il runner
non parta mai prima che Gitea sia avviato: se Gitea si ferma, systemd ferma anche il runner.
La modalita' `daemon` mantiene il processo in esecuzione continua in attesa di nuovi job.

---

### Blocco 7 — Docker

```bash
echo "[7/7] Installazione Docker per Gitea Actions..."
apt-get install -y docker.io
usermod -aG docker gitea
systemctl enable docker && systemctl start docker
```

I job delle pipeline CI/CD vengono eseguiti all'interno di container Docker isolati.
Ogni job ottiene un ambiente pulito e riproducibile, indipendente dallo stato della VM.

`usermod -aG docker gitea` aggiunge l'utente `gitea` al gruppo `docker`: senza questo
passaggio il runner non potrebbe avviare container perche' il socket Docker
(`/var/run/docker.sock`) e' accessibile solo a `root` e ai membri del gruppo `docker`.

---

## Avvio

```bash
git clone <url-del-repo>
cd gitea-local
vagrant up
```

Il provisioning viene eseguito automaticamente al primo `vagrant up` e richiede circa
**5-10 minuti** a seconda della connessione di rete.

---

## Accesso ai servizi

| Servizio        | Indirizzo                              |
|-----------------|----------------------------------------|
| Interfaccia web | http://localhost:3000                  |
| Clone HTTPS     | http://localhost:3000/utente/repo.git  |
| Clone SSH       | ssh://git@localhost:2201/utente/repo   |

Credenziali amministratore predefinite:

```
Username : admin
Password : Admin123
```

Cambia la password al primo accesso da `Impostazioni utente -> Password`.

---

## Pipeline CI/CD

Crea il file `.gitea/workflows/ci.yml` nel repository:

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configurazione Node.js
        uses: actions/setup-node@v3
        with:
          node-version: "18"

      - name: Installazione dipendenze
        run: npm install

      - name: Esecuzione test
        run: npm test
```

```bash
git add .gitea/workflows/ci.yml
git commit -m "Aggiunta pipeline CI"
git push
```

Lo stato di esecuzione e' visibile nella scheda **Actions** del repository.
Per verificare che il runner sia online:

```
Impostazioni (icona utente) -> Pannello di amministrazione -> Actions -> Runner
```

---

## Gestione utenti e permessi

### Creare un nuovo utente

```
Pannello di amministrazione -> Gestione utenti -> Crea account utente
```

Per disabilitare la registrazione pubblica, modifica in `Provision.sh` la sezione `[service]`
dell'`app.ini`:

```ini
DISABLE_REGISTRATION = true
```

### Organizzazioni e team

Le organizzazioni raggruppano repository e utenti. I livelli di accesso disponibili per i team
sono: **Lettura**, **Scrittura**, **Amministratore**.

Percorso: `Menu + -> Nuova organizzazione -> Team -> Crea team`

### Permessi per singolo repository

```
Repository -> Impostazioni -> Collaboratori -> Aggiungi collaboratore
```

---

## Comandi Vagrant

| Comando             | Descrizione                                              |
|---------------------|----------------------------------------------------------|
| `vagrant up`        | Avvia la VM; esegue il provisioning al primo avvio       |
| `vagrant halt`      | Spegne la VM preservando i dati                          |
| `vagrant destroy`   | Elimina la VM e tutti i dati                             |
| `vagrant reload`    | Riavvia la VM ricaricando il Vagrantfile                 |
| `vagrant provision` | Riesegue Provision.sh su una VM gia' in esecuzione       |
| `vagrant ssh`       | Apre una sessione SSH nella VM                           |
| `vagrant status`    | Mostra lo stato corrente della VM                        |
| `vagrant suspend`   | Sospende la VM salvando lo stato in memoria              |
| `vagrant resume`    | Riprende una VM sospesa                                  |

---

## Diagnostica

Dall'interno della VM (`vagrant ssh`):

```bash
# Stato dei servizi
sudo systemctl status gitea
sudo systemctl status gitea-runner

# Log in tempo reale
sudo journalctl -u gitea -f
sudo journalctl -u gitea-runner -f

# Verifica risposta HTTP
curl -I http://127.0.0.1:3000
```

---

## Problemi noti

**Credenziali amministratore non accettate**
Il carattere `!` e altri caratteri speciali nella password vengono interpretati da bash durante
la creazione dell'utente, causando una mancata corrispondenza con quanto salvato nel database.
Usare solo caratteri alfanumerici e i simboli `-`, `_`, `.` nella variabile `ADMIN_PASSWORD`.
Per reimpostare la password senza ricreare la VM:

```bash
vagrant ssh
sudo -u gitea GITEA_WORK_DIR=/opt/gitea gitea admin user change-password \
    --config /etc/gitea/app.ini \
    --username admin \
    --password "NuovaPassword"
```

**Runner non registrato**
Se la registrazione automatica del runner fallisce durante il provisioning, recupera il token
da `Impostazioni -> Actions -> Runner` e registra manualmente:

```bash
vagrant ssh
sudo -u gitea act_runner register \
    --no-interactive \
    --instance "http://127.0.0.1:3000" \
    --token "TOKEN" \
    --name "local-runner" \
    --labels "ubuntu-latest:docker://node:16-bullseye"
sudo systemctl restart gitea-runner
```

**Porta gia' in uso**
Se la porta `3000` o `2201` e' occupata sull'host, modifica il valore `host:` nel Vagrantfile
e riavvia con `vagrant reload`.

**Conflitto IP sulla rete privata**
Se l'IP `192.168.56.10` e' gia' assegnato a un'altra VM, modificalo nel Vagrantfile e aggiorna
la variabile `DOMAIN` in `Provision.sh` con lo stesso valore, poi esegui:

```bash
vagrant destroy -f && vagrant up
```

**Provisioning interrotto per mancanza di memoria**
Riduci temporaneamente `vb.memory` nel Vagrantfile da `2048` a `1024`. Le funzionalita' di base
restano operative; i job CI/CD con container pesanti potrebbero risultare instabili.

---

## Versioni software

| Software     | Versione  |
|--------------|-----------|
| Gitea        | 1.22.1    |
| Gitea Runner | 0.2.11    |
| Ubuntu       | 22.04 LTS |
| VirtualBox   | >= 6.1    |
| Vagrant      | >= 2.3    |
