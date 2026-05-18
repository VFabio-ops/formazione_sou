# Web Radio locale Guida
### Stack: Vagrant + Ubuntu 22.04 + Apache + AzuraCast (Docker)

> Guida completa per installare, configurare e risolvere i problemi di una web radio locale con supporto a playlist automatiche e dirette live.

---

## Architettura

```
Il tuo PC (host)
│
├── Browser / BUTT (client)
│
└── Vagrant
    └── VM Ubuntu 22.04 — 192.168.56.10
        ├── Apache :80          ← reverse proxy
        └── AzuraCast :8000     ← pannello web
            ├── Liquidsoap      ← gestione playlist e mix
            └── Icecast :8080   ← streaming audio (mount: /radio.mp3)
```

Il flusso di una richiesta:
```
Browser → Apache :80 → (proxy) → AzuraCast :8000
BUTT    → Icecast :8005 (porta live streamer)
Ascoltatore → http://192.168.56.10/radio.mp3
```

---

## Prerequisiti

Installare sul PC host prima di tutto:

| Software | Link | Note |
|---|---|---|
| VirtualBox | https://www.virtualbox.org | Hypervisor gratuito |
| Vagrant | https://www.vagrantup.com | Orchestratore VM |

Verifica:
```bash
vagrant --version
VBoxManage --version
```

---

## Installazione

### Passo 1 — Creare il progetto Vagrant

```bash
mkdir web-radio && cd web-radio
vagrant init ubuntu/jammy64
```

Sostituisci il `Vagrantfile` generato con il seguente:

```ruby
Vagrant.configure("2") do |config|

  config.vm.box      = "ubuntu/jammy64"
  config.vm.hostname = "web-radio"

  # Rete privata: la VM sarà raggiungibile su http://192.168.56.10
  config.vm.network "private_network", ip: "192.168.56.10"

  # Port forwarding (accesso alternativo da localhost)
  config.vm.network "forwarded_port", guest: 80,   host: 8080, host_ip: "127.0.0.1"
  config.vm.network "forwarded_port", guest: 8000, host: 8000, host_ip: "127.0.0.1"
  config.vm.network "forwarded_port", guest: 8005, host: 8005, host_ip: "127.0.0.1"

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "web-radio"
    vb.memory = "2048"
    vb.cpus   = 2
  end

  config.vm.provision "shell", inline: <<-SHELL
    apt-get update -qq && apt-get upgrade -y -qq

    # --- Apache ---
    apt-get install -y apache2
    a2enmod proxy proxy_http proxy_wstunnel headers rewrite
    systemctl enable apache2

    # --- Docker (repository ufficiale, NON docker.io da apt) ---
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
      gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin
    usermod -aG docker vagrant

    # --- AzuraCast ---
    mkdir -p /var/azuracast
    cd /var/azuracast
    curl -fsSL https://raw.githubusercontent.com/AzuraCast/AzuraCast/stable/docker.sh \
      -o docker.sh
    chmod +x docker.sh

    echo "Provisioning completato. Esegui: vagrant ssh, poi cd /var/azuracast && sudo ./docker.sh install"
  SHELL

end
```

### Passo 2 — Avviare la VM

```bash
vagrant up        # primo avvio ~10 minuti
vagrant ssh       # entra nella VM
```

### Passo 3 — Installare AzuraCast

Dentro la VM:

```bash
cd /var/azuracast
sudo ./docker.sh install
```

Durante l'installazione:
- **HTTPS?** → `n`
- **Porta HTTP?** → `8000`
- **Porta HTTPS?** → `8443`

### Passo 4 — Setup headless (senza browser)

Se il server non è raggiungibile via browser, usa le variabili di ambiente:

```bash
sudo docker compose down

sudo nano /var/azuracast/azuracast.env
# Aggiungi in fondo:
# INIT_BASE_URL=http://192.168.56.10
# INIT_INSTANCE_NAME="La Mia Web Radio"
# INIT_ADMIN_EMAIL=tuo@email.com
# INIT_ADMIN_PASSWORD=UnaPasswordSicura123!

sudo docker compose up -d
sudo docker compose logs -f azuracast   # attendi "Setup complete"
```

Verifica account creato:
```bash
sudo ./docker.sh cli azuracast:account:list
```

Rimuovi le variabili INIT dal .env dopo la creazione e riavvia:
```bash
sudo docker compose restart
```

---

## Configurazione Apache

Crea il virtual host:

```bash
sudo nano /etc/apache2/sites-available/radio.conf
```

```apache
<VirtualHost *:80>
    ServerName radio.local
    ServerAlias 192.168.56.10

    ErrorLog  ${APACHE_LOG_DIR}/radio_error.log
    CustomLog ${APACHE_LOG_DIR}/radio_access.log combined

    ProxyPreserveHost On
    ProxyRequests    Off

    ProxyPass        / http://127.0.0.1:8000/
    ProxyPassReverse / http://127.0.0.1:8000/

    # WebSocket per le dirette live
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) ws://127.0.0.1:8000/$1 [P,L]

    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
</VirtualHost>
```

```bash
sudo a2ensite radio.conf
sudo a2dissite 000-default.conf
sudo apache2ctl configtest
sudo systemctl restart apache2
```

File hosts sul PC host (opzionale):
```
# Linux/Mac: /etc/hosts
# Windows: C:\Windows\System32\drivers\etc\hosts
192.168.56.10   radio.local
```

---

## Setup AzuraCast

### Accesso al pannello

```
http://radio.local        (se configurato il file hosts)
http://192.168.56.10      (IP diretto)
```

### Configurare la porta di Icecast

> La porta di default di Icecast è `8000`, ma quella porta è già usata dal processo web di AzuraCast. Va cambiata obbligatoriamente.

Nel pannello:
1. **Stazioni** → **Modifica stazione** → scheda **Frontend (Broadcasting)**
2. Cambia porta Icecast da `8000` → `8080`
3. Salva e riavvia la stazione

---

## Musica e Playlist

1. **Media** → carica file MP3/FLAC/OGG → attendi il processing
2. **Playlists** → crea playlist → aggiungi i brani caricati
3. Imposta tipo playlist su **General Rotation** e abilitala
4. **Stazioni** → riavvia la stazione
5. Testa lo stream:

```bash
curl -v http://192.168.56.10:8080/radio.mp3
# Deve restituire 200 e iniziare a ricevere dati audio
```

---

## Dirette Live

Usa **BUTT** (Broadcast Using This Tool): https://danielnoethen.de/butt/

Configurazione in BUTT:
- **Server:** `192.168.56.10`
- **Port:** `8005` (porta live streamer di AzuraCast)
- **Password:** recuperala da AzuraCast → Stazione → Mount Points

In AzuraCast: **Stazione** → **Streamer/DJ** → crea un account DJ con username e password.

---

## Troubleshooting

### Errore: `'name' does not match any of the regexes: '^x-'`

**Sintomo:** `sudo ./docker.sh install` fallisce con questo errore.

**Causa:** La versione di `docker-compose` installata da `apt` (pacchetto `docker.io`) è troppo vecchia e non supporta il campo `name:` nel `docker-compose.yml` di AzuraCast.

**Soluzione:** Rimuovere il docker-compose vecchio e installare Docker Compose V2 dal repository ufficiale Docker.

```bash
# Rimuovi versione vecchia
sudo apt-get remove -y docker docker.io docker-compose
sudo rm -f /usr/local/bin/docker-compose

# Installa Docker dal repository ufficiale
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker vagrant
```

Verifica:
```bash
docker compose version   # deve mostrare v2.x.x (senza trattino)
```

**Riferimenti:**
- https://docs.docker.com/engine/install/ubuntu/
- https://github.com/AzuraCast/AzuraCast/issues (ricerca "name does not match")

---

### Errore: `Command "azuracast:account:create" is not defined`

**Sintomo:** Il comando CLI non esiste nelle versioni recenti di AzuraCast.

**Causa:** AzuraCast ha rinominato e rimosso alcuni comandi CLI nelle versioni più recenti. `azuracast:account:create` non esiste più.

**Soluzione:** Usare le variabili `INIT_*` nel file `azuracast.env` per il setup headless iniziale, oppure generare un login token se l'account esiste già.

```bash
# Se l'account esiste già
sudo ./docker.sh cli azuracast:account:login-token tuo@email.com

# Se l'account NON esiste (lista vuota)
# → usare il metodo azuracast.env descritto nel Passo 4
```

Comandi account disponibili nelle versioni recenti:
```
azuracast:account:list
azuracast:account:login-token
azuracast:account:reset-password
azuracast:account:set-administrator
```

**Riferimenti:**
- https://docs.azuracast.com/en/administration/command-line-interface
- https://www.azuracast.com/docs/developers/getting-started/

---

### Errore: AzuraCast mostra l'IP pubblico invece di quello della VM

**Sintomo:** Al termine dell'installazione appare `Visita http://188.x.x.x` (IP pubblico del server) invece di `http://192.168.56.10`.

**Causa:** Durante il setup, AzuraCast ha rilevato automaticamente l'IP dell'interfaccia di rete principale (`enp0s3`, NAT di VirtualBox) invece della rete privata.

**Soluzione:**

```bash
cd /var/azuracast
sudo ./docker.sh cli azuracast:settings:set base_url http://192.168.56.10
sudo docker compose restart
```

Se il pannello non è raggiungibile, usa il tunnel SSH dal PC host:
```bash
ssh -L 8080:localhost:80 utente@IP_SERVER
# Poi apri http://localhost:8080 nel browser
```

---

### Errore: `Could not create listener socket on port 8000` (Icecast)

**Sintomo:** Il log `/var/azuracast/stations/webradio/config/icecast.log` mostra in loop:
```
EROR connection/connection_setup_sockets Could not create listener socket on port 8000
EROR main/fatal_error Server startup failed. Exiting
```

**Causa:** Icecast è configurato di default per usare la porta `8000`, ma quella stessa porta è già occupata dal processo web di AzuraCast (il pannello di amministrazione).

**Soluzione:** Cambiare la porta di Icecast dal pannello web:

1. **Stazioni** → **Modifica stazione** → scheda **Frontend (Broadcasting)**
2. Porta Icecast: `8000` → `8080`
3. Salva → riavvia la stazione

Verifica:
```bash
# Dentro il container Docker
sudo docker exec -it azuracast bash
tail -f /var/azuracast/stations/webradio/config/icecast.log
# Deve apparire: "server started" senza errori
```

---

### Errore: `Queue is empty!` — nessun audio dallo stream

**Sintomo:** Il log di Liquidsoap mostra in loop:
```
API nextsong - Response (400): {"message":"Queue is empty!"}
local_1: Connection failed: 404, Not Found
```

**Causa:** Liquidsoap funziona correttamente, ma non trova brani da riprodurre perché non è stato caricato nessun file media nella stazione, oppure la playlist è vuota o disabilitata.

**Soluzione:**

1. Dal pannello web → **Media** → carica file MP3/FLAC
2. Attendi il completamento del processing (indicatore verde)
3. **Playlists** → apri la playlist → **Aggiungi media** → seleziona i brani
4. Verifica che la playlist sia di tipo **General Rotation** e sia **abilitata**
5. **Stazioni** → riavvia la stazione

Verifica stream attivo:
```bash
curl -s -o /dev/null -w "%{http_code}" http://192.168.56.10:8080/radio.mp3
# 200 = stream attivo, 404 = ancora nessun audio
```

---

### BUTT non si connette alla porta 8005

**Sintomo:** BUTT non riesce a stabilire la connessione per la diretta live.

**Causa:** La porta del live streamer in BUTT non corrisponde a quella configurata in AzuraCast, oppure Icecast non è ancora partito (vedi errore precedente).

**Soluzione:**

1. Risolvi prima il problema di Icecast (porta 8000 → 8080)
2. In AzuraCast → **Stazione** → **Mount Points**: annota la porta esatta del mount point live (di default `8005`)
3. In BUTT: Server `192.168.56.10`, Port `8005`, Password da AzuraCast → Streamer/DJ

---

## Comandi utili

### Vagrant (dal PC host)

```bash
vagrant up          # avvia la VM
vagrant ssh         # entra nella VM
vagrant halt        # spegni la VM
vagrant suspend     # sospendi (salva stato)
vagrant resume      # riprendi dopo sospensione
vagrant reload      # riavvia e ricarica Vagrantfile
vagrant destroy     # elimina la VM (ATTENZIONE: distrugge tutto)
```

### AzuraCast (dentro la VM)

```bash
cd /var/azuracast

sudo ./docker.sh cli azuracast:account:list              # lista account
sudo ./docker.sh cli azuracast:account:login-token EMAIL # link login temporaneo
sudo ./docker.sh cli azuracast:account:reset-password EMAIL
sudo ./docker.sh cli azuracast:account:set-administrator EMAIL
sudo ./docker.sh cli azuracast:settings:list             # lista impostazioni
sudo ./docker.sh cli azuracast:settings:set CHIAVE VALORE
sudo ./docker.sh cli azuracast:radio:restart             # riavvia stazioni
sudo ./docker.sh ps                                      # stato container
sudo ./docker.sh logs                                    # log in tempo reale
sudo ./docker.sh update                                  # aggiorna AzuraCast
```

### Docker (dentro la VM)

```bash
sudo docker compose up -d        # avvia container
sudo docker compose down         # ferma container
sudo docker compose restart      # riavvia container
sudo docker compose logs -f      # log in tempo reale
sudo docker exec -it azuracast bash   # shell dentro il container
sudo docker ps --format "table {{.Names}}\t{{.Ports}}"  # porte esposte
```

### Log da monitorare

```bash
# Dentro il container (sudo docker exec -it azuracast bash)
tail -f /var/azuracast/stations/webradio/config/icecast.log
tail -f /var/azuracast/stations/webradio/config/liquidsoap.log

# Apache (fuori dal container)
sudo tail -f /var/log/apache2/radio_error.log
sudo tail -f /var/log/apache2/radio_access.log
```

---

## Schema porte

| Servizio | Porta interna | Accessibile da |
|---|---|---|
| AzuraCast pannello web | 8000 | http://192.168.56.10 (via Apache :80) |
| Apache reverse proxy | 80 | http://radio.local |
| Icecast streaming | 8080 | http://192.168.56.10/public/webradio |
| Live streamer (BUTT) | 8005 | 192.168.56.10:8005 |
| AzuraCast SFTP | 2022 | sftp://192.168.56.10:2022 |

---

## Riferimenti e risorse

### Documentazione ufficiale

| Risorsa | URL |
|---|---|
| AzuraCast — Installazione Docker | https://www.azuracast.com/docs/getting-started/installation/docker/ |
| AzuraCast — CLI Reference | https://docs.azuracast.com/en/administration/command-line-interface |
| AzuraCast — Setup headless (variabili INIT_*) | https://www.azuracast.com/docs/developers/getting-started/ |
| Docker — Installazione Ubuntu ufficiale | https://docs.docker.com/engine/install/ubuntu/ |
| Apache — mod_proxy | https://httpd.apache.org/docs/2.4/mod/mod_proxy.html |
| Vagrant — Documentazione | https://developer.hashicorp.com/vagrant/docs |

### Guide italiane consultate

| Risorsa | URL |
|---|---|
| ITHost — Guida tecnica web radio | https://www.ithost.it/it/guide/streaming/creare-una-web-radio |
| RadioSpeaker — Strumentazione low budget | https://www.radiospeaker.it/blog/web-radio-strumentazione-low-budget/ |
| PartitaIVA — Aspetti legali web radio | https://www.partitaiva.it/come-aprire-radio/ |

### Problemi specifici risolti

| Problema | Fonte |
|---|---|
| Docker Compose V2 vs V1 (errore `name`) | https://docs.docker.com/compose/releases/migrate/ |
| AzuraCast headless setup con `azuracast.env` | https://github.com/AzuraCast/php-api-client/blob/main/azuracast.env |
| CLI comandi disponibili versioni recenti | https://docs.azuracast.com/en/administration/command-line-interface |

### Software utilizzato

| Software | URL | Uso |
|---|---|---|
| BUTT (Broadcast Using This Tool) | https://danielnoethen.de/butt/ | Client per dirette live |
| VirtualBox | https://www.virtualbox.org | Hypervisor |
| Vagrant | https://www.vagrantup.com | Orchestrazione VM |
| AzuraCast | https://www.azuracast.com | Pannello web radio |
