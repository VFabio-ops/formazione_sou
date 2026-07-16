# MariaDB Backup/Restore Lab 

## Obiettivo del lab

Catena end-to-end su due VM:

1. Istanza MariaDB con dati di test (sorgente)
2. Backup del database
3. Restore su una seconda istanza (destinazione)
4. Verifica di consistenza dei dati
5. Orchestrazione con Ansible + credenziali in Ansible Vault
6. Integrazione dei playbook in AWX

## Ambiente

| Elemento | Valore |
|----------|--------|
| Provisioning | Vagrant + VirtualBox |
| Box | bento/ubuntu-24.04 |
| VM sorgente | m1 - 192.168.100.3 |
| VM destinazione | m2 - 192.168.100.2 |
| Database engine | MariaDB 10.11 (repo Ubuntu 24.04) |
| Database applicativo | shopdb (utf8mb4) |
| Utente applicativo | shopuser (password locale, da spostare in Vault) |
| Tabelle | customers, orders (orders.customer_id -> customers.id) |
| Dati di test | 1000 clienti, 5000 ordini (deterministici) |

### Fase 1 - Setup e popolamento (m1)

Installazione e messa in sicurezza:

```bash
sudo apt update
sudo apt install -y mariadb-server mariadb-client
sudo mariadb-secure-installation   # rimossi utenti anonimi, db test, root remoto
```

Nota: su Ubuntu l'utente root del DB usa autenticazione unix_socket. Si
amministra con `sudo mariadb`, senza password. Root e' rimasto su socket per
scelta; le password sono riservate all'utente applicativo.

Creazione database e utente dedicato:

```sql
CREATE DATABASE shopdb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'shopuser'@'localhost' IDENTIFIED BY '<password>';
GRANT ALL PRIVILEGES ON shopdb.* TO 'shopuser'@'localhost';
```

Lo scope `shopdb.*` limita l'utente al solo database applicativo (principio del
minimo privilegio). Lo scope `@'localhost'` indica connessione via socket locale.

Popolamento: schema (customers, orders con foreign key) e seeding tramite una
stored procedure con due cicli WHILE. Dati deterministici, indispensabili per la
verifica di consistenza tramite checksum. Caricato come utente applicativo:

```bash
mariadb -u shopuser -p shopdb < /tmp/seed.sql
mariadb -u shopuser -p shopdb -e "SELECT COUNT(*) FROM customers; SELECT COUNT(*) FROM orders;"
# risultato atteso: 1000 clienti, 5000 ordini
```

### Fase 2 - Backup (m1)

```bash
mkdir -p ~/backups
sudo mariadb-dump \
  --single-transaction \
  --routines --triggers --events \
  --databases shopdb \
  --result-file=/home/vagrant/backups/shopdb.sql
sha256sum ~/backups/shopdb.sql   # impronta di integrita' annotata
```

Opzioni chiave:

- `--single-transaction`: backup consistente senza lock, sfruttando il MVCC di
  InnoDB. Cattura una fotografia coerente del DB mentre le scritture proseguono.
  Valido solo su tabelle transazionali (le nostre sono InnoDB).
- `--databases shopdb`: include `CREATE DATABASE` e `USE`, cosi' il dump ricrea
  il database da solo in fase di restore.
- `--routines --triggers --events`: include routine, trigger ed event, che di
  default non finirebbero nel dump.

### Fase 3 - Restore (m2)

Su m2: installazione e hardening di MariaDB con gli stessi passi della Fase 1.

Trasferimento del dump tramite la cartella condivisa di Vagrant (`/vagrant`,
montata su entrambe le VM). Import come root via socket:

```bash
sha256sum /vagrant/shopdb.sql          # confronto con l'hash di m1
sudo mariadb < /vagrant/shopdb.sql
sudo mariadb -e "SELECT COUNT(*) FROM shopdb.customers; SELECT COUNT(*) FROM shopdb.orders;"
# risultato atteso: 1000 clienti, 5000 ordini
```

## Prossimo passo immediato - Fase 4

Il conteggio righe conferma la quantita', non l'identita' del contenuto. Per
dimostrare che il restore e' fedele, confrontare i CHECKSUM TABLE tra le due VM.

Su m1 e su m2 eseguire:

```bash
sudo mariadb -e "USE shopdb; CHECKSUM TABLE customers, orders;"
```

I valori di checksum devono coincidere tra m1 e m2. Se coincidono, i dati sono
identici a livello di contenuto e la consistenza e' dimostrata.

## Note tecniche da ricordare

- Root MariaDB su Ubuntu usa unix_socket: amministrazione con `sudo mariadb`.
- L'identita' di un utente e' la coppia `nome@host`; `localhost` significa
  connessione via socket, diversa da `127.0.0.1` (TCP).
- Con `CREATE USER` e `GRANT` non serve `FLUSH PRIVILEGES`.
- Gli utenti e i loro privilegi non sono inclusi in un dump del solo database
  applicativo.
- `--single-transaction` funziona solo con tabelle transazionali (InnoDB).
- Verificare sempre l'integrita' del dump trasferito con sha256 prima del restore.
