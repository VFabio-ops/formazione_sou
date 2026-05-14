# Apache Web Server e Test dei Codici di Stato HTTP

Un progetto pratico per configurare ed eseguire un server HTTP Apache su Ubuntu, testare una serie di codici di stato HTTP tramite configurazione diretta del server e provocare un errore 500 Internal Server Error attraverso un'applicazione Python Flask servita tramite mod_wsgi.

---

## Panoramica

Questo progetto mostra come:

- Configurare un VirtualHost Apache per servire un'applicazione Python Flask tramite `mod_wsgi`
- Utilizzare le direttive Apache per produrre risposte HTTP specifiche (reindirizzamento 301, autenticazione 401)
- Provocare deliberatamente un errore 500 Internal Server Error tramite un'applicazione Flask non funzionante
- Osservare e interpretare gli header HTTP raw per ciascun codice di stato

Il server è in ascolto sulla porta 80 e utilizza il nome host `ubuntu_1`, configurato all'interno di una macchina virtuale VirtualBox.

---

## Requisiti

- Ubuntu (testato con la versione che include Apache 2.4.64)
- Apache2 con `mod_wsgi` abilitato
- Python 3 con `venv`
- Flask

Installazione delle dipendenze:

```bash
sudo apt update
sudo apt install apache2 libapache2-mod-wsgi-py3 python3-venv
```

Abilitazione del modulo wsgi:

```bash
sudo a2enmod wsgi
sudo systemctl restart apache2
```

---

## Struttura del Progetto

```
/home/vboxuser/myflaskapp/
    venv/               # Ambiente virtuale Python
    myflaskapp.wsgi     # Entry point WSGI per Apache
    app.py              # Applicazione Flask

/var/www/ubuntu_1/
    error.log           # Log degli errori di Apache
    access.log          # Log degli accessi di Apache

/etc/apache2/sites-available/
    HTTP_Host.conf      # File di configurazione VirtualHost
```

---

## Configurazione del VirtualHost Apache

File: `HTTP_Host.conf`

```apache
<VirtualHost *:80>
    ServerName ubuntu_1

    WSGIDaemonProcess myflaskapp python-home=/home/vboxuser/myflaskapp/venv python-path=/home/vboxuser/myflaskapp
    WSGIProcessGroup myflaskapp
    WSGIScriptAlias / /home/vboxuser/myflaskapp/myflaskapp.wsgi

    <Directory /home/vboxuser/myflaskapp>
        Require all granted
    </Directory>

    # Redirect 301 / https://www.google.com
    #   <Directory "/var/www/ubuntu_1/public_html">
    #       AuthType Basic
    #       AuthName "admin area"
    #       AuthUserFile /etc/apache2/.htpasswd
    #       Require valid-user
    #   </Directory>

    ErrorLog /var/www/ubuntu_1/error.log
    CustomLog /var/www/ubuntu_1/access.log combined

</VirtualHost>
```

Per abilitare il sito:

```bash
sudo a2ensite HTTP_Host.conf
sudo systemctl reload apache2
```

---

## Configurazione dell'Applicazione Flask

Creazione dell'ambiente virtuale e installazione di Flask:

```bash
cd /home/vboxuser/myflaskapp
python3 -m venv venv
source venv/bin/activate
pip install flask
```

Esempio di entry point `myflaskapp.wsgi`:

```python
import sys
sys.path.insert(0, '/home/vboxuser/myflaskapp')
from app import app as application
```

Esempio di `app.py` che provoca deliberatamente un errore 500:

```python
from flask import Flask

app = Flask(__name__)

@app.route('/')
def index():
    raise Exception("Errore interno del server provocato deliberatamente per il test")

if __name__ == '__main__':
    app.run()
```

Quando Apache inoltra una richiesta a questa applicazione e l'eccezione non viene gestita, restituisce una risposta HTTP 500 al client.

---

## Codici di Stato HTTP Testati

Di seguito sono riportate le risposte catturate dal server durante i test.

### 200 OK

Il server ha restituito con successo la risorsa richiesta.

```
HTTP/1.1 200 OK
Date: Tue, 12 May 2026 15:12:05 GMT
Server: Apache/2.4.64 (Ubuntu)
Last-Modified: Tue, 21 Apr 2026 07:38:52 GMT
ETag: "f9-64ff381bb3cd7"
Accept-Ranges: bytes
Content-Length: 249
Vary: Accept-Encoding
Content-Type: text/html
```

### 301 Moved Permanently

Attivato decommentando la direttiva `Redirect 301` nella configurazione del VirtualHost. Il client viene istruito a seguire permanentemente l'header `Location`.

```
HTTP/1.1 301 Moved Permanently
Date: Tue, 12 May 2026 15:12:26 GMT
Server: Apache/2.4.64 (Ubuntu)
Location: https://www.google.com
Content-Type: text/html; charset=iso-8859-1
```

### 401 Unauthorized

Attivato decommentando il blocco `AuthType Basic` e generando un file `.htpasswd`. Il server richiede le credenziali al client.

```
HTTP/1.1 401 Unauthorized
Date: Wed, 13 May 2026 08:03:35 GMT
Server: Apache/2.4.64 (Ubuntu)
WWW-Authenticate: Basic realm="admin area"
Content-Type: text/html; charset=iso-8859-1
```

Per generare il file `.htpasswd`:

```bash
sudo htpasswd -c /etc/apache2/.htpasswd admin
```

### 404 Not Found

Restituito quando il client richiede un percorso che non esiste sul server.

```
HTTP/1.1 404 Not Found
Date: Wed, 13 May 2026 08:04:42 GMT
Server: Apache/2.4.64 (Ubuntu)
Content-Type: text/html; charset=iso-8859-1
```

### 500 Internal Server Error

Attivato dall'applicazione Flask che genera un'eccezione non gestita. Apache riceve il fallimento dal processo WSGI e restituisce un 500 al client. Si noti l'header `Connection: close`, che indica che il server ha chiuso la connessione dopo l'errore.

```
HTTP/1.1 500 Internal Server Error
Date: Wed, 13 May 2026 10:06:37 GMT
Server: Apache/2.4.64 (Ubuntu)
Connection: close
Content-Type: text/html; charset=iso-8859-1
```

---

## Dettagli di Configurazione

### Passaggio tra gli Scenari

Il file VirtualHost utilizza i commenti per alternare i diversi comportamenti del server. Decommentare blocchi specifici modifica la risposta restituita:

- Decommentare `Redirect 301` per produrre una risposta 301 su tutte le richieste.
- Decommentare il blocco `AuthType Basic` per richiedere l'autenticazione HTTP Basic, producendo una risposta 401 per le richieste non autenticate.
- L'applicazione Flask con un'eccezione non gestita produce il codice 500 senza alcuna modifica alle direttive Apache.

Dopo aver modificato il file di configurazione, ricaricare sempre Apache:

```bash
sudo systemctl reload apache2
```

### File di Log

I log di accesso e di errore vengono scritti in `/var/www/ubuntu_1/`:

```bash
# Monitorare gli accessi in tempo reale
sudo tail -f /var/www/ubuntu_1/access.log

# Monitorare gli errori in tempo reale
sudo tail -f /var/www/ubuntu_1/error.log
```

---

## Test

Inviare richieste HTTP raw usando `curl` con il flag `-I` per ispezionare gli header di risposta:

```bash
# Testare la risposta predefinita
curl -I http://ubuntu_1

# Seguire i reindirizzamenti
curl -IL http://ubuntu_1

# Testare con credenziali per l'autenticazione Basic
curl -I -u admin:password http://ubuntu_1

# Richiedere un percorso inesistente per ottenere un 404
curl -I http://ubuntu_1/nonexistent
```

Per verificare l'identità e la versione del server negli header di risposta, cercare il campo `Server`, che in questa configurazione restituisce `Apache/2.4.64 (Ubuntu)`.
