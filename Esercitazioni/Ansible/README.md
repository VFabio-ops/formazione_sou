# Esercitazioni Ansible

Riepilogo degli esercizi svolti: gestione di segreti con Ansible Vault, creazione utenti tramite loop, installazione pacchetti da dictionary, e generazione di configurazioni dinamiche con template Jinja2.

## Struttura del progetto

```
Ansible/
├── ansible.cfg
├── hosts.yml            (inventory)
├── value.yml             (Vault cifrato)
├── esercizi.yml          (playbook principale)
├── templates/
│   ├── limits.j2
│   └── whitelist.j2
└── Vagrantfile           (macchine di test)
```

## 1. Ansible Vault

Obiettivo: memorizzare variabili sensibili (`user_name`, `user_pass`) in modo cifrato e usarle in un playbook.

### Creazione del Vault

```bash
ansible-vault create value.yml
```

Il comando chiede una password e apre un editor. Contenuto in chiaro (prima della cifratura):

```yaml
user_name: pippo
user_pass: supersegreta
```

Una volta salvato, il file su disco risulta cifrato con AES256:

```
$ANSIBLE_VAULT;1.1;AES256
64346363643636623865...
```

### Inclusione nel playbook

```yaml
vars_files:
  - value.yml
```

### Esecuzione con richiesta password

```bash
ansible-playbook --ask-vault-pass esercizi.yml
```

Il flag `--ask-vault-pass` fa comparire il prompt della password del Vault, necessaria per decifrare `value.yml` a runtime.

### Stampa a video

```yaml
- name: Check for Variables
  ansible.builtin.debug:
    msg: "{{ user_name }} {{ user_pass }}"
```

## 2. Inventory con ambienti separati

Per distinguere produzione da sviluppo, gli host sono raggruppati nell'inventory:

```yaml
all:
  children:
    produzione:
      hosts:
        buntu-prod:
          ansible_host: 192.168.100.3
          ansible_user: vagrant
    sviluppo:
      hosts:
        buntu:
          ansible_host: 192.168.100.2
          ansible_user: vagrant
```

```
                inventory (hosts.yml)
                        |
          -------------------------------
          |                             |
      produzione                    sviluppo
          |                             |
      buntu-prod                     buntu
```

Nel playbook, la magic variable `group_names` permette di sapere a quale gruppo appartiene l'host in esecuzione:

```yaml
when: "'produzione' in group_names"
```

## 3. Installazione pacchetti da dictionary

Struttura dati: un dizionario `chiave: stato` invece di una semplice lista.

```yaml
vars:
  packages:
    curl: present
    wget: present
    python3: latest
    htop: present
```

Il filtro `dict2items` trasforma ogni coppia in un oggetto con proprietà `key` e `value`, iterabile con `loop`:

```yaml
- name: Install tool
  ansible.builtin.apt:
    update_cache: true
    name: "{{ item.key }}"
    state: "{{ item.value }}"
  loop: "{{ packages | dict2items }}"
```

```
packages (dict)              dict2items                loop
-----------------            ---------->     item.key / item.value
curl: present                                 curl / present
wget: present                                 wget / present
python3: latest                               python3 / latest
htop: present                                 htop / present
```

## 4. Creazione utenti da lista di dictionary

Struttura dati: una lista, dove ogni elemento è già un dizionario con più campi.

```yaml
vars:
  users:
    - name: "{{ user_name }}"
      shell: "/bin/bash"
      group: sudo
      home: "/home/{{ user_name }}"
      password: "{{ user_pass | password_hash('sha512') }}"
    - name: Pluto
      shell: "/bin/sh"
      group: sudo
      home: "/home/Pluto"
      password: "{{ user_pass | password_hash('sha512') }}"
```

Qui non serve `dict2items` (la struttura è già una lista): si accede direttamente ai campi con `item.campo`.

```yaml
- name: Creazione utenti
  ansible.builtin.user:
    name: "{{ item.name }}"
    shell: "{{ item.shell }}"
    group: "{{ item.group }}"
    home: "{{ item.home }}"
    password: "{{ item.password }}"
  loop: "{{ users }}"
```

Nota sulla password: il modulo `user` richiede un hash, non testo in chiaro. Il filtro `password_hash('sha512')` calcola l'hash a runtime, mantenendo la password in chiaro solo dentro il Vault.

Nota sullo scope: le `vars:` definite dentro un singolo task sono visibili solo in quel task. Per riusare `users` in altri task (come nell'esercizio con `blockinfile`), va dichiarata a livello di play, insieme a `vars_files`.

## 5. Template Jinja2 per configurazioni dinamiche

### Limite di file aperti (limits.conf)

Il contenuto della configurazione cambia in base all'ambiente, quindi la logica va nel template invece che nel playbook.

`templates/limits.j2`:

```jinja
{% if 'produzione' in group_names %}
{{ user_name }} hard nofile 10000
{% else %}
{{ user_name }} hard nofile 1000
{% endif %}
```

Task nel playbook, con `blockinfile` per fare un append controllato senza duplicare righe:

```yaml
- name: Limite file aperti
  ansible.builtin.blockinfile:
    path: /etc/security/limits.conf
    block: "{{ lookup('template', 'limits.j2') }}"
```

### Whitelist utenti (access.conf)

`templates/whitelist.j2`:

```jinja
{% for u in users %}
+ : {{ u.name }} : ALL
{% endfor %}
```

Task nel playbook, con `insertbefore` per posizionare il blocco prima della riga che blocca tutti gli accessi non autorizzati:

```yaml
- name: Whitelist utenti in access.conf
  ansible.builtin.blockinfile:
    path: /etc/security/access.conf
    block: "{{ lookup('template', 'whitelist.j2') }}"
    insertbefore: "^- : ALL : ALL$"
```

```
access.conf (prima)              access.conf (dopo)
------------------                ------------------
...                                ...
- : ALL : ALL                      + : pippo : ALL
                                    + : Pluto : ALL
                                    - : ALL : ALL
```

## Concetti chiave riassunti

| Concetto | A cosa serve |
|---|---|
| Ansible Vault | Cifrare variabili/file sensibili |
| `vars_files` | Includere file di variabili (anche cifrati) nel playbook |
| `--ask-vault-pass` | Chiedere la password del Vault a runtime |
| `loop` | Ripetere un task su più elementi |
| `dict2items` | Trasformare un dizionario in lista iterabile (`item.key`/`item.value`) |
| `group_names` | Sapere a quale gruppo di inventory appartiene l'host corrente |
| `password_hash` | Calcolare l'hash di una password a runtime |
| `lineinfile` | Assicurare la presenza di una singola riga in un file |
| `blockinfile` | Gestire un blocco di più righe, con inserimento posizionato (`insertbefore`) |
| `lookup('template', ...)` | Renderizzare un file `.j2` e usarne l'output come valore di un parametro |

## Playbook finale (esercizi.yml)

```yaml
- hosts: all
  become: true
  gather_facts: true
  connection: ssh
  vars_files:
    - value.yml
  vars:
    users:
      - name: "{{ user_name }}"
        shell: "/bin/bash"
        group: sudo
        home: "/home/{{ user_name }}"
        password: "{{ user_pass | password_hash('sha512') }}"
      - name: Pluto
        shell: "/bin/sh"
        group: sudo
        home: "/home/Pluto"
        password: "{{ user_pass | password_hash('sha512') }}"
  tasks:
    - name: Check for Variables
      ansible.builtin.debug:
        msg: "{{ user_name }} {{ user_pass }}"

    - name: Install tool
      ansible.builtin.apt:
        update_cache: true
        name: "{{ item.key }}"
        state: "{{ item.value }}"
      loop: "{{ packages | dict2items }}"
      vars:
        packages:
          curl: present
          wget: present
          python3: latest
          htop: present

    - name: Creazione utenti
      ansible.builtin.user:
        name: "{{ item.name }}"
        shell: "{{ item.shell }}"
        group: "{{ item.group }}"
        home: "{{ item.home }}"
        password: "{{ item.password }}"
      loop: "{{ users }}"

    - name: Limite file aperti
      ansible.builtin.blockinfile:
        path: /etc/security/limits.conf
        block: "{{ lookup('template', 'limits.j2') }}"

    - name: Whitelist utenti in access.conf
      ansible.builtin.blockinfile:
        path: /etc/security/access.conf
        block: "{{ lookup('template', 'whitelist.j2') }}"
        insertbefore: "^- : ALL : ALL$"
```