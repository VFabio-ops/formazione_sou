Certificazione SSL

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