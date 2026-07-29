# MariaDB Backup/Restore Lab - Documentazione finale

Pipeline end-to-end che, con un solo clic in AWX, installa MariaDB su due VM,
popola i dati, esegue un backup consistente, lo restaura su una seconda istanza
e dimostra con i checksum che i dati sono identici. Infrastruttura provisionata
con Vagrant, orchestrata con Ansible, credenziali protette con Ansible Vault,
esecuzione da interfaccia web con AWX su Kubernetes.

Questo documento copre l'intero progetto e serve sia da riferimento tecnico sia
da ripasso dei concetti.

## Indice

1. Risultato finale
2. Architettura completa
3. Ambiente e versioni
4. Struttura del repository
5. Fase Ansible: i playbook
6. Fase AWX: dall'installazione al Workflow
7. Il ponte di rete (il nodo concettuale di AWX)
8. Concetti chiave
9. Come eseguire tutto
10. Riproducibilita' da zero
11. Problemi incontrati e soluzioni
12. Note di sicurezza
13. Stato delle task

---

## 1. Risultato finale

Un Workflow AWX in sei nodi che esegue in cascata, ognuno solo se il precedente
riesce (transizioni "on success"):

```
01-install -> 02-database -> 03-seed -> 04-backup -> 05-restore -> 06-verify
```

Il flusso verde significa non solo "eseguito", ma "backup e restore avvenuti e
dati dimostrati identici", perche' l'ultimo nodo (verify) fallisce se i
CHECKSUM TABLE tra le due macchine divergono. La verifica di consistenza e'
quindi incorporata come condizione di successo dell'intera pipeline.

## 2. Architettura completa

Tre livelli di virtualizzazione sullo stesso portatile, collegati da un ponte
di rete costruito ad hoc:

```
   HOST (macOS)
   |
   |-- VirtualBox: rete host-only 192.168.100.0/24
   |       |-- m1  192.168.100.3   (MariaDB sorgente)
   |       |-- m2  192.168.100.2   (MariaDB destinazione)
   |       forward: host:2201 -> m1:22   host:2202 -> m2:22
   |
   |-- Docker Desktop
           |-- minikube (Kubernetes)
                   |-- AWX (web, task, postgres)
                           |-- pod job effimeri (execution environment)

   Connessione AWX -> VM:
     pod AWX -> host.minikube.internal (= Mac) -> forward -> VM:22

   Trasferimento del dump (NON passa dal control node, effimero):
     m1 --- scp diretto sulla rete privata ---> m2
```

Il punto chiave dell'architettura finale: il backup del database non transita mai
per il control node (che in AWX e' un container usa-e-getta), ma viaggia
direttamente tra le due VM, che sono persistenti.

## 3. Ambiente e versioni

| Elemento | Valore |
|----------|--------|
| Host | macOS |
| Provisioning | Vagrant + VirtualBox |
| Box | bento/ubuntu-24.04 |
| Database | MariaDB 10.11 |
| VM sorgente | m1 - 192.168.100.3 (SSH forward host:2201) |
| VM destinazione | m2 - 192.168.100.2 (SSH forward host:2202) |
| Chiave SSH | insecure key condivisa (insert_key=false) |
| DB applicativo | shopdb (utf8mb4) |
| Utente applicativo | shopuser (password nel Vault) |
| Tabelle | customers, orders (FK orders.customer_id -> customers.id) |
| Dati di test | 5 clienti, 5 ordini |
| Kubernetes locale | minikube (driver Docker) |
| AWX | AWX Operator 2.19.1, istanza awx-demo |
| Accesso UI | service LoadBalancer + minikube tunnel |

## 4. Struttura del repository

Il lab vive in una sottocartella di un repo piu' grande. Questo ha imposto due
accorgimenti specifici per AWX:

```
<repo-root>/
├── collections/
│   └── requirements.yml            # <-- alla RADICE del repo (per AWX)
└── Esercitazioni/Backup/playbook/  # il lab
    ├── ansible.cfg                 # usato solo dalla CLI locale
    ├── inventory/
    │   └── hosts.yml               # host + chiavi locali (solo CLI)
    ├── group_vars/                 # <-- SPOSTATO qui, accanto ai playbook
    │   └── all/
    │       ├── vars.yml            # variabili in chiaro
    │       └── vault.yml           # cifrato con ansible-vault
    ├── files/
    │   └── seed.sql                # schema + dati di test
    ├── mariadb.yml
    ├── database.yml
    ├── seed.yml
    ├── backup.yml                  # backup + scp diretto m1->m2
    ├── restore.yml                 # import sul target
    ├── verify.yml                  # CHECKSUM TABLE m1 vs m2
    └── site.yml                    # orchestratore per la CLI
```

Due scelte non ovvie, entrambe dettate da AWX:

- `group_vars` sta accanto ai playbook, non dentro `inventory/`. In AWX
  l'inventario e' un oggetto AWX, non il file, quindi il caricamento
  "group_vars accanto all'inventario" non scatta; funziona invece
  "group_vars accanto al playbook", che vale sia in CLI sia in AWX.
- `collections/requirements.yml` sta alla radice del repo, non nella
  sottocartella: AWX lo cerca li' relativamente alla radice del progetto.

## 5. Fase Ansible: i playbook

Tutti i play usano `become: true` (root via sudo passwordless delle box
Vagrant) e si autenticano a MariaDB come root via unix_socket.

mariadb.yml (hosts: db) - installa mariadb-server/-client (state: present, non
latest, per non disallineare le versioni tra i nodi) e assicura il servizio
avviato e abilitato. Solo moduli ansible.builtin, nessuna dipendenza.

database.yml (hosts: db) - installa python3-pymysql, crea shopdb e
shopuser@localhost con privilegi ALL sul solo shopdb. Password dal Vault, task
utente con no_log. Gira su entrambi i nodi (l'utente non viaggia nel dump).

seed.yml (hosts: source) - copia files/seed.sql su m1 e lo importa. Reset
deterministico (DROP+CREATE+INSERT): ogni run riporta il DB allo stesso stato.

backup.yml (hosts: source) - la parte riscritta per AWX. Sequenza:
  1. assicura /var/backups/mariadb (mode 0755, attraversabile da vagrant)
  2. mariadb-dump --single-transaction --databases shopdb (come root)
  3. chown del dump a vagrant (cosi' lo scp non-root puo' leggerlo)
  4. scp del dump direttamente su vagrant@m2:/tmp/ (become: false, per usare
     la chiave SSH di vagrant, non di root)

restore.yml (hosts: target) - verifica con assert che /tmp/shopdb.sql esista
sul target, poi lo importa con `mariadb < /tmp/shopdb.sql` (shell, per la
redirezione). Nessuna copia: il file e' gia' sul target, ce l'ha messo il
backup.

verify.yml (due play) - primo play su hosts: db calcola CHECKSUM TABLE su ogni
nodo e lo salva con set_fact; secondo play su localhost confronta
hostvars['m1'] e hostvars['m2'] con assert. Non tocca file ne' hash: interroga
i database vivi, quindi e' indipendente dal control node effimero.

site.yml - orchestratore per la CLI locale (import_playbook dei sei file). In
AWX questo ruolo lo svolge il Workflow.

## 6. Fase AWX: dall'installazione al Workflow

### Installazione

```bash
brew install minikube kubectl
minikube start --cpus=4 --memory=6g

# AWX Operator via kustomize, versione pinnata
# kustomization.yaml -> resources: github.com/ansible/awx-operator/config/default?ref=2.19.1
#                       images: quay.io/ansible/awx-operator newTag 2.19.1
kubectl apply -k .

# istanza AWX (awx-demo.yml, kind: AWX, service_type: nodeport)
kubectl apply -k .

# password admin
kubectl get secret awx-demo-admin-password -o jsonpath="{.data.password}" | base64 --decode; echo
```

Accesso UI stabile (piu' robusto del port-forward su Mac+Docker):

```bash
kubectl patch svc awx-demo-service -n awx -p '{"spec":{"type":"LoadBalancer"}}'
sudo minikube tunnel        # in una finestra dedicata, lasciata aperta
kubectl get svc awx-demo-service -n awx   # apri l'EXTERNAL-IP:porta
```

### Oggetti configurati in AWX

- Project: repo Git, con "Update Revision on Launch" attivo (git pull a ogni
  job). Legge collections/requirements.yml e installa community.mysql alla sync.
- Credentials:
  - Machine `vagrant-ssh`: username vagrant + chiave privata insecure condivisa.
  - Vault `vault-password`: la password del vault (AWX decifra vault.yml da se').
- Inventory `mariadb-lab`: gruppi source/target/db; host m1 e m2 con
  `ansible_host: host.minikube.internal` e `ansible_port` 2201 / 2202.
- Job Templates 01..06: uno per playbook, ciascuno con inventory mariadb-lab,
  il Project, e le due credenziali (Machine + Vault) agganciate insieme.
- Workflow "MariaDB Backup Lab - Full Pipeline": sei nodi in catena on-success.

## 7. Il ponte di rete (il nodo concettuale di AWX)

I pod AWX girano dentro Kubernetes dentro Docker: una rete isolata che non
raggiunge la host-only 192.168.100.x di VirtualBox. Il ponte sfrutta l'unico
punto comune, il Mac:

- `host.minikube.internal` risolve, dai pod, all'indirizzo del Mac.
- Vagrant inoltra host:2201 -> m1:22 e host:2202 -> m2:22
- Percorso completo: pod AWX -> host.minikube.internal:2201 -> Mac -> forward -> m1:22

Per il dump si e' scelto un percorso diverso e diretto (m1 -> m2 sulla rete
privata) proprio per non dipendere dal control node effimero: ogni job AWX gira
in un container usa-e-getta, quindi un file lasciato "sul control node"
sparirebbe prima del job successivo. Per abilitare m1 -> m2 la chiave privata
insecure e' stata messa in ~/.ssh/id_rsa dell'utente vagrant su m1.

## 8. Concetti chiave

Idempotenza - i playbook descrivono lo stato desiderato; rieseguirli non cambia
nulla se lo stato e' gia' quello (ok, changed=0). Backup/restore/seed fanno
eccezione: "fanno" qualcosa a ogni run, e lo dichiarano con changed_when: true.
Attenzione: changed_when e' una promessa nostra, non prova che l'operazione sia
riuscita; l'esito reale si legge nel return code e nell'output.

Control node vs managed node - le dipendenze vivono in due posti. In AWX il
control node e' l'execution environment: le collection vanno dichiarate in
collections/requirements.yml (installate alla sync). I driver Python (es.
python3-pymysql) vanno invece installati sui managed node dai playbook.

become e unix_socket - become passa a root sul nodo; combinato con
login_unix_socket, MariaDB riconosce root senza password. Ma attenzione a quale
utente possiede la chiave SSH: lo scp m1->m2 richiede become: false per girare
come vagrant (che ha la chiave), non root.

register / set_fact / hostvars - register cattura l'output di un task; set_fact
lo promuove a fatto dell'host visibile agli altri play; hostvars lo legge da un
altro host. E' il pattern del confronto checksum in verify.yml.

command vs shell - command esegue senza shell (niente redirezioni); shell
supporta `<`, `|`, `>`. Il restore usa shell per `mariadb < file`.

delegate_to - esegue un singolo task su un host diverso da quello del play.

Permessi e directory - per leggere un file dentro una directory serve il
permesso di attraversamento (x) sulla directory. Un file di vagrant dentro una
directory 0750 di root resta illeggibile a vagrant finche' la directory non
diventa 0755.

Vault - indirezione con prefisso vault_: vars.yml contiene
`app_db_password: "{{ vault_app_db_password }}"`, vault.yml (cifrato) contiene
il valore vero. In AWX la Vault Credential inietta la password e decifra da se'.

/tmp e' volatile - viene ripulito al reboot e periodicamente. Usarlo come
transito va bene se i job sono consecutivi (come nel Workflow); per un flusso
robusto e' preferibile una directory persistente.

## 9. Come eseguire tutto

Dalla CLI locale (nella cartella del lab):

```bash
ansible-galaxy collection install -r collections/requirements.yml   # (path relativo)
vagrant up
ansible-playbook site.yml --ask-vault-pass
```

Da AWX:

- singola fase: lancia il Job Template desiderato (01..06)
- intera pipeline: lancia il Workflow "MariaDB Backup Lab - Full Pipeline"

## 10. Riproducibilita' da zero

La prova che il lavoro non dipende da aggiustamenti manuali:

```bash
vagrant destroy -f && vagrant up
# poi lancia il Workflow da AWX
```

A macchine vergini i nodi mostreranno changed (installa e popola davvero),
non ok idempotenti. Se anche cosi' il Workflow finisce verde con verify che
passa, l'intera catena e' genuinamente riproducibile.

Nota: dopo un destroy/up, il ponte m1 -> m2 (chiave in ~/.ssh/id_rsa su m1) va
ristabilito, perche' e' stato configurato a mano. La forma piu' pulita sarebbe
un task Ansible che deposita quella chiave all'inizio del backup; e' il naturale
prossimo miglioramento per rendere anche quel pezzo riproducibile.

## 11. Problemi incontrati e soluzioni

Utenti duplicati su m2 al restore - innocuo: il dump usa CREATE DATABASE IF NOT
EXISTS e DROP TABLE IF EXISTS; gli account non viaggiano nel dump.

group_vars non caricati in AWX - spostati da inventory/group_vars a
group_vars/ accanto ai playbook (portabile CLI + AWX).

ansible.cfg ignorato in AWX - AWX esegue dalla radice del repo; il cfg nella
sottocartella non viene letto. Non serve replicarlo: inventario, host key
checking e interpreter li gestisce AWX.

community.mysql assente in AWX - aggiunto collections/requirements.yml alla
radice del repo; installato alla sync del Project (serve una Galaxy credential
sull'Organization, di norma gia' presente sulla Default).

Sidecar operator in ImagePullBackOff - il tag di kube-rbac-proxy non esiste;
sidecar accessorio (metriche), non blocca AWX. Ignorato.

Job fermo in ContainerCreating - primo download dell'execution environment
(awx-ee), lento una tantum; poi in cache.

Reachability AWX -> VM - risolta col ponte host.minikube.internal + forward
2201/2202.

Chiave SSH pubblica al posto della privata in AWX - la Machine Credential vuole
la privata (blocco BEGIN/END), non la pubblica (ssh-rsa ...).

insert_key=false su ambiente gia' creato - non riscrive authorized_keys
esistenti; la chiave insecure e' stata autorizzata a mano (o via destroy/up).

scp Permission denied (local) - il dump di root non era leggibile da vagrant;
risolto con chown a vagrant + directory 0755. Trappola: un secondo task
duplicato rimetteva la directory a 0750 annullando la fix.

Restore assert "dump non trovato" - la rete di sicurezza dell'assert ha fatto
il suo lavoro; causa reale un refuso nel playbook (e attenzione alla volatilita'
di /tmp tra job non consecutivi).

port-forward instabile - sostituito da service LoadBalancer + minikube tunnel.

Progetto completo: dalla creazione manuale di una singola istanza a una pipeline
che si ricostruisce e si verifica da sola con un clic.