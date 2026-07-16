# MariaDB Backup/Restore Lab - Documentazione

Laboratorio end-to-end che automatizza con Ansible la creazione di due istanze
MariaDB, il popolamento, il backup, il restore su una seconda macchina e la
verifica di consistenza dei dati. Ambiente provisionato con Vagrant, credenziali
protette con Ansible Vault.

Questo documento serve sia come stato del progetto sia come ripasso dei concetti
incontrati durante la costruzione.

## Indice

1. Obiettivo e architettura
2. Ambiente
3. Stato delle task
4. Struttura del progetto
5. Concetti chiave di Ansible
6. I playbook, uno per uno
7. Ansible Vault
8. Come eseguire
9. Verifica di consistenza
10. Note di sicurezza
11. Prossimo passo: AWX

---

## 1. Obiettivo e architettura

La catena completa, in un singolo comando (`ansible-playbook site.yml`):

1. Installazione di MariaDB su due VM
2. Creazione del database applicativo e dell'utente dedicato
3. Popolamento con dati di test
4. Backup logico del database sorgente
5. Restore del backup sulla seconda istanza
6. Verifica che i dati sul target siano identici al sorgente

Ansible gira dall'host (control node), che coordina via SSH le due VM (managed
node). Il control node fa anche da tramite per il trasferimento del dump:

```
        HOST / control node (Mac, dove gira ansible-playbook)
        |
        |  ansible-playbook site.yml
        |
   +----+-----------------+        +------------------------+
   |  m1  192.168.100.3    |        |  m2  192.168.100.2     |
   |  MariaDB (sorgente)   |        |  MariaDB (destinazione)|
   |  popolato + backup    |        |  restore + verifica    |
   +----------+------------+        +-----------+------------+
              |  fetch (m1 -> host)             |  copy (host -> m2)
              +--------> artifacts/shopdb.sql --+
                        verify: CHECKSUM TABLE m1 vs m2
```

## 2. Ambiente

| Elemento | Valore |
|----------|--------|
| Control node | host locale (macOS) con Ansible installato |
| Provisioning VM | Vagrant + VirtualBox |
| Box | bento/ubuntu-24.04 |
| VM sorgente | m1 - 192.168.100.3 |
| VM destinazione | m2 - 192.168.100.2 |
| Database engine | MariaDB 10.11 (repo Ubuntu 24.04) |
| Database applicativo | shopdb (utf8mb4) |
| Utente applicativo | shopuser@localhost (password nel Vault) |
| Tabelle | customers, orders (orders.customer_id -> customers.id) |
| Dati di test | 5 clienti, 5 ordini (scritti a mano in files/seed.sql) |
| Collection Ansible | community.mysql |
| Driver sui managed node | python3-pymysql |

Rete: le VM usano la rete privata (host-only) 192.168.100.0/24, con IP statici.
Le chiavi SSH sono quelle generate da Vagrant, una per VM (il Vagrantfile non
imposta insert_key=false), referenziate direttamente nell'inventario.

## 3. Struttura del progetto

```
playbook/
├── ansible.cfg
├── inventory/
│   ├── hosts.yml
│   └── group_vars/
│       └── all/
│           ├── vars.yml       (in chiaro, committabile)
│           └── vault.yml      (cifrato con ansible-vault)
├── files/
│   └── seed.sql               (schema + dati di test)
├── mariadb.yml                (install del server)
├── database.yml               (database + utente)
├── seed.yml                   (popolamento)
├── backup.yml                 (dump sul sorgente)
├── restore.yml                (restore sul target)
├── verify.yml                 (verifica di consistenza)
├── site.yml                   (orchestratore: importa i 6 playbook)
├── artifacts/                 (dump scaricati, gitignored)
└── .gitignore
```

Ruolo dei file di configurazione:

- ansible.cfg punta l'inventario alla directory `inventory/` (non a un singolo
  file). Puntando alla directory, Ansible carica in automatico anche la
  sottocartella `group_vars/`, dove stanno le variabili condivise e il vault.
- inventory/hosts.yml definisce i gruppi. `db` e' un gruppo-di-gruppi che
  contiene `source` (m1) e `target` (m2). Ogni host porta le sue coordinate di
  connessione: ansible_host (IP privato), ansible_user (vagrant), la chiave
  privata generata da Vagrant, la porta.
- group_vars/all/ contiene variabili applicate a tutti gli host. I due file
  (vars.yml e vault.yml) vengono uniti nello stesso spazio di variabili.

## 4. Concetti chiave di Ansible

Riepilogo dei concetti incontrati costruendo il lab.

Dichiarativo e idempotenza. Un playbook descrive lo stato desiderato, non una
sequenza di comandi. Ansible confronta con lo stato attuale e agisce solo se
serve. Rieseguire lo stesso playbook lascia il sistema uguale (idempotenza):
la seconda esecuzione tende a mostrare tutto `ok` e `changed=0`.

Control node e managed node. Il control node e' dove gira Ansible (l'host). I
managed node sono le macchine gestite (m1, m2). Attenzione a dove vivono le
dipendenze: la collection community.mysql va installata sul control node; il
driver python3-pymysql va installato sui managed node, perche' e' li' che i
moduli mysql_* aprono la connessione al database.

become. Privilege escalation: passare a root sul nodo gestito. Serve perche' ci
si connette come utente vagrant, ma installare pacchetti o amministrare MariaDB
richiede root. Funziona senza password perche' le box Vagrant hanno sudo
passwordless.

Autenticazione unix_socket. Su Ubuntu il root di MariaDB si autentica via socket
Unix: se sei root a livello OS (become: true), MariaDB ti riconosce senza
password. Per questo i moduli usano login_unix_socket e non serve mai scrivere
la password di root da nessuna parte. E' la traduzione di `sudo mariadb`.

gather_facts. All'inizio del play, Ansible puo' raccogliere informazioni
sull'host (OS, IP, RAM...). Si tiene acceso solo se un task usa quei dati;
altrimenti si spegne (gather_facts: false) per non sprecare tempo.

register. Cattura il risultato di un task in una variabile, per riusarlo dopo.
Esempio: `stat` calcola lo sha256 di un file e lo salva in dump_stat; il task
successivo legge dump_stat.stat.checksum.

set_fact e hostvars. set_fact promuove un valore a "fatto dell'host", visibile
anche agli altri play. hostvars e' il dizionario che raccoglie le variabili di
tutti gli host: hostvars['m1'].node_checksums legge il fatto calcolato da m1.
E' il pattern per raccogliere dati da piu' host e poi confrontarli in un punto
unico (nel lab: il play su localhost).

fetch e copy. Sono speculari. fetch scarica un file da un nodo gestito al
control node. copy spinge un file dal control node a un nodo gestito. Il modulo
copy verifica da solo il checksum del file trasferito: se il task riesce, il
file e' arrivato integro.

command e shell. command esegue un programma direttamente, senza shell: piu'
sicuro, ma non capisce redirezioni o pipe. shell esegue dentro una shell,
quindi supporta `<`, `|`, `>`. Nel restore serve `mariadb < file`, quindi si usa
shell; per il dump basta command.

changed_when. Alcuni task (backup, restore) "fanno" sempre qualcosa e non sono
idempotenti per natura. changed_when: true dichiara esplicitamente che il task
cambia lo stato a ogni esecuzione, invece di lasciarlo indovinare ad Ansible.

Template Jinja e filtri. Dentro `{{ }}` Ansible valuta espressioni invece di
stampare testo letterale. La barra `|` incatena filtri (trasformazioni):
`{{ (dump_stat.stat.size / 1024) | round(1) }}` converte byte in KiB e arrotonda.

no_log. Impedisce ad Ansible di stampare i parametri di un task nell'output e
nei log. Usato sul task che gestisce la password dell'utente, per non esporre il
segreto sul terminale.

## 5. I playbook, uno per uno

mariadb.yml (hosts: db). Installa mariadb-server e mariadb-client con state:
present (non latest, per non disallineare le versioni tra m1 e m2), e assicura
che il servizio sia avviato (state: started) e abilitato al boot (enabled: true).
Usa solo moduli ansible.builtin: nessuna dipendenza esterna.

database.yml (hosts: db). Installa python3-pymysql, poi crea il database shopdb
e l'utente shopuser@localhost con privilegi ALL sul solo shopdb (minimo
privilegio). La password arriva dal Vault. Il task dell'utente ha no_log: true.
Gira su entrambi i nodi: l'utente serve anche su m2, perche' gli account non
viaggiano nel dump.

seed.yml (hosts: source). Copia files/seed.sql su m1, lo importa in shopdb con
mysql_db state: import, poi rimuove il file temporaneo. Il file fa DROP TABLE +
CREATE + INSERT: e' un reset deterministico, quindi ogni esecuzione riporta il
DB allo stesso stato (risulta changed, non ok, perche' ricostruisce). Gira solo
sul sorgente: i dati su m2 arriveranno dal restore.

backup.yml (hosts: source). Crea /var/backups/mariadb, esegue mariadb-dump con
--single-transaction (fotografia consistente senza lock, sfrutta il MVCC di
InnoDB) e --databases shopdb (include CREATE DATABASE nel dump, cosi' il file si
ricostruisce da solo). Calcola lo sha256 con stat, lo mostra con debug, e scarica
il dump sul control node in artifacts/ con fetch (flat: true).

restore.yml (hosts: target). Verifica che il dump esista sul control node (stat
con delegate_to: localhost, piu' assert come rete di sicurezza), copia il dump su
m2 con copy (che verifica l'integrita' del trasferimento), e lo importa con shell
`mariadb < file`. Non serve indicare il database: il dump con --databases contiene
gia' CREATE DATABASE e USE, e i DROP TABLE IF EXISTS ripuliscono cio' che c'era.

verify.yml (due play). Primo play (hosts: db): su ogni nodo calcola CHECKSUM
TABLE customers, orders e lo salva come fatto dell'host con set_fact. Secondo play
(hosts: localhost): confronta hostvars['m1'] e hostvars['m2'] con assert. Se i
checksum coincidono, i dati sono bit-identici e la consistenza e' dimostrata.

site.yml. Orchestratore: importa i sei playbook in ordine con import_playbook
(statico, ordine fisso noto). L'ordine codifica le dipendenze: install prima di
database, seed prima di backup, backup prima di restore, restore prima di verify.

## 6. Ansible Vault

La password del database non sta in chiaro in nessun file committabile. Il
pattern usato e' l'indirezione con prefisso vault_:

- inventory/group_vars/all/vars.yml (in chiaro):
  `app_db_password: "{{ vault_app_db_password }}"` - e' solo un puntatore.
- inventory/group_vars/all/vault.yml (cifrato AES256):
  `vault_app_db_password: "<segreto>"` - il valore vero.

Vantaggi: il file cifrato contiene solo variabili vault_*; guardando il file in
chiaro si capisce quali variabili sono coperte dal vault; i task usano il nome
pulito app_db_password senza sapere che e' cifrato.

Ciclo di vita del vault:

```bash
# creazione (scrive gia' cifrato)
ansible-vault create inventory/group_vars/all/vault.yml

# lettura senza modificare
ansible-vault view inventory/group_vars/all/vault.yml

# modifica (decifra, apre nell'editor, ricifra al salvataggio)
ansible-vault edit inventory/group_vars/all/vault.yml

# cambio della password del vault
ansible-vault rekey inventory/group_vars/all/vault.yml
```

La password del vault viene fornita a ogni esecuzione con --ask-vault-pass.

Attenzione: vault.yml e' committabile (e' cifrato). Il file .vault_pass, se mai
lo si usasse per non digitare la password, non deve MAI finire su Git.

## 7. Come eseguire

Prerequisiti (una tantum):

```bash
# collection sul control node
ansible-galaxy collection install -r requirements.yml
# oppure: ansible-galaxy collection install community.mysql

# VM su
vagrant up
```

Catena completa (dalla radice del progetto, dove sta ansible.cfg):

```bash
ansible-playbook site.yml --ask-vault-pass
```

Singole fasi:

```bash
ansible-playbook mariadb.yml  --ask-vault-pass
ansible-playbook database.yml --ask-vault-pass
ansible-playbook seed.yml     --ask-vault-pass
ansible-playbook backup.yml   --ask-vault-pass
ansible-playbook restore.yml  --ask-vault-pass
ansible-playbook verify.yml   --ask-vault-pass
```

Verifiche ad-hoc utili:

```bash
# connettivita'
ansible db -m ping

# struttura dell'inventario
ansible-inventory --graph

# dry-run (simula senza modificare)
ansible-playbook site.yml --check --diff --ask-vault-pass

# conteggio dati
ansible source -m command -a "mariadb -N -e 'SELECT COUNT(*) FROM shopdb.customers;'" --become --ask-vault-pass
```

Come leggere il PLAY RECAP: `ok` conta tutti i task riusciti (changed incluso,
changed e' un sottoinsieme di ok). Nei playbook dichiarativi la seconda
esecuzione tende a changed=0. Nei playbook di backup/restore/seed changed>0 e'
normale e atteso: quei task "fanno" qualcosa a ogni run.

## 8. Verifica di integrità

Guardare a occhio cinque righe non basta a garantire che due copie siano uguali:
su grandi volumi una differenza minima passerebbe inosservata. CHECKSUM TABLE
calcola un'impronta numerica dell'intero contenuto (e struttura) di una tabella:
se anche un solo byte differisce, l'impronta cambia. Confrontare due numeri e'
un test insindacabile. verify.yml calcola i checksum su m1 e m2 e li confronta:
se coincidono, il restore e' fedele. Se un giorno divergessero con righe
apparentemente uguali, il primo sospetto sarebbe una differenza di schema.