# Apache Web Server e Test dei Codici di Stato HTTP

Un progetto pratico per configurare ed eseguire un server HTTP Apache su Ubuntu, testare diversi codici di stato HTTP tramite configurazione diretta del server e provocare un errore `500 Internal Server Error` attraverso un'applicazione Python Flask servita tramite `mod_wsgi`.

---

# Panoramica

Questo progetto mostra come:

* Configurare un `VirtualHost` Apache per servire un'applicazione Python Flask tramite `mod_wsgi`
* Utilizzare le direttive Apache per produrre risposte HTTP specifiche:

  * `301 Moved Permanently`
  * `401 Unauthorized`
* Provocare deliberatamente un errore `500 Internal Server Error`
* Osservare e interpretare gli header HTTP raw per ciascun codice di stato

Il server è in ascolto sulla porta `80` e utilizza il nome host `ubuntu_1`, configurato all'interno di una macchina virtuale VirtualBox.

---

# Requisiti

* Ubuntu *(testato con Apache `2.4.64`)*
* Apache2 con `mod_wsgi`
* Python 3 con `venv`
* Flask

## Installazione delle dipendenze

```bash
sudo apt update
sudo apt install apache2 libapache2-mod-wsgi-py3 python3-venv
```

## Abilitazione del modulo WSGI

```bash
sudo a2enmod wsgi
sudo systemctl restart apache2
```

---

# Struttura del Progetto

```text
/home/vboxuser/myflaskapp/
├── venv/               # Ambiente virtuale Python
├── myflaskapp.wsgi     # Entry point WSGI per Apache
└── app.py              # Applicazione Flask

/var/www/ubuntu_1/
├── error.log           # Log degli errori Apache
└── access.log          # Log degli accessi Apache

/etc/apache2/sites-available/
└── HTTP_Host.conf      # Configurazione VirtualHost
```

---

# Configurazione del VirtualHost Apache

 **File:** `HTTP_Host.conf`

```apache
<VirtualHost *:80>
    ServerName ubuntu_1

    WSGIDaemonProcess myflaskapp \
        python-home=/home/vboxuser/myflaskapp/venv \
        python-path=/home/vboxuser/myflaskapp

    WSGIProcessGroup myflaskapp
    WSGIScriptAlias / /home/vboxuser/myflaskapp/myflaskapp.wsgi

    <Directory /home/vboxuser/myflaskapp>
        Require all granted
    </Directory>

    # Redirect 301 / https://www.google.com

    # <Directory "/var/www/ubuntu_1/public_html">
    #     AuthType Basic
    #     AuthName "admin area"
    #     AuthUserFile /etc/apache2/.htpasswd
    #     Require valid-user
    # </Directory>

    ErrorLog /var/www/ubuntu_1/error.log
    CustomLog /var/www/ubuntu_1/access.log combined

</VirtualHost>
```

## Abilitazione del sito

```bash
sudo a2ensite HTTP_Host.conf
sudo systemctl reload apache2
```

---

# Configurazione dell'Applicazione Flask

## Creazione dell'ambiente virtuale

```bash
cd /home/vboxuser/myflaskapp

python3 -m venv venv
source venv/bin/activate

pip install flask
```

## File `myflaskapp.wsgi`

```python
import sys

sys.path.insert(0, '/home/vboxuser/myflaskapp')

from app import app as application
```

## File `app.py`

Applicazione Flask che genera volutamente un errore `500`.

```python
from flask import Flask

app = Flask(__name__)

@app.route('/')
def index():
    raise Exception(
        "Errore interno del server provocato deliberatamente per il test"
    )

if __name__ == '__main__':
    app.run()
```

Quando Apache inoltra una richiesta a questa applicazione e l'eccezione non viene gestita, il server restituisce automaticamente una risposta HTTP `500`.

---

# Codici di Stato HTTP Testati

Di seguito sono riportate le risposte catturate durante i test.

---

## 200 OK

Il server restituisce correttamente la risorsa richiesta.

```http
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

---

## 301 Moved Permanently

Attivato decommentando la direttiva `Redirect 301`.

```http
HTTP/1.1 301 Moved Permanently
Date: Tue, 12 May 2026 15:12:26 GMT
Server: Apache/2.4.64 (Ubuntu)
Location: https://www.google.com
Content-Type: text/html; charset=iso-8859-1
```

Il client viene reindirizzato permanentemente all'URL specificato nell'header `Location`.

---

## 401 Unauthorized

Attivato decommentando il blocco `AuthType Basic`.

```http
HTTP/1.1 401 Unauthorized
Date: Wed, 13 May 2026 08:03:35 GMT
Server: Apache/2.4.64 (Ubuntu)
WWW-Authenticate: Basic realm="admin area"
Content-Type: text/html; charset=iso-8859-1
```

## Generazione del file `.htpasswd`

```bash
sudo htpasswd -c /etc/apache2/.htpasswd admin
```

Il server richiede credenziali HTTP Basic per accedere alla risorsa.

---

## 404 Not Found

Restituito quando il client richiede un percorso inesistente.

```http
HTTP/1.1 404 Not Found
Date: Wed, 13 May 2026 08:04:42 GMT
Server: Apache/2.4.64 (Ubuntu)
Content-Type: text/html; charset=iso-8859-1
```

---

## 500 Internal Server Error

Generato dall'applicazione Flask tramite eccezione non gestita.

```http
HTTP/1.1 500 Internal Server Error
Date: Wed, 13 May 2026 10:06:37 GMT
Server: Apache/2.4.64 (Ubuntu)
Connection: close
Content-Type: text/html; charset=iso-8859-1
```

Apache riceve il fallimento dal processo WSGI e restituisce il codice `500` al client.

L'header:

```http
Connection: close
```

indica che il server ha chiuso la connessione dopo l'errore.

---

# Dettagli di Configurazione

## Passaggio tra gli Scenari

Il file `VirtualHost` utilizza commenti per alternare i diversi comportamenti del server.

### Per attivare un redirect `301`

Decommentare:

```apache
Redirect 301 / https://www.google.com
```

### Per attivare autenticazione HTTP Basic (`401`)

Decommentare:

```apache
<Directory "/var/www/ubuntu_1/public_html">
    AuthType Basic
    AuthName "admin area"
    AuthUserFile /etc/apache2/.htpasswd
    Require valid-user
</Directory>
```

### Per provocare un `500 Internal Server Error`

Lasciare attiva l'applicazione Flask contenente l'eccezione non gestita.

---

## Ricaricare Apache

Dopo ogni modifica alla configurazione:

```bash
sudo systemctl reload apache2
```

---

# File di Log

I log vengono scritti nella directory:

```text
/var/www/ubuntu_1/
```

## Monitorare gli accessi in tempo reale

```bash
sudo tail -f /var/www/ubuntu_1/access.log
```

## Monitorare gli errori in tempo reale

```bash
sudo tail -f /var/www/ubuntu_1/error.log
```

---

# Test delle Risposte HTTP

Utilizzare `curl` con il flag `-I` per ispezionare gli header HTTP.

## Test risposta predefinita

```bash
curl -I http://ubuntu_1
```

## Seguire automaticamente i redirect

```bash
curl -IL http://ubuntu_1
```

## Test autenticazione Basic

```bash
curl -I -u admin:password http://ubuntu_1
```

## Test errore 404

```bash
curl -I http://ubuntu_1/nonexistent
```

---

# 🔎 Verifica della Versione del Server

Per verificare identità e versione del server HTTP, controllare il campo:

```http
Server: Apache/2.4.64 (Ubuntu)
```

presente negli header di risposta HTTP.

---

# Obiettivi Didattici

Questo progetto permette di comprendere:

* Il funzionamento di Apache come web server
* La gestione dei codici di stato HTTP
* L'integrazione tra Apache e Flask tramite WSGI
* L'autenticazione HTTP Basic
* Il debugging tramite file di log Apache
* L'analisi manuale delle risposte HTTP raw
