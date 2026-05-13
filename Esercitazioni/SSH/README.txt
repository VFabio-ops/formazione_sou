Scambio Chiave SSH

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