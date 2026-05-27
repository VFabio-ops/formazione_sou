# Guida Ansible — Da zero a operativo

---

## Cos'è Ansible

Ansible è uno strumento open source per l'**automazione IT**: permette di configurare server, installare software, distribuire applicazioni e orchestrare operazioni complesse su decine o centinaia di macchine contemporaneamente, scrivendo istruzioni in file di testo.

Il suo punto di forza è l'architettura **agentless**: non richiede l'installazione di alcun software sui server target. Comunica tramite SSH (Linux/macOS) o WinRM (Windows) e legge le istruzioni da file scritti in YAML.

Viene usato per:
- Configurare server da zero in modo ripetibile
- Aggiornare pacchetti su più macchine in un solo comando
- Distribuire applicazioni in ambienti di staging e produzione
- Automatizzare task ripetitivi (backup, rotazione log, gestione utenti…)
- Implementare infrastrutture "Infrastructure as Code"

---

## Prerequisiti

Per usare Ansible è sufficiente:
- Un **control node**: la macchina da cui esegui i comandi (Linux o macOS; su Windows si usa WSL)
- Uno o più **managed node**: i server che vuoi gestire (qualsiasi sistema con SSH e Python installato)
- Connettività SSH tra control node e managed node

---

## Installazione

```bash
# Ubuntu / Debian
sudo apt update && sudo apt install ansible -y

# macOS (via Homebrew)
brew install ansible

# pip (universale)
pip install ansible --break-system-packages

# Verifica installazione
ansible --version
```

---

## YAML — Il formato dei file Ansible

Tutti i file di configurazione di Ansible sono scritti in **YAML** (YAML Ain't Markup Language). Prima di imparare Ansible, è fondamentale capire YAML.

### Regole base di YAML

YAML rappresenta dati strutturati usando indentazione, trattini e due punti. È sensibile agli spazi (non alle tabulazioni).

**Coppia chiave-valore:**
```yaml
nome: Mario
eta: 30
attivo: true
```

**Lista (array):**
```yaml
frutti:
  - mela
  - banana
  - arancia
```

**Lista inline:**
```yaml
frutti: [mela, banana, arancia]
```

**Dizionario (oggetto):**
```yaml
utente:
  nome: Mario
  cognome: Rossi
  eta: 30
```

**Lista di dizionari:**
```yaml
utenti:
  - nome: Mario
    ruolo: admin
  - nome: Laura
    ruolo: user
```

**Stringa multilinea:**
```yaml
# Mantiene i newline (block literal)
messaggio: |
  Prima riga
  Seconda riga
  Terza riga

# Unisce tutto in una riga (block folded)
descrizione: >
  Questo testo lungo
  viene unito in una
  sola riga.
```

**Commenti:**
```yaml
# Questo è un commento — YAML li ignora
nome: Mario  # commento inline
```

**Tipi di dato:**
```yaml
stringa: "ciao mondo"
stringa_senza_virgolette: ciao
intero: 42
decimale: 3.14
booleano_vero: true
booleano_falso: false
nullo: null
```

### Errori comuni in YAML

```yaml
# SBAGLIATO — indentazione con tabulazione
nome:
	valore: 42

# CORRETTO — solo spazi
nome:
  valore: 42

# SBAGLIATO — spazio mancante dopo i due punti
nome:Mario

# CORRETTO
nome: Mario
```

---

## Struttura di un progetto Ansible

```
progetto-ansible/
├── inventory/
│   ├── hosts.ini          # Lista dei server
│   └── group_vars/        # Variabili per gruppo
│       └── webservers.yml
├── playbooks/
│   └── site.yml           # Playbook principale
├── roles/
│   └── nginx/             # Ruolo riutilizzabile
│       ├── tasks/
│       │   └── main.yml
│       ├── templates/
│       │   └── nginx.conf.j2
│       └── vars/
│           └── main.yml
└── ansible.cfg            # Configurazione globale
```

---

## L'Inventory

L'inventory è la **lista dei server** che Ansible deve gestire. Può essere un file statico (`.ini` o `.yml`) o dinamico (generato da script).

### Formato INI (il più comune per chi inizia)

```ini
# inventory/hosts.ini

# Server singolo
web1.example.com

# Gruppo di server
[webservers]
web1.example.com
web2.example.com
192.168.1.10

# Gruppo con opzioni di connessione
[dbservers]
db1.example.com ansible_user=ubuntu ansible_port=2222

# Gruppo di gruppi
[produzione:children]
webservers
dbservers

# Variabili di gruppo
[webservers:vars]
http_port=80
max_connections=200
```

### Formato YAML

```yaml
# inventory/hosts.yml
all:
  children:
    webservers:
      hosts:
        web1.example.com:
        web2.example.com:
          ansible_port: 2222
    dbservers:
      hosts:
        db1.example.com:
      vars:
        db_port: 5432
```

### Verifica inventory

```bash
# Elenca tutti i server nell'inventory
ansible-inventory -i inventory/hosts.ini --list

# Testa la connettività verso tutti i server
ansible all -i inventory/hosts.ini -m ping
```

---

## I Playbook

Un **playbook** è un file YAML che contiene una serie di istruzioni (task) che Ansible esegue in ordine sui server specificati. È il cuore di Ansible.

### Struttura di un playbook

```yaml
---
# Il triplo trattino indica l'inizio di un documento YAML

- name: Nome descrittivo del play       # Cosa fa questo play
  hosts: webservers                     # Su quali host eseguirlo
  become: true                          # Esegui come superutente (sudo)
  vars:                                 # Variabili locali al play
    http_port: 80
    app_name: myapp

  tasks:                                # Lista dei task da eseguire
    - name: Installa nginx
      apt:
        name: nginx
        state: present

    - name: Avvia nginx
      service:
        name: nginx
        state: started
        enabled: true
```

### Anatomia di un task

```yaml
- name: Descrizione chiara del task     # Obbligatorio: descrive cosa fa
  nome_modulo:                          # Il modulo Ansible da usare
    parametro1: valore1                 # Parametri del modulo
    parametro2: valore2
  when: condizione                      # Opzionale: esegui solo se vero
  register: risultato                   # Opzionale: salva l'output
  notify: nome_handler                  # Opzionale: trigger per handler
  tags: [web, configurazione]           # Opzionale: etichette per filtro
```

---

## I Moduli principali

I moduli sono le unità di lavoro di Ansible. Ogni task usa un modulo.

### Gestione pacchetti

```yaml
# apt (Debian/Ubuntu)
- name: Installa nginx
  apt:
    name: nginx
    state: present      # present = installa, absent = rimuovi, latest = aggiorna

- name: Installa più pacchetti
  apt:
    name:
      - nginx
      - curl
      - git
    state: present
    update_cache: true  # Equivale a apt update

# yum / dnf (RHEL/CentOS/Fedora)
- name: Installa nginx
  dnf:
    name: nginx
    state: present
```

### Gestione servizi

```yaml
- name: Avvia e abilita nginx
  service:
    name: nginx
    state: started      # started, stopped, restarted, reloaded
    enabled: true       # Avvia automaticamente al boot
```

### Gestione file

```yaml
# Copia un file locale sul server
- name: Copia file di configurazione
  copy:
    src: files/nginx.conf
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'

# Crea una directory
- name: Crea directory per i log
  file:
    path: /var/log/myapp
    state: directory
    mode: '0755'
    owner: www-data

# Elimina un file
- name: Rimuovi file temporaneo
  file:
    path: /tmp/temp.txt
    state: absent

# Crea un link simbolico
- name: Crea symlink
  file:
    src: /etc/nginx/sites-available/myapp
    dest: /etc/nginx/sites-enabled/myapp
    state: link
```

### Esecuzione comandi

```yaml
# command — esegue comandi semplici (senza shell)
- name: Verifica versione Python
  command: python3 --version
  register: python_version

# shell — esegue comandi con funzionalità shell (pipe, redirect, glob)
- name: Lista file log
  shell: ls /var/log/*.log | wc -l
  register: num_log

# Usa command invece di shell quando possibile (più sicuro)
```

### Gestione utenti

```yaml
- name: Crea utente applicazione
  user:
    name: appuser
    shell: /bin/bash
    groups: sudo
    append: true        # Non rimuovere dai gruppi esistenti
    create_home: true

- name: Aggiungi chiave SSH all'utente
  authorized_key:
    user: appuser
    key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
    state: present
```

### Template Jinja2

```yaml
- name: Genera configurazione nginx da template
  template:
    src: templates/nginx.conf.j2
    dest: /etc/nginx/sites-available/myapp
    mode: '0644'
  notify: Ricarica nginx
```

Il file `nginx.conf.j2` può usare variabili:
```nginx
server {
    listen {{ http_port }};
    server_name {{ server_name }};

    location / {
        proxy_pass http://localhost:{{ app_port }};
    }
}
```

### Download e URI

```yaml
# Scarica un file
- name: Scarica installer
  get_url:
    url: https://example.com/app.tar.gz
    dest: /tmp/app.tar.gz
    mode: '0644'

# Chiamata HTTP
- name: Verifica che l'app risponda
  uri:
    url: http://localhost:8080/health
    status_code: 200
```

---

## Le Variabili

Le variabili rendono i playbook flessibili e riutilizzabili.

### Definire variabili

```yaml
# Nel playbook (scope: play)
- name: Deploy applicazione
  hosts: webservers
  vars:
    app_version: "2.1.0"
    app_port: 8080
    deploy_dir: /opt/myapp

# In un file separato
  vars_files:
    - vars/app.yml
    - vars/secrets.yml
```

### Usare variabili

```yaml
- name: Crea directory dell'app
  file:
    path: "{{ deploy_dir }}/{{ app_version }}"
    state: directory

# Nei task le variabili vanno sempre tra virgolette quando sono il valore intero
- name: Avvia app sulla porta corretta
  debug:
    msg: "L'app gira sulla porta {{ app_port }}"
```

### Variabili di gruppo e host (group_vars / host_vars)

```
inventory/
├── hosts.ini
├── group_vars/
│   ├── all.yml          # Variabili per TUTTI i server
│   └── webservers.yml   # Variabili per il gruppo webservers
└── host_vars/
    └── web1.example.com.yml   # Variabili per un singolo host
```

```yaml
# group_vars/webservers.yml
http_port: 80
max_connections: 1000
app_name: myapp
```

### Variabili da riga di comando

```bash
# Passa variabili al momento dell'esecuzione
ansible-playbook site.yml -e "app_version=2.1.0 environment=prod"

# Da file JSON o YAML
ansible-playbook site.yml -e "@vars/extra.yml"
```

### Variabili di sistema (Facts)

Ansible raccoglie automaticamente informazioni sui server (detti "facts"):

```yaml
- name: Mostra informazioni sul sistema
  debug:
    msg: >
      Sistema: {{ ansible_distribution }}
      Versione: {{ ansible_distribution_version }}
      CPU: {{ ansible_processor_count }}
      RAM: {{ ansible_memtotal_mb }} MB
      IP: {{ ansible_default_ipv4.address }}
```

---

## Le Condizioni (when)

```yaml
# Esegui solo su Ubuntu
- name: Installa nginx su Ubuntu
  apt:
    name: nginx
    state: present
  when: ansible_distribution == "Ubuntu"

# Esegui solo se la variabile è definita
- name: Configura porta custom
  lineinfile:
    path: /etc/app/config.ini
    line: "port={{ custom_port }}"
  when: custom_port is defined

# Condizioni multiple (AND)
- name: Task su Ubuntu 20.04
  debug:
    msg: "Questo è Ubuntu 20.04"
  when:
    - ansible_distribution == "Ubuntu"
    - ansible_distribution_version == "20.04"

# Condizioni alternative (OR)
- name: Task su Debian o Ubuntu
  apt:
    name: curl
    state: present
  when: ansible_distribution == "Ubuntu" or ansible_distribution == "Debian"
```

---

## I Loop

```yaml
# Loop su una lista
- name: Installa più pacchetti
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - nginx
    - curl
    - git
    - vim

# Loop su una lista di dizionari
- name: Crea utenti
  user:
    name: "{{ item.name }}"
    groups: "{{ item.groups }}"
    shell: /bin/bash
  loop:
    - { name: alice, groups: sudo }
    - { name: bob,   groups: www-data }
    - { name: carol, groups: sudo }

# Loop con indice
- name: Task con indice
  debug:
    msg: "Item {{ ansible_loop.index }}: {{ item }}"
  loop: [a, b, c]
  loop_control:
    extended: true
```

---

## Gli Handler

Gli handler sono task speciali che vengono eseguiti **solo se notificati**, e solo **una volta** alla fine del play, indipendentemente da quante volte vengono notificati. Sono usati tipicamente per riavviare servizi dopo una modifica alla configurazione.

```yaml
- name: Configura e avvia nginx
  hosts: webservers
  become: true

  tasks:
    - name: Copia configurazione nginx
      copy:
        src: nginx.conf
        dest: /etc/nginx/nginx.conf
      notify: Ricarica nginx          # Notifica l'handler

    - name: Copia virtual host
      template:
        src: vhost.conf.j2
        dest: /etc/nginx/sites-available/myapp
      notify: Ricarica nginx          # Stessa notifica — ma l'handler gira solo una volta

  handlers:
    - name: Ricarica nginx
      service:
        name: nginx
        state: reloaded
```

---

## Register e Debug

Puoi salvare l'output di un task in una variabile e usarlo nei task successivi.

```yaml
- name: Controlla se l'app è in esecuzione
  command: pgrep -x myapp
  register: app_status
  ignore_errors: true       # Non fallire se il comando ritorna errore

- name: Mostra lo status
  debug:
    var: app_status           # Mostra il contenuto completo della variabile

- name: Avvia l'app se non è attiva
  command: /opt/myapp/start.sh
  when: app_status.rc != 0   # rc = return code

# debug per stampare messaggi durante l'esecuzione
- name: Informazioni di debug
  debug:
    msg: "Distribuzione: {{ ansible_distribution }}, IP: {{ ansible_default_ipv4.address }}"
```

---

## I Roles

I roles sono il modo per organizzare e riutilizzare i playbook. Un role è una struttura di directory standardizzata che raggruppa task, variabili, template e file relativi a un componente specifico.

```
roles/
└── nginx/
    ├── tasks/
    │   └── main.yml        # Task principali
    ├── handlers/
    │   └── main.yml        # Handler del role
    ├── templates/
    │   └── nginx.conf.j2   # Template Jinja2
    ├── files/
    │   └── index.html      # File statici
    ├── vars/
    │   └── main.yml        # Variabili (alta priorità)
    ├── defaults/
    │   └── main.yml        # Variabili di default (bassa priorità)
    └── meta/
        └── main.yml        # Dipendenze del role
```

**roles/nginx/tasks/main.yml:**
```yaml
---
- name: Installa nginx
  apt:
    name: nginx
    state: present
    update_cache: true

- name: Copia configurazione
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Ricarica nginx

- name: Avvia e abilita nginx
  service:
    name: nginx
    state: started
    enabled: true
```

**Usa il role nel playbook:**
```yaml
---
- name: Configura webserver
  hosts: webservers
  become: true
  roles:
    - nginx
    - ufw
    - certbot
```

### Ansible Galaxy

Galaxy è il repository ufficiale di roles e collection pubblici:

```bash
# Cerca un role
ansible-galaxy search nginx

# Installa un role
ansible-galaxy install geerlingguy.nginx

# Installa da requirements.yml
ansible-galaxy install -r requirements.yml
```

---

## Esecuzione dei Playbook

```bash
# Esecuzione base
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# Con verbose (più output per debug)
ansible-playbook site.yml -v      # livello 1
ansible-playbook site.yml -vv     # livello 2
ansible-playbook site.yml -vvv    # livello 3 (molto dettagliato)

# Dry run: mostra cosa farebbe senza eseguire nulla
ansible-playbook site.yml --check

# Mostra le differenze nei file che verrebbero modificati
ansible-playbook site.yml --check --diff

# Esegui solo i task con determinati tag
ansible-playbook site.yml --tags "nginx,ssl"

# Escludi tag
ansible-playbook site.yml --skip-tags "debug"

# Esegui solo su host specifici
ansible-playbook site.yml --limit web1.example.com

# Chiedi la password sudo
ansible-playbook site.yml --ask-become-pass

# Specifica l'utente SSH
ansible-playbook site.yml -u ubuntu
```

---

## ansible.cfg — Configurazione globale

```ini
[defaults]
inventory       = inventory/hosts.ini
remote_user     = ubuntu
host_key_checking = False           # Utile in sviluppo (non in produzione)
retry_files_enabled = False
stdout_callback = yaml              # Output più leggibile

[privilege_escalation]
become          = True
become_method   = sudo
become_user     = root
```

---

## Playbook completo di esempio

```yaml
---
# playbooks/webserver.yml
# Deploy completo di un webserver con nginx e app Python

- name: Configura webserver
  hosts: webservers
  become: true
  vars:
    app_port: 8000
    app_user: appuser
    app_dir: /opt/myapp
    domain: example.com

  tasks:

    # --- Sistema base ---
    - name: Aggiorna la cache dei pacchetti
      apt:
        update_cache: true
        cache_valid_time: 3600      # Non aggiornare se fatto meno di 1 ora fa

    - name: Installa dipendenze di sistema
      apt:
        name:
          - nginx
          - python3
          - python3-pip
          - git
        state: present

    # --- Utente applicazione ---
    - name: Crea utente per l'applicazione
      user:
        name: "{{ app_user }}"
        shell: /bin/bash
        create_home: true

    - name: Crea directory dell'applicazione
      file:
        path: "{{ app_dir }}"
        state: directory
        owner: "{{ app_user }}"
        mode: '0755'

    # --- Codice applicazione ---
    - name: Clona il repository dell'applicazione
      git:
        repo: https://github.com/example/myapp.git
        dest: "{{ app_dir }}"
        version: main
        force: true
      become_user: "{{ app_user }}"

    - name: Installa dipendenze Python
      pip:
        requirements: "{{ app_dir }}/requirements.txt"
        virtualenv: "{{ app_dir }}/venv"
      become_user: "{{ app_user }}"

    # --- Configurazione nginx ---
    - name: Copia configurazione nginx
      template:
        src: ../templates/nginx-vhost.conf.j2
        dest: /etc/nginx/sites-available/{{ domain }}
        mode: '0644'
      notify: Ricarica nginx

    - name: Abilita il virtual host
      file:
        src: /etc/nginx/sites-available/{{ domain }}
        dest: /etc/nginx/sites-enabled/{{ domain }}
        state: link
      notify: Ricarica nginx

    - name: Rimuovi configurazione default di nginx
      file:
        path: /etc/nginx/sites-enabled/default
        state: absent
      notify: Ricarica nginx

    # --- Servizio ---
    - name: Avvia e abilita nginx
      service:
        name: nginx
        state: started
        enabled: true

    # --- Verifica ---
    - name: Verifica che nginx risponda
      uri:
        url: http://localhost
        status_code: 200
      register: health_check
      retries: 3
      delay: 5

    - name: Mostra risultato health check
      debug:
        msg: "Nginx risponde correttamente: {{ health_check.status }}"

  handlers:
    - name: Ricarica nginx
      service:
        name: nginx
        state: reloaded
```

---

## Consigli pratici per principianti

**Inizia sempre con `--check --diff`** — prima di eseguire un playbook su server reali, usa sempre la modalità dry run per vedere cosa cambierebbe senza applicare nulla.

**Dai nomi descrittivi a tutti i task** — il nome di un task apparirà nell'output di ogni esecuzione. Un nome come "Installa e configura nginx con SSL" è infinitamente più utile di "Task 3".

**Usa `ansible_distribution` invece di assumere il sistema operativo** — non dare per scontato che tutti i tuoi server siano Ubuntu. Usa i facts per scrivere playbook portabili.

**Un task, una responsabilità** — ogni task deve fare una sola cosa. Se un task "installa nginx E configura il firewall E crea l'utente", spezzalo in tre task separati.

**Preferisci i moduli ai comandi shell** — usa `apt` invece di `command: apt-get install`, `file` invece di `command: mkdir`, e così via. I moduli sono idempotenti, i comandi shell spesso no.

**Idempotenza** — un playbook ben scritto può essere eseguito più volte e produrre sempre lo stesso risultato senza effetti collaterali. Ansible è progettato per essere idempotente: `state: present` non reinstalla nginx se è già installato.

**Metti i segreti in Ansible Vault** — non scrivere mai password, chiavi API o certificati in chiaro nei file YAML. Usa `ansible-vault encrypt_string` o file cifrati.

```bash
# Cifra una stringa
ansible-vault encrypt_string 'password123' --name 'db_password'

# Cifra un intero file
ansible-vault encrypt vars/secrets.yml

# Esegui playbook con vault
ansible-playbook site.yml --ask-vault-pass
```

**Usa il verbose per capire i problemi** — quando qualcosa non funziona, aggiungi `-vvv` per vedere ogni dettaglio della comunicazione SSH e dell'esecuzione dei moduli.

---

## Esercizi per principianti

### Esercizio 1 — Primo contatto con YAML

Scrivi un file YAML valido che rappresenti il seguente scenario: una lista di tre server, ciascuno con nome, indirizzo IP, sistema operativo e lista di servizi in esecuzione. Validalo con `python3 -c "import yaml; yaml.safe_load(open('servers.yml'))"`.

---

### Esercizio 2 — Inventory e ping

1. Crea un file `hosts.ini` con almeno un server (può essere `localhost`).
2. Esegui `ansible all -i hosts.ini -m ping` e verifica la risposta.
3. Aggiungi un gruppo `[test]` e verifica con `ansible test -i hosts.ini -m ping`.
4. Usa `ansible all -i hosts.ini -m setup | grep ansible_distribution` per vedere i facts raccolti.

---

### Esercizio 3 — Playbook base: configurazione sistema

Scrivi un playbook che, su un server Linux:

1. Aggiorna la cache dei pacchetti
2. Installa `vim`, `curl` e `htop`
3. Crea una directory `/opt/test` con permessi `0755`
4. Crea un file `/opt/test/README.txt` con contenuto a scelta
5. Verifica che nginx non sia installato (usa `state: absent`)

Eseguilo prima con `--check` poi senza.

---

### Esercizio 4 — Variabili e condizioni

1. Scrivi un playbook con una variabile `installa_nginx: true`.
2. Aggiungi un task che installa nginx solo se la variabile è `true`.
3. Aggiungi un task che stampa "nginx installato" o "nginx non installato" in base alla variabile.
4. Prova a sovrascrivere la variabile da riga di comando con `-e "installa_nginx=false"`.

---

### Esercizio 5 — Handlers e notifiche

1. Scrivi un playbook che installa nginx.
2. Copia un file di configurazione nginx fittizio in `/etc/nginx/nginx.conf`.
3. Aggiungi un handler che ricarica nginx quando la configurazione cambia.
4. Esegui il playbook due volte: verifica che il ricaricamento avvenga solo alla prima esecuzione (o quando il file cambia effettivamente).

---

### Esercizio 6 — Role: nginx

1. Crea la struttura di directory per un role chiamato `webserver`.
2. Nel role, scrivi i task per: installare nginx, copiare un template di configurazione, avviare il servizio.
3. Crea un file `defaults/main.yml` con variabili di default (porta, nome del server…).
4. Usa il role in un playbook principale `site.yml`.

---

### Esercizio 7 — Playbook completo: LAMP stack

Scrivi un playbook che configuri un server con:

1. Apache (o nginx) come web server
2. MySQL (o MariaDB) come database
3. PHP come runtime
4. Un database e un utente MySQL creati con i moduli Ansible
5. Una pagina `info.php` distribuita sul server

Usa variabili per tutte le password, porte e nomi.

---

## Domande di verifica

**YAML**

1. Qual è la differenza tra `|` e `>` nelle stringhe multilinea YAML?
2. Come si scrive una lista inline in YAML?
3. Perché YAML non accetta tabulazioni per l'indentazione?

**Concetti Ansible**

4. Cos'è il control node e cos'è un managed node?
5. Cosa significa "agentless" e perché è un vantaggio?
6. Cosa sono i "facts" e come li raccoglie Ansible?
7. Cos'è l'idempotenza e perché è importante in Ansible?

**Playbook e task**

8. Qual è la differenza tra `command` e `shell`? Quando usare l'uno o l'altro?
9. Quando viene eseguito un handler? Cosa succede se lo stesso handler viene notificato più volte nello stesso play?
10. Cosa fa il parametro `register` in un task?
11. Qual è la differenza tra `vars` e `defaults` in un role?

**Variabili e condizioni**

12. In quale ordine di priorità Ansible risolve le variabili (da quella con priorità più bassa a quella più alta)?
13. Come si accede a un fact nested come l'indirizzo IPv4 del sistema?
14. Come si esegue un task solo su server Debian ma non Ubuntu?

**Comandi**

15. Cosa fa il flag `--check`? Ha limitazioni?
16. Come si esegue solo i task con il tag `deploy` ignorando gli altri?
17. Cosa fa `ansible-vault` e in quale scenario è indispensabile?
ENDOFFILE
echo "done"
