Impersonificazione Sudo nel File sudoers

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

> **Attenzione:** Modificare il file `/etc/sudoers` richiede estrema cautela. Usare **sempre** `visudo` per evitare errori di sintassi che potrebbero rendere il sistema inaccessibile.

```bash
# Apertura sicura del file sudoers
sudo visudo