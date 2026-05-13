Port Scanner con Netcat

Questa esercitazione consiste in uno script Bash che implementa un semplice ma funzionale **port scanner**, utilizzando `netcat` (`nc`) per verificare quali porte TCP sono aperte su un host remoto in un intervallo definito dall'utente.

**File:** `esercizi/port_scanner.sh`

**Utilizzo:**
```bash
chmod +x port_scanner.sh
./port_scanner.sh <IP_ADDRESS> <PORTA_INIZIO> <PORTA_FINE>

# Esempio: scansiona le porte dalla 20 alla 1024 sull'host 192.168.1.1
./port_scanner.sh 192.168.1.1 20 1024
```

**Come funziona — flusso logico dello script:**

```
1. Lettura degli argomenti   →  IP, porta iniziale, porta finale
2. Validazione input         →  controlla che siano esattamente 3 argomenti
3. Validazione IP            →  verifica il formato con regex (es. 192.168.1.1)
4. Validazione range porte   →  porta minima ≥ 1, porta massima ≤ 65535
5. Scansione con netcat      →  per ogni porta nel range, tenta connessione TCP
6. Output risultati          →  stampa le porte aperte trovate
```

**Dettaglio dei controlli implementati:**

| Controllo | Comportamento in caso di errore |
|---|---|
| Numero di argomenti ≠ 3 | Stampa usage ed esce con codice 1 |
| IP non valido (formato errato) | Segnala l'indirizzo non valido ed esce |
| Porta iniziale < 1 | Segnala porta non valida ed esce |
| Porta finale > 65535 | Segnala porta inesistente ed esce |

**Comando chiave — netcat:**
```bash
nc -w 1 $HOST_IP $port <<< ""
# -w 1   : timeout di 1 secondo per la connessione
# <<<    : invia una stringa vuota (here-string) per tentare la connessione
# se il comando ha successo (exit code 0), la porta è aperta