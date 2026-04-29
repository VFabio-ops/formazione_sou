Benvenuti nella repository DevOps della #6 edizione Academy Sourcesense S.p.A.
# 📚 formazione_sou

Repository dedicata alla formazione, contenente esercitazioni pratiche e script Bash commentati su temi fondamentali di amministrazione di sistema Linux, sicurezza e gestione dei permessi.

---

## 📁 Struttura della Repository

```
formazione_sou/
├── esercizi/               # Esercitazioni pratiche svolte
│   ├── ssl_certificate/    # Certificazione SSL/TLS
│   ├── git_conflict/       # Gestione conflitti Git
│   ├── ssh_key_exchange/   # Scambio chiavi SSH
│   └── sudo_impersonation/ # Impersonificazione sudo nel file sudoers
│
└── Script_Sourcesense/            # Script Bash da analizzare e commentare

```

---

## 🧪 Esercitazioni

### 1. 🔐 Certificazione SSL

Questa esercitazione guida alla creazione e gestione di certificati SSL/TLS, fondamentali per garantire comunicazioni sicure e cifrate tra client e server.

**Argomenti trattati:**
- Differenza tra certificati **self-signed** e certificati firmati da una **CA (Certificate Authority)**
- Utilizzo di `openssl` per la generazione di chiavi private e certificati
- Configurazione di un server web (es. Nginx/Apache) con supporto HTTPS
- Verifica e ispezione di un certificato SSL

**Comandi principali utilizzati:**
```bash
# Generazione di una chiave privata RSA a 2048 bit
openssl genrsa -out server.key 2048

# Creazione di un Certificate Signing Request (CSR)
openssl req -new -key server.key -out server.csr

# Generazione di un certificato self-signed valido 365 giorni
openssl req -x509 -days 365 -key server.key -in server.csr -out server.crt

# Ispezione del certificato
openssl x509 -in server.crt -text -noout
```

---

### 2. ⚔️ Gestione di un Conflitto Git

Questa esercitazione simula e risolve un conflitto Git, una delle situazioni più comuni nel lavoro collaborativo su repository condivise.

**Argomenti trattati:**
- Comprensione di come nascono i conflitti (modifiche concorrenti sullo stesso file/riga)
- Lettura e interpretazione dei marcatori di conflitto (`<<<<<<<`, `=======`, `>>>>>>>`)
- Strategie di risoluzione: accettare la versione locale, remota o creare una versione combinata
- Utilizzo di tool grafici (`git mergetool`) e risoluzione manuale

**Flusso dell'esercizio:**
```bash
# 1. Creare due branch che modificano lo stesso file
git checkout -b branch-A
echo "Modifica da branch A" >> file.txt
git add . && git commit -m "Modifica da A"

git checkout main
git checkout -b branch-B
echo "Modifica da branch B" >> file.txt
git add . && git commit -m "Modifica da B"

# 2. Effettuare il merge e provocare il conflitto
git checkout main
git merge branch-A
git merge branch-B    # ← qui scatta il conflitto

# 3. Risolvere il conflitto manualmente, poi:
git add file.txt
git commit -m "Risolto conflitto tra branch-A e branch-B"
```

---

### 3. 🔑 Scambio Chiave SSH

Questa esercitazione copre la configurazione dell'autenticazione basata su chiavi SSH, metodo più sicuro rispetto all'autenticazione tramite password.

**Argomenti trattati:**
- Funzionamento della crittografia asimmetrica (chiave pubblica/privata)
- Generazione di una coppia di chiavi SSH con `ssh-keygen`
- Copia della chiave pubblica sul server remoto tramite `ssh-copy-id`
- Configurazione del file `~/.ssh/authorized_keys`
- Hardening: disabilitazione dell'accesso SSH tramite password

**Comandi principali utilizzati:**
```bash
# Generazione coppia di chiavi (algoritmo ED25519, più sicuro di RSA)
ssh-keygen -t ed25519 -C "commento_identificativo"

# Copia della chiave pubblica sul server remoto
ssh-copy-id utente@indirizzo_server

# In alternativa, manuale:
cat ~/.ssh/id_ed25519.pub | ssh utente@server "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# Test della connessione con chiave
ssh -i ~/.ssh/id_ed25519 utente@indirizzo_server

# Disabilitazione login con password (su /etc/ssh/sshd_config)
# PasswordAuthentication no
# PubkeyAuthentication yes
```

---

### 4. 🛡️ Impersonificazione Sudo nel File sudoers

Questa esercitazione esplora la gestione avanzata dei privilegi con `sudo`, con particolare attenzione alla configurazione del file `/etc/sudoers` per permettere a un utente di eseguire comandi come se fosse un altro utente (non necessariamente root).

**Argomenti trattati:**
- Struttura e sintassi del file `/etc/sudoers`
- Differenza tra esecuzione come `root` e impersonificazione di un altro utente (`-u`)
- Utilizzo di `visudo` per la modifica sicura del file sudoers
- Definizione di regole granulari: limitare comandi specifici, utenti specifici e host
- Utilizzo di alias (`User_Alias`, `Cmnd_Alias`, `Host_Alias`)

**Sintassi fondamentale di sudoers:**
```
# Formato base:
# utente  host=(utente_destinazione)  comando

# Permettere a "alice" di eseguire qualsiasi comando come "bob"
alice   ALL=(bob)   ALL

# Permettere a "alice" di eseguire solo /bin/ls come "bob", senza password
alice   ALL=(bob)   NOPASSWD: /bin/ls

# Utilizzo da terminale
sudo -u bob /bin/ls /home/bob
```

> ⚠️ **Attenzione:** Modificare il file `/etc/sudoers` richiede estrema cautela. Usare **sempre** `visudo` per evitare errori di sintassi che potrebbero rendere il sistema inaccessibile.

```bash
# Apertura sicura del file sudoers
sudo visudo
```

---

## 🐚 Script Bash

La cartella `script_bash/` contiene script Bash da analizzare, studiare e commentare. L'obiettivo è comprendere la logica dei singoli script, documentare ogni sezione con commenti esplicativi e — dove necessario — migliorarne la leggibilità o la robustezza.

**Linee guida per la commentazione:**
- Ogni script deve avere un'intestazione con **scopo**, **autore** e **data**
- Le sezioni logiche vanno separate da commenti di blocco
- Le variabili principali vanno documentate con il loro utilizzo
- I comandi non ovvi vanno spiegati inline

**Esempio di intestazione standard:**
```bash
#!/usr/bin/env bash
# =============================================================================
# Nome script : nome_script.sh
# Descrizione : Breve descrizione dello scopo dello script
# Autore      : Nome Cognome
# Data        : YYYY-MM-DD
# Versione    : 1.0
# Utilizzo    : ./nome_script.sh [argomenti]
# =============================================================================
```

---

## 🛠️ Requisiti

Per eseguire le esercitazioni è consigliato un ambiente **Linux** (Ubuntu/Debian o CentOS/RHEL) con i seguenti strumenti installati:

| Strumento   | Utilizzo                          | Installazione              |
|-------------|-----------------------------------|----------------------------|
| `openssl`   | Gestione certificati SSL          | `apt install openssl`      |
| `git`       | Versionamento e gestione conflitti | `apt install git`          |
| `openssh`   | Connessioni e scambio chiavi SSH  | `apt install openssh-client openssh-server` |
| `sudo`      | Gestione privilegi                | Preinstallato su molte distro |
| `bash`      | Esecuzione script                 | Preinstallato              |

---

## 🚀 Come usare questa repository

```bash
# 1. Clona la repository
git clone https://github.com/VFabio-ops/formazione_sou.git

# 2. Entra nella directory
cd formazione_sou

# 3. Naviga nella cartella dell'esercitazione di interesse
cd esercizi/ssl_certificate

# 4. Leggi il README locale dell'esercizio (se presente) e segui le istruzioni
```

---

## 📌 Note

- Gli esercizi sono pensati per un contesto di **laboratorio/formazione**: non usare configurazioni self-signed o permessi sudo permissivi in ambienti di produzione.
- Prima di modificare file di sistema critici come `sudoers` o `sshd_config`, effettua sempre un **backup**.
- Ogni script Bash nella cartella `script_bash/` può richiedere adattamenti in base alla distribuzione Linux utilizzata.

---

## 👤 Autore

**VFabio-ops**  
Repository creata nell'ambito del percorso formativo SOU.

---

*Ultimo aggiornamento: Aprile 2026*
