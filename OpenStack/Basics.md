# OpenStack — Riassunto dei concetti base

## Modello mentale

OpenStack e' un cloud privato IaaS: un insieme di servizi indipendenti che insieme
permettono di offrire VM, reti e dischi a richiesta, tramite API o interfaccia web.

Idea chiave: non c'e' un cervello centrale. Ogni servizio ha una propria API REST,
un proprio database, dei worker sui nodi, e comunica con gli altri tramite una coda
di messaggi (RabbitMQ). Keystone fa da collante (autenticazione + catalogo servizi).

Topologia dei nodi:

- Control plane (controller node): API dei servizi, database, coda messaggi, dashboard.
  E' il cervello. Non ci girano le VM degli utenti.
- Compute node: server che ospitano le VM (hypervisor + agente nova-compute).
Frase da ricordare: servizi specializzati, tenuti insieme da Keystone, che comunicano
via API e coda di messaggi, divisi tra un control plane che comanda e compute node che eseguono.

---

## Keystone — Identity (permessi)

Compito: autenticazione (sei chi dici di essere?) e autorizzazione (puoi fare questo, qui?).
Tutti gli altri servizi delegano a lui. E' la porta d'ingresso, si studia per primo.

Mattoni dell'identita':

- Utente (user): chi si autentica (persona o servizio).
- Progetto (project, ex tenant): contenitore delle risorse e unita' di isolamento.
  Le VM/reti/dischi appartengono a un progetto.
- Ruolo (role): admin, member, reader. Non e' una proprieta' dell'utente da solo:
  e' la terna utente + progetto + ruolo. Stesso utente puo' avere ruoli diversi su progetti diversi.
- Dominio (domain): contenitore piu' esterno di utenti e progetti. In setup semplici e' solo "Default".
Token: dopo l'autenticazione Keystone rilascia un token, una stringa cifrata che contiene
chi sei, in quale progetto, con quale ruolo e fino a quando vale (scade, tipo 1 ora).
Lo alleghi a ogni richiesta successiva: gli altri servizi non chiedono la password, validano il token.
I token moderni sono "Fernet" (cifrati, non gonfiano il database).

Service catalog: Keystone tiene anche l'elenco dei servizi e i loro endpoint (dove trovarli).
Client e servizi si trovano a vicenda cosi'. Endpoint tipici: public, internal, admin.

Doc: <https://docs.openstack.org/keystone/latest/>

---

## Glance — Image service (immagini)

Compito: catalogo delle immagini. Da qui Nova prende lo "stampo" per creare il disco di ogni VM.

Immagine: un disco virtuale con un SO gia' installato, impacchettato in un file.
Non e' un programma: e' il contenuto di un disco, pronto per essere copiato e acceso.

ISO vs cloud image:

- ISO (ISO 9660): immagine di un CD/DVD, sola lettura, e' un supporto di INSTALLAZIONE
  (installer + pacchetti). Nel cloud NON si usa.
- Cloud image (raw, qcow2): rappresenta un HARD DISK con il SO gia' pronto. E' cio' che si usa.
- Analogia: ISO = cantiere/CD, cloud image = casa prefabbricata/hard disk.
cloud-init: al primo avvio configura la VM con i dati che TU passi al momento della creazione
(chiavi SSH, hostname, utenti), ricevuti tramite un servizio di metadati. E' il motivo per cui
100 VM diverse possono nascere dalla stessa identica immagine.

Formati:

- raw: copia grezza byte per byte del disco. Semplice, veloce, ma anche i blocchi vuoti
  occupano spazio (salvo sparse file).
- qcow2 (QEMU Copy-On-Write v2): contenitore con tabella di mappatura. Vantaggi:
  thin provisioning (solo i blocchi scritti occupano spazio), backing image (poggia su
  un'immagine di base e salva solo le differenze -> 100 VM da un unico stampo), snapshot, compressione.
  Costo: un filo piu' lento per l'indirezione.
Nota: Glance gestisce i metadati (nome, formato, permessi); i byte veri stanno in un backend
di storage separato (disco locale, Swift, spesso Ceph in produzione).
Visibilita' immagini: pubblica, privata o condivisa con progetti specifici.

Doc: <https://docs.openstack.org/glance/latest/>

---

## Nova — Compute (il cuore)

Compito: direttore d'orchestra del compute. Mette insieme gli ingredienti e sorveglia la VM.
Nova NON e' l'hypervisor: comanda un hypervisor tramite un "virt driver".
Hypervisor predefinito: KVM, pilotato tramite la libreria libvirt (virt_type configurabile:
KVM, QEMU, LXC, Xen). Altri driver: VMware vSphere, Hyper-V, Ironic (bare metal). In pratica: 95% KVM via libvirt.

Concetti utente:

- Istanza (instance): la VM in esecuzione (il risultato finale).
- Flavor: la TAGLIA dell'hardware virtuale (vCPU, RAM, disco). Un menu' di taglie predefinite.
- IMPORTANTE: flavor e immagine sono assi indipendenti.
  Immagine = COSA c'e' dentro (il SO). Flavor = QUANTO grande e' la macchina che lo esegue.
  Stessa immagine su flavor diversi; stesso flavor con immagini diverse.
Formula: istanza = immagine (Glance) + flavor (taglia) + rete (Neutron), piazzata su un host.

Componenti interni:

- nova-api: porta d'ingresso. Riceve e valida la richiesta, controlla il token, mette in coda.
  Non aspetta: la VM parte in stato BUILD e si costruisce dietro le quinte.
- nova-conductor: coordinatore. Orchestra i passaggi e fa da tramite verso il database.
  I nova-compute NON toccano il DB direttamente (scelta di sicurezza): passano dal conductor.
- nova-scheduler: decide SU QUALE host va la VM. Si appoggia a Placement.
- nova-compute: sul compute node. Recupera immagine (Glance), rete (Neutron), eventuale volume (Cinder),
  e comanda l'hypervisor a creare/avviare la VM. A fine boot -> stato ACTIVE.
Placement: tiene l'inventario aggiornato delle risorse (CPU, RAM, disco) di ogni host e di
quanto e' libero. Fornisce allo scheduler la rosa di host possibili. Senza Placement lo scheduler e' cieco.

Scheduling in due tempi:

- Filtri (filters): eliminano gli host inadatti (poca RAM, in manutenzione, senza GPU richiesta...).
- Pesi (weighers): danno un punteggio ai sopravvissuti secondo una politica
  (consolidare su pochi host o bilanciare su tutti). Vince il punteggio piu' alto.
Ciclo di vita (dopo ACTIVE): pausa/sospensione, snapshot (diventa una nuova immagine in Glance),
resize (flavor piu' grande), migrazione a freddo o live (sposta la VM accesa, utile per manutenzione).

Doc: <https://docs.openstack.org/nova/latest/>

---

## Neutron — Networking (la rete)

Compito: costruire reti virtuali self-service, isolate per progetto, con API come il resto.

Mattoni di base (dal basso verso l'alto). Catena: istanza -> port -> subnet -> network.

- Network: switch virtuale (L2). Solo il "cavo condiviso", senza indirizzi.
- Subnet: intervallo di IP e config agganciati a una network (CIDR es. 192.168.1.0/24,
  gateway, DHCP, DNS). E' il livello 3 (IP).
- Port: scheda di rete virtuale (la presa). Porta MAC + IP preso dalla subnet.
  L'istanza si attacca alla rete attraverso una port.
Tipi di rete:
- Rete tenant/privata (self-service): la crea il progetto, e' isolata, IP privati visibili solo li'.
- Rete esterna/provider: collegata alla rete fisica reale, ha sbocco su Internet. Da qui gli IP pubblici.
Router e NAT:
- Le VM su rete privata hanno solo IP privati.
- In uscita (VM naviga): il router fa SNAT automatico, le VM escono mascherate dietro l'IP del router.
- In entrata (raggiungere la VM da fuori, es. SSH): serve un floating IP, un IP pubblico
  della rete esterna che ASSOCI alla VM (NAT 1:1). E' mobile: si stacca e si riattacca a un'altra VM.
  A monte serve un router che colleghi rete privata ed esterna.
Security group: firewall a livello di port (attaccato alle schede delle istanze).
Definisce il traffico ammesso in entrata/uscita. E' stateful (la risposta a una connessione permessa
rientra da sola). DEFAULT: blocca tutto in entrata -> nuova VM, SSH non funziona finche' non apri la porta 22.
Primo posto da controllare quando non ti connetti.

Sotto il cofano: architettura a plugin, standard ML2 (Modular Layer 2); il meccanismo che realizza
la rete e' Open vSwitch (OVS) o, nelle installazioni moderne, OVN (Open Virtual Network).

Doc: <https://docs.openstack.org/neutron/latest/>
Guida admin/networking: <https://docs.openstack.org/neutron/latest/admin/>

---

## Schema di una richiesta "crea una VM"

1. Utente (CLI/Horizon) si autentica su Keystone -> ottiene il token.
2. nova-api riceve la richiesta (col token), valida, mette in coda.
3. nova-conductor coordina; nova-scheduler sceglie l'host (filtri + weigher, tramite Placement).
4. nova-compute sull'host scelto: prende immagine da Glance, rete da Neutron (eventuale volume da Cinder).
5. nova-compute comanda l'hypervisor (KVM via libvirt) -> la VM parte -> stato ACTIVE.
