# Percorso formativo OpenStack

Percorso di studio strutturato per imparare OpenStack dalla teoria al deploy
pratico, pensato per un profilo DevOps. E' una risorsa condivisibile: puo' essere
seguita in autonomia da un allievo e usata da un tutor per accompagnare e
valutare la formazione di piu' persone.

Ogni modulo ha: prerequisiti, domande guida, tecnologie e concetti, informazioni
chiave, esercizi di recap, una traccia di valutazione e link ufficiali.

---

## Materiali del pacchetto

Questo percorso e' lo scheletro didattico. Va condiviso insieme ai documenti di
supporto, che contengono la teoria di dettaglio e le procedure pratiche:

- `Basics.md` — modello mentale, Keystone, Glance, Nova, Neutron.
- `Extras.md` — i tre tipi di storage, Cinder, Horizon, Swift, Heat.
- `README-openstack-kolla.md` — deploy pratico all-in-one con Kolla-Ansible,
  con precauzioni e guida originale annotata.
- `README_DASH.md` — creazione di un'istanza da dashboard e modello a floating IP.

Chi riceve il percorso dovrebbe ricevere anche questi quattro file.

---

## Per chi usa questo percorso

### Allievo

- Segui i moduli in ordine: ognuno si appoggia ai precedenti.
- Per ogni modulo: leggi i concetti (nel modulo e nei file di supporto), rispondi
  alle domande guida con parole tue, fai gli esercizi di recap sull'ambiente, poi
  affronta la traccia di valutazione.
- Regola di studio: prima capire il concetto (domande), poi vederlo accadere
  (esercizi). La CLI per capire, la dashboard per esplorare, il codice/IaC per
  produrre.
- Sii onesto nell'autovalutazione: spuntare una voce che non sai davvero
  spiegare vanifica il percorso.

### Tutor / mentore

- Usa le domande guida come base per un colloquio breve: chiedi all'allievo di
  spiegare con parole sue, non di ripetere definizioni.
- Usa la prova pratica di ogni modulo come verifica oggettiva: o il criterio di
  riuscita e' soddisfatto o non lo e'.
- Assegna il livello raggiunto (vedi sotto) per capire se l'allievo esegue,
  diagnostica o progetta.
- Il vero segnale di padronanza non e' "il comando ha funzionato", ma "so dire
  quale servizio e' intervenuto e perche'". Valuta soprattutto quello.
- L'appendice finale fornisce tempi stimati e consigli per condurre le verifiche.

---

## Come funziona la valutazione

Ogni modulo si valuta su due componenti:

- Checklist di padronanza: affermazioni verificabili che l'allievo deve saper
  sostenere. Si spuntano solo quando sono vere davvero.
- Prova pratica: un compito con un criterio di riuscita oggettivo ("superato se
  ...").

Il livello raggiunto si misura su tre gradini, validi per tutti i moduli:

- Base: esegue i comandi seguendo la guida e riconosce i concetti.
- Intermedio: diagnostica e risolve quando qualcosa non torna, senza guida passo
  a passo.
- Avanzato: spiega il meccanismo sottostante e sa progettare o adattare la
  soluzione, non solo eseguirla.

Obiettivo minimo del percorso: livello intermedio su tutti i moduli core
(Keystone, Glance, Nova, Neutron, Cinder) e almeno base sui restanti.

---

## Nota sulle versioni (per non creare documentazione in conflitto)

- OpenStack esce a cicli di sei mesi, tipicamente aprile e ottobre. La numerazione
  e' per anno: 2025.1, 2025.2, 2026.1, e cosi' via. Ogni release ha anche un nome
  in codice (es. 2025.1 = "Epoxy", 2026.1 = "Gazpacho").
- Alla stesura, la release corrente e' 2026.1; la 2026.2 e' in sviluppo. La 2025.1
  usata nel laboratorio e' ancora supportata.
- Alcune release sono SLURP (Skip-Level Upgrade Release Process), pensate per
  aggiornamenti a salto di versione: 2025.1 e' una di queste.
- IMPORTANTE: `https://docs.openstack.org` senza numero di versione mostra sempre
  l'ULTIMA release. Se l'ambiente e' su 2025.1, consultare la doc di quella
  versione per evitare istruzioni non allineate. Pattern degli URL:
  - ultima release: `https://docs.openstack.org/<servizio>/latest/`
  - release specifica: `https://docs.openstack.org/<servizio>/2025.1/`
- Elenco release e stato di supporto: `https://releases.openstack.org/`

---

## Prerequisiti generali del percorso

Da avere (almeno di base) prima di iniziare:

- Linux da riga di comando: navigazione, permessi, utenti/gruppi, `systemctl`,
  gestione pacchetti (apt), lettura log (`journalctl`).
- Reti TCP/IP di base: indirizzi e CIDR, subnet, gateway, DNS, NAT, porte, SSH.
- Concetti di virtualizzazione: cos'e' un hypervisor, una VM, un disco virtuale.
- YAML: sintassi di base (serve per `globals.yml`, Heat, Ansible).
- Git di base: clone, branch, checkout.
- Per il deploy pratico: Vagrant + VirtualBox, e nozioni di Ansible (Kolla lo usa).

Tecnologie/strumenti che si incontrano: VirtualBox, Vagrant, Docker, Ansible,
Kolla-Ansible, il client `openstack` (OpenStackClient), LVM, Open vSwitch/OVN,
QEMU/KVM, CirrOS.

---

## Modulo 0 — Il modello mentale di OpenStack

Prerequisiti: prerequisiti generali.

Domande guida:

- Cos'e' OpenStack e cosa vuol dire "cloud privato IaaS"?
- Perche' si dice che non ha un "cervello centrale"? Come comunicano i servizi?
- Che differenza c'e' tra control plane e compute node?
- Perche' Keystone e' il collante del sistema?

Concetti chiave: insieme di servizi indipendenti (API REST + database + worker),
comunicazione via coda di messaggi (RabbitMQ), Keystone per identita' e catalogo
servizi, separazione control plane / compute node. Dettaglio in `Basics.md`.

Esercizio di recap:

- A parole tue, descrivi il viaggio di una richiesta "crea una VM" dai servizi
  coinvolti (Keystone, nova-api, scheduler, Placement, nova-compute, Glance,
  Neutron, hypervisor). Confronta con lo schema in `Basics.md`.

Valutazione:

- Checklist di padronanza:
  - So spiegare cosa distingue OpenStack dalla semplice virtualizzazione.
  - So descrivere il pattern comune a ogni servizio (API + database + worker + coda).
  - So dire cosa gira sul control plane e cosa sui compute node.
- Prova pratica: disegna o descrivi a voce il flusso completo "crea una VM".
  Superato se nomini i servizi nell'ordine giusto e sai dire cosa fa ciascuno.
- Livello atteso: base (comprensione del quadro).

Link:

- Panoramica e get started: `https://docs.openstack.org/2026.1/`
- Project navigator: `https://www.openstack.org/software/project-navigator/`
- Video introduttivo (OpenInfra Live, OpenStack Basics): `https://www.youtube.com/watch?v=hGRkdYu6I5k`

---

## Modulo 1 — Keystone (Identity)

Prerequisiti: Modulo 0.

Domande guida:

- Che differenza c'e' tra autenticazione e autorizzazione?
- Perche' un ruolo da solo (es. "admin") non basta a dire cosa puo' fare un utente?
- Cos'e' un token e perche' evita di reinserire la password a ogni richiesta?
- A cosa serve il service catalog?

Concetti chiave: utente, progetto, ruolo (terna utente+progetto+ruolo), dominio,
token (Fernet), service catalog, endpoint public/internal/admin. Dettaglio in
`Basics.md`.

Esercizi di recap:

- Crea un progetto e un utente, assegna un ruolo `member` sul progetto.
- Ottieni un token con `openstack token issue` e osserva cosa contiene.
- Elenca gli endpoint con `openstack endpoint list` e collega ogni servizio alla
  sua porta.

Valutazione:

- Checklist di padronanza:
  - So spiegare perche' il permesso vive nella terna utente+progetto+ruolo.
  - So spiegare a cosa serve il token e come lo usano gli altri servizi.
  - So dire cosa contiene il service catalog e perche' e' utile.
- Prova pratica: crea utente, progetto e assegnazione di ruolo, poi autentica e
  ottieni un token. Superato se il token viene emesso e sai indicare progetto e
  ruolo con cui e' stato richiesto.
- Livello atteso: intermedio.

Link:

- Keystone: `https://docs.openstack.org/keystone/latest/`
- OpenStackClient (comandi CLI): `https://docs.openstack.org/python-openstackclient/latest/`

---

## Modulo 2 — Glance (Image service)

Prerequisiti: Modulo 1.

Domande guida:

- Perche' nel cloud si usano cloud image e non ISO di installazione?
- Cosa fa cloud-init e perche' permette a 100 VM di nascere dalla stessa immagine?
- Che differenza tecnica c'e' tra i formati raw e qcow2?
- Dove stanno fisicamente i byte delle immagini se non dentro Glance?

Concetti chiave: immagine come disco con SO gia' installato, cloud image vs ISO,
cloud-init, formati raw/qcow2 (thin provisioning, backing image, snapshot),
backend di storage, visibilita' delle immagini. Dettaglio in `Basics.md`.

Esercizi di recap:

- Elenca le immagini con `openstack image list`; identifica `cirros` e il formato.
- (Facoltativo) Carica una cloud image ufficiale in Glance con
  `openstack image create`, indicando formato e visibilita'.

Valutazione:

- Checklist di padronanza:
  - So spiegare la differenza tra ISO e cloud image e perche' nel cloud si usa la seconda.
  - So spiegare cosa fa cloud-init e da dove prende i dati.
  - So descrivere la differenza tra raw e qcow2 (spazio, snapshot, backing image).
- Prova pratica: carica un'immagine in Glance con formato e visibilita' corretti,
  poi elencala. Superato se l'immagine compare con i metadati attesi.
- Livello atteso: intermedio.

Link:

- Glance: `https://docs.openstack.org/glance/latest/`
- Virtual Machine Image Guide: da `https://docs.openstack.org/2026.1/`

---

## Modulo 3 — Nova (Compute)

Prerequisiti: Moduli 1-2.

Domande guida:

- Nova e' l'hypervisor? Se no, come lo comanda?
- Qual e' la differenza tra immagine e flavor? (Assi indipendenti.)
- Cosa fanno nova-api, nova-conductor, nova-scheduler, nova-compute?
- Come sceglie lo scheduler l'host, e a chi si appoggia (Placement, filtri, pesi)?

Concetti chiave: istanza, flavor, virt driver (KVM via libvirt; QEMU senza
accelerazione), componenti interni, ruolo di Placement, scheduling in due tempi
(filtri poi pesi), ciclo di vita (snapshot, resize, migrazione). Dettaglio in
`Basics.md`.

Esercizi di recap:

- Elenca i servizi compute con `openstack compute service list` e verifica che
  `nova-compute` sia `up`.
- Crea un'istanza CirrOS con `openstack server create` (flavor piccolo) e seguila
  da BUILD ad ACTIVE con `openstack server list`.
- Guarda la stessa istanza in Horizon: nota che i dati coincidono.

Valutazione:

- Checklist di padronanza:
  - So spiegare perche' Nova non e' l'hypervisor e cosa fa il virt driver.
  - So distinguere nettamente flavor (taglia) e immagine (contenuto).
  - So dire quale componente decide su quale host va la VM e a chi si appoggia.
- Prova pratica: crea un'istanza da CLI e portala ad ACTIVE. Superato se
  l'istanza e' attiva e sai spiegare cosa hanno fatto scheduler, Placement e
  nova-compute per crearla.
- Livello atteso: intermedio (avanzato se sai spiegare filtri e pesi).

Link:

- Nova: `https://docs.openstack.org/nova/latest/`
- Placement: `https://docs.openstack.org/placement/latest/`

---

## Modulo 4 — Neutron (Networking)

Prerequisiti: Moduli 1-3. E' il modulo piu' denso: dedicagli piu' tempo.

Domande guida:

- Qual e' la catena istanza -> port -> subnet -> network?
- Differenza tra rete tenant (privata) e rete esterna (provider)?
- Cosa fa il router e cosa il NAT? Differenza tra uscita (SNAT) ed entrata (floating IP)?
- Perche' il primo SSH a una nuova VM spesso fallisce (security group)?

Concetti chiave: network (L2), subnet (L3), port, reti private vs esterne, router
più NAT, floating IP, security group (stateful, ingress chiuso di default), ML2 con
OVS/OVN. Dettaglio in `Basics.md`.

Esercizi di recap:

- Elenca reti, subnet e router (`openstack network/subnet/router list`).
- Crea un floating IP dalla rete esterna e associalo a un'istanza; verifica con
  `openstack floating ip list` che `Fixed IP Address` e `Port` siano valorizzati.
- Ispeziona il security group dell'istanza e conferma le regole per tcp/22 e icmp;
  poi prova ping e SSH.

Valutazione:

- Checklist di padronanza:
  - So spiegare la catena istanza -> port -> subnet -> network.
  - So spiegare perche' una VM su rete privata non e' raggiungibile senza floating IP.
  - So dire perche' il security group blocca l'SSH di default e come aprirlo.
- Prova pratica: lancia un'istanza su rete privata e rendila raggiungibile in SSH
  dall'host. Superato se ping e SSH rispondono e sai indicare il ruolo di router,
  floating IP e security group nel percorso.
- Livello atteso: intermedio (il piu' importante da consolidare).

Link:

- Neutron: `https://docs.openstack.org/neutron/latest/`
- Guida amministrazione/networking: `https://docs.openstack.org/neutron/latest/admin/`

---

## Modulo 5 — Cinder (Block storage)

Prerequisiti: Moduli 1-4.

Domande guida:

- Che differenza c'e' tra disco effimero (dal flavor) e volume Cinder?
- Come si collega/scollega un volume, e perche' di norma va a una VM per volta?
- Cosa sono snapshot e boot-from-volume?
- Cos'e' il backend LVM e cosa il volume group `cinder-volumes`?

Concetti chiave: volumi persistenti, effimero vs persistente, attach/detach/
extend, snapshot, boot-from-volume, astrazione a driver (LVM, Ceph), volume type.
Dettaglio in `Extras.md`.

Esercizi di recap:

- Crea un volume da 1 GB: `openstack volume create --size 1 vol1`.
- Collegalo a un'istanza (`openstack server add volume ...`); dentro la VM
  verifica il nuovo disco con `lsblk` (es. `vdb` accanto al `vda` effimero).
- Scollegalo e verifica che i dati sopravvivano ricollegandolo altrove.

Valutazione:

- Checklist di padronanza:
  - So spiegare perche' il disco del flavor e' effimero e il volume Cinder no.
  - So collegare/scollegare un volume e riconoscerlo dentro la VM.
  - So spiegare a cosa serve il boot-from-volume.
- Prova pratica: crea un volume, collegalo, scrivici un file, scollegalo e
  ricollegalo a un'altra istanza. Superato se il file e' ancora presente dopo lo
  spostamento.
- Livello atteso: intermedio.

Link:

- Cinder: `https://docs.openstack.org/cinder/latest/`

---

## Modulo 6 — Swift (Object storage)

Prerequisiti: Modulo 0. Indipendente dai moduli VM.

Domande guida:

- Qual e' la differenza di fondo tra storage a blocchi (Cinder) e a oggetti (Swift)?
- Com'e' organizzato Swift (account, container, object)? E' una gerarchia ad albero?
- Cosa garantiscono ridondanza e scalabilita' orizzontale? Cos'e' la consistenza eventuale?

Concetti chiave: oggetti via HTTP, gerarchia account/container/object (piatta),
ridondanza (piu' copie), scalabilita' orizzontale, the ring, consistenza
eventuale, compatibilita' S3. Dettaglio in `Extras.md`.

Nota: nel laboratorio Kolla di base Swift non e' abilitato: il modulo e' teorico
salvo abilitare Swift.

Valutazione:

- Checklist di padronanza:
  - So spiegare blocchi vs oggetti come differenza di fondo Cinder/Swift.
  - So descrivere la gerarchia account/container/object e perche' e' piatta.
  - So spiegare a cosa serve la ridondanza e cos'e' la consistenza eventuale.
- Prova pratica (teorica): dato un caso d'uso (es. backup, disco di sistema di una
  VM, hosting di file statici), scegli tra Cinder e Swift motivando. Superato se
  la scelta e' corretta e argomentata.
- Livello atteso: base.

Link:

- Swift: `https://docs.openstack.org/swift/latest/`

---

## Modulo 7 — Horizon (Dashboard)

Prerequisiti: Moduli 1-4.

Domande guida:

- Perche' si dice che Horizon "non sa fare niente di suo"?
- Come si autentica Horizon e perche' mostra a utenti diversi cose diverse?
- Quando conviene la dashboard e quando la CLI/IaC?

Concetti chiave: faccia grafica sulle API, autenticazione via Keystone, vista per
ruolo, uso per esplorare vs codice per produrre. Dettaglio in `Extras.md`. Vedi
anche il flusso corretto di creazione istanza in `README_DASH.md`.

Esercizi di recap:

- Accedi a Horizon dall'host, crea un'istanza attaccandola SOLO alla rete privata,
  poi associa un floating IP dal menu Azioni.
- Ripeti la stessa operazione da CLI e confronta i passaggi.

Valutazione:

- Checklist di padronanza:
  - So spiegare che ogni azione in Horizon e' una chiamata API.
  - So spiegare perche' la dashboard mostra cose diverse a seconda del ruolo.
  - So dire quando usare la dashboard e quando la CLI/IaC.
- Prova pratica: crea la stessa istanza una volta da dashboard e una da CLI.
  Superato se i risultati coincidono e sai mappare ogni click a un comando.
- Livello atteso: base.

Link:

- Horizon: `https://docs.openstack.org/horizon/latest/`

---

## Modulo 8 — Heat (Orchestration / IaC)

Prerequisiti: Moduli 1-5, YAML.

Domande guida:

- Che differenza c'e' tra template e stack?
- Cosa vuol dire dichiarativo vs imperativo, e perche' interessa a un DevOps?
- Come gestisce Heat le dipendenze tra risorse?
- Differenza tra Heat e Terraform/OpenTofu?

Concetti chiave: template HOT (parameters, resources, outputs), stack come insieme
di risorse gestite come blocco, dichiarativo vs imperativo, dipendenze automatiche,
ciclo create/update/delete. Dettaglio in `Extras.md`.

Esercizi di recap:

- Scrivi un template minimo che crea una rete, una subnet e un'istanza.
- Crea lo stack, osserva l'ordine di creazione, fai un update cambiando un
  parametro, poi un delete e verifica che smonti tutto in ordine inverso.

Valutazione:

- Checklist di padronanza:
  - So distinguere template (progetto) e stack (risorse reali create).
  - So spiegare dichiarativo vs imperativo e i vantaggi per il DevOps.
  - So spiegare come Heat risolve le dipendenze tra risorse.
- Prova pratica: scrivi ed esegui un template che crea istanza + rete + floating
  IP in un unico stack. Superato se lo stack si crea, l'istanza e' raggiungibile,
  e il delete rimuove tutto senza risorse orfane.
- Livello atteso: intermedio (avanzato se automatizzi l'esposizione via floating IP).

Link:

- Heat: `https://docs.openstack.org/heat/latest/`

---

## Modulo 9 — Deploy pratico con Kolla-Ansible (all-in-one)

Prerequisiti: tutti i precedenti (almeno concettualmente), Vagrant/VirtualBox,
Ansible di base.

Domande guida:

- Perche' Kolla mette ogni servizio in un container Docker?
- Che ruolo ha l'inventory Ansible in un deploy single-node?
- A cosa servono prechecks, bootstrap-servers, deploy, post-deploy?
- Perche' senza KVM si usa `nova_compute_virt_type: qemu`?

Contenuto: deploy documentato passo passo in `README-openstack-kolla.md`, con
Vagrantfile, preparazione sistema, LVM per Cinder, `globals.yml`, e la sequenza
install-deps -> bootstrap-servers -> prechecks -> deploy -> post-deploy.

Esercizio di recap:

- Ripeti il deploy da zero seguendo il README, tenendo a mente le precauzioni
  (clone da GitHub, DNS con VPN, niente KVM, stand-by, /etc/hosts per RabbitMQ,
  secondo disco, terza NIC, coerenza del branch).

Valutazione:

- Checklist di padronanza:
  - So spiegare perche' Kolla usa container e Ansible.
  - So spiegare cosa verificano i prechecks e perche' vengono prima del deploy.
  - So riconoscere e risolvere almeno tre delle precauzioni documentate.
- Prova pratica: porta a termine un deploy AIO fino a `openstack endpoint list`
  che risponde. Superato se tutti i servizi core hanno un endpoint e la dashboard
  risponde.
- Livello atteso: intermedio (avanzato se diagnostichi autonomamente i fallimenti).

Link:

- Kolla-Ansible (ultima): `https://docs.openstack.org/kolla-ansible/latest/`
- Kolla-Ansible (versione allineata al deploy): `https://docs.openstack.org/kolla-ansible/2025.1/`
- Guide di installazione: `https://docs.openstack.org/install-guide/`
- Guide di deployment: da `https://docs.openstack.org/2026.1/`

---

## Modulo 10 — Operativita' e troubleshooting

Prerequisiti: Modulo 9.

Domande guida:

- Come si spegne/riaccende l'ambiente senza distruggerlo?
- Come si diagnostica un'istanza irraggiungibile (rete, floating IP, security group)?
- Come si leggono i log dei servizi (journalctl con DevStack, container con Kolla)?

Concetti chiave: ciclo di vita dell'ambiente (`vagrant halt`/`up`), verifica dei
container (`docker ps`), diagnosi di rete (rete privata vs attacco diretto alla
esterna, floating IP con NAT, regole del security group). Checklist in
`README_DASH.md`.

Esercizi di recap:

- Rimuovi il floating IP a un'istanza e ricostruisci la raggiungibilita' passo passo.
- Simula "SSH in timeout" e verifica in ordine: stato istanza, rete, floating IP
  associato, regole del security group.

Valutazione:

- Checklist di padronanza:
  - So spegnere e riaccendere l'ambiente senza perdere il lavoro.
  - So elencare, in ordine, i punti da controllare quando una VM non risponde.
  - So trovare e leggere i log del servizio giusto.
- Prova pratica: ti viene dato un ambiente con un guasto introdotto (floating IP
  mancante, o regola SSH rimossa, o istanza sulla rete sbagliata). Superato se
  individui e correggi la causa spiegando il ragionamento.
- Livello atteso: intermedio (e' il modulo che misura l'autonomia reale).

---

## Progetto finale (capstone)

Obiettivo: dimostrare padronanza end-to-end su ambiente Kolla AIO.

1. Crea un progetto e un utente dedicati (Keystone).
2. Usa o carica una cloud image (Glance) e scegli/definisci un flavor (Nova).
3. Crea una rete privata con subnet e un router verso la rete esterna (Neutron).
4. Lancia un'istanza sulla rete privata, apri SSH e ICMP nel security group.
5. Assegna un floating IP e accedi in SSH dall'host.
6. Crea un volume Cinder, collegalo e montalo; verifica la persistenza.
7. Bonus: riproduci i passi 3-5 con un template Heat (IaC).

### Griglia di valutazione del capstone

| Criterio | Base | Intermedio | Avanzato |

|---|---|---|---|
| Identita' (Keystone) | Crea utente/progetto seguendo la guida | Assegna ruoli corretti e verifica il token | Spiega la terna e i ruoli a livello di dominio/sistema |
| Immagini e compute (Glance/Nova) | Lancia un'istanza | Distingue immagine e flavor e diagnostica un BUILD lento | Spiega scheduler, Placement, filtri e pesi |
| Rete (Neutron) | Ottiene un'istanza raggiungibile con aiuto | Costruisce rete, router, floating IP e SSH da solo | Progetta la topologia e spiega il NAT |
| Storage (Cinder) | Collega un volume | Dimostra la persistenza spostando il volume | Sceglie backend/volume type con motivazione |
| Automazione (Heat) | - | Esegue un template dato | Scrive un template che espone la VM via floating IP |
| Autonomia | Segue la guida | Risolve gli intoppi da solo | Anticipa i problemi e li previene |

Criterio di riuscita complessivo: intermedio su tutte le righe core (identita',
compute, rete, storage). Il livello avanzato indica prontezza per lavorare su
ambienti reali con supervisione minima.

---

## Link utili globali

Documentazione ufficiale:

- Portale doc (ultima release): `https://docs.openstack.org/`
- Release corrente 2026.1: `https://docs.openstack.org/2026.1/`
- Elenco e stato delle release: `https://releases.openstack.org/`
- Install guide: `https://docs.openstack.org/install-guide/`
- Kolla-Ansible: `https://docs.openstack.org/kolla-ansible/latest/`
- OpenStackClient (CLI): `https://docs.openstack.org/python-openstackclient/latest/`
- Per servizio: keystone, glance, nova, placement, neutron, cinder, swift,
  horizon, heat -> `https://docs.openstack.org/<servizio>/latest/`

Community e supporto:

- Community OpenStack: `https://www.openstack.org/community/`
- Ask OpenStack (domande e risposte): `https://ask.openstack.org/`
- Mailing list openstack-discuss: `https://lists.openstack.org/`
- IRC: canale `#openstack` sulla rete OFTC (`https://webchat.oftc.net/`)

Blog e approfondimenti:

- Superuser (OpenInfra): `https://superuser.openinfra.org/`
- Wiki OpenStack: `https://wiki.openstack.org/`

Video:

- Canale YouTube OpenInfra Foundation: `https://www.youtube.com/user/OpenStackFoundation`
- OpenInfra Live "OpenStack Basics": `https://www.youtube.com/watch?v=hGRkdYu6I5k`

---

## Appendice per il tutor

Tempi stimati (indicativi, per un allievo con i prerequisiti):

- Moduli 0-2 (modello, Keystone, Glance): circa 1 giornata.
- Modulo 3 (Nova): mezza giornata / 1 giornata.
- Modulo 4 (Neutron): 1 giornata (il piu' impegnativo).
- Moduli 5-8 (Cinder, Swift, Horizon, Heat): 1-2 giornate complessive.
- Modulo 9 (deploy Kolla): 1 giornata (piu' i tempi morti dei download).
- Modulo 10 + capstone: 1 giornata.

Consigli per condurre le verifiche:

- Preferisci la domanda "perche'?" alla domanda "come?": chi sa il perche' sa
  anche adattarsi quando la procedura cambia.
- Per la prova pratica, introduci un piccolo guasto e osserva il metodo di
  diagnosi, non solo la soluzione.
- Registra il livello raggiunto per modulo, cosi' sai dove serve rinforzo.
- Ricorda che il troubleshooting reale (rete, DNS, virtualizzazione, permessi) e'
  parte della competenza: un allievo che scioglie gli intoppi ragionando vale piu'
  di uno che esegue una guida senza errori.

---

## Glossario rapido

- IaaS: Infrastructure as a Service, infrastruttura (VM/reti/dischi) a richiesta.
- Control plane: i nodi che ospitano API, database, coda messaggi, dashboard.
- Compute node: i nodi che ospitano le VM (hypervisor + nova-compute).
- Progetto (project/tenant): unita' di isolamento delle risorse.
- Token: credenziale temporanea rilasciata da Keystone.
- Flavor: taglia dell'hardware virtuale (vCPU, RAM, disco).
- Istanza: la VM in esecuzione.
- Floating IP: indirizzo pubblico assegnabile a una VM per raggiungerla da fuori.
- Security group: firewall per-istanza, ingress chiuso di default.
- Volume: disco persistente Cinder.
- Stack: insieme di risorse create da un template Heat.
- SLURP: release pensata per upgrade a salto di versione.
