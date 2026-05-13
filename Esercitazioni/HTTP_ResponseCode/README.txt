# Apache Web Server & HTTP Status Code Testing

A hands-on project to configure and run an Apache HTTP server on Ubuntu, 
test a range of HTTP status codes through direct server configuration, 
and trigger a 500 Internal Server Error via a Python Flask application served through mod_wsgi.

---

---

## Overview

This project demonstrates how to:

- Configure an Apache VirtualHost to serve a Python Flask application via `mod_wsgi`
- Use Apache directives to produce specific HTTP responses (301 redirect, 401 authentication challenge)
- Deliberately trigger a 500 Internal Server Error through a broken Flask application
- Observe and interpret raw HTTP response headers for each status code

The server runs on port 80 and uses the hostname `ubuntu_1`, configured inside a VirtualBox virtual machine.

---

## Requirements

- Ubuntu (tested on the version shipping with Apache 2.4.64)
- Apache2 with `mod_wsgi` enabled
- Python 3 with `venv`
- Flask

Install dependencies:

```bash
sudo apt update
sudo apt install apache2 libapache2-mod-wsgi-py3 python3-venv
```

Enable the wsgi module:

```bash
sudo a2enmod wsgi
sudo systemctl restart apache2
```

---

## Project Structure

```
/home/vboxuser/myflaskapp/
    venv/               # Python virtual environment
    myflaskapp.wsgi     # WSGI entry point for Apache
    app.py              # Flask application

/var/www/ubuntu_1/
    error.log           # Apache error log
    access.log          # Apache access log

/etc/apache2/sites-available/
    HTTP_Host.conf      # VirtualHost configuration file
```

---

## Apache VirtualHost Configuration

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


To enable the site:

```bash
sudo a2ensite HTTP_Host.conf
sudo systemctl reload apache2
```

---

## Flask Application Setup

Create the virtual environment and install Flask:

```bash
cd /home/vboxuser/myflaskapp
python3 -m venv venv
source venv/bin/activate
pip install flask
```

Example `myflaskapp.wsgi` entry point:

```python
import sys
sys.path.insert(0, '/home/vboxuser/myflaskapp')
from app import app as application
```

Example `app.py` that deliberately raises a 500 error:

```python
from flask import Flask

app = Flask(__name__)

@app.route('/')
def index():
    raise Exception("Deliberate internal server error for testing")

if __name__ == '__main__':
    app.run()
```

When Apache passes a request to this application and the exception is unhandled, it returns an HTTP 500 response to the client.

---

## HTTP Status Codes Tested

The following responses were captured from the server during testing.

### 200 OK

The server successfully returned the requested resource.

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

Triggered by uncommenting the `Redirect 301` directive in the VirtualHost configuration. The client is instructed to follow the `Location` header permanently.

```
HTTP/1.1 301 Moved Permanently
Date: Tue, 12 May 2026 15:12:26 GMT
Server: Apache/2.4.64 (Ubuntu)
Location: https://www.google.com
Content-Type: text/html; charset=iso-8859-1
```

### 401 Unauthorized

Triggered by uncommenting the `AuthType Basic` block and generating a `.htpasswd` file. The server challenges the client for credentials.

```
HTTP/1.1 401 Unauthorized
Date: Wed, 13 May 2026 08:03:35 GMT
Server: Apache/2.4.64 (Ubuntu)
WWW-Authenticate: Basic realm="admin area"
Content-Type: text/html; charset=iso-8859-1
```

To generate the `.htpasswd` file:

```bash
sudo htpasswd -c /etc/apache2/.htpasswd admin
```

### 404 Not Found

Returned when a client requests a path that does not exist on the server.

```
HTTP/1.1 404 Not Found
Date: Wed, 13 May 2026 08:04:42 GMT
Server: Apache/2.4.64 (Ubuntu)
Content-Type: text/html; charset=iso-8859-1
```

### 500 Internal Server Error

Triggered by the Flask application raising an unhandled exception. Apache receives the failure from the WSGI process and returns a 500 to the client. Note the `Connection: close` header, which indicates the server closed the connection after the error.

```
HTTP/1.1 500 Internal Server Error
Date: Wed, 13 May 2026 10:06:37 GMT
Server: Apache/2.4.64 (Ubuntu)
Connection: close
Content-Type: text/html; charset=iso-8859-1
```

---

## Configuration Details

### Switching Between Scenarios

The VirtualHost file uses comments to toggle between different server behaviors. Uncommenting specific blocks changes the server response:

- Remove the comment from `Redirect 301` to produce a 301 response on all requests.
- Remove the comment from the `AuthType Basic` block to require HTTP Basic Authentication, producing a 401 on unauthenticated requests.
- The Flask application with an unhandled exception produces the 500 without any Apache directive change.

After editing the configuration file, always reload Apache:

```bash
sudo systemctl reload apache2
```

### Log Files

Access and error logs are written to `/var/www/ubuntu_1/`:

```bash
# Monitor access in real time
sudo tail -f /var/www/ubuntu_1/access.log

# Monitor errors in real time
sudo tail -f /var/www/ubuntu_1/error.log
```

---

## Testing

Send raw HTTP requests using `curl` with the `-I` flag to inspect response headers:

```bash
# Test the default response
curl -I http://ubuntu_1

# Follow redirects
curl -IL http://ubuntu_1

# Test with credentials for Basic Auth
curl -I -u admin:password http://ubuntu_1

# Request a non-existent path for 404
curl -I http://ubuntu_1/nonexistent
```

To verify the server identity and version in the response headers, look for the `Server` field, 
which in this setup returns `Apache/2.4.64 (Ubuntu)`.