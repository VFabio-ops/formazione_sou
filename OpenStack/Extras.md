# I tre tipi di storage (per non confonderli)

- Disco effimero (dal flavor): storage a blocchi, temporaneo, muore con la VM.
- Volume Cinder: storage a blocchi, persistente, sopravvive alla VM.
- Swift: storage a oggetti, file interi via HTTP, non si monta come disco.

Radice della differenza Cinder vs Swift: BLOCCHI vs OGGETTI.
Blocchi = disco che monti e formatti. Oggetti = file che carichi/scarichi via web.

---

## Cinder — Block Storage (dischi persistenti)

Compito: fornire volumi, cioe' dischi virtuali persistenti che colleghi/scolleghi dalle istanze
come un hard disk esterno. Il volume vive nel backend di storage, non dentro la VM, e sopravvive alla VM.

Distinzione chiave (l'errore classico):

- Disco del flavor = effimero: quanto grande, ma muore con l'istanza.
- Volume Cinder = persistente: lo elimini tu, quando vuoi.
- Flavor = quanto grande e' la macchina; immagine = cosa c'e' dentro; volume = disco extra che dura.

Uso tipico:

- Crei il volume (dici la dimensione) e lo colleghi (attach) a una VM: compare come disco a blocchi
  (es. /dev/vdb), che formatti e monti.
- Puoi scollegarlo (detach) e ricollegarlo a un'altra VM, portandoti i dati.
- Puoi ingrandirlo (extend). Lo elimini esplicitamente.
- Di norma un volume si collega a UNA VM per volta (come una chiavetta USB).

Funzioni utili:

- Snapshot: fotografia del volume in un istante; da uno snapshot crei nuovi volumi.
- Boot from volume: avvii la VM direttamente da un volume Cinder -> l'intera macchina (SO compreso)
  diventa persistente. Utile per server che devono durare.

Sotto il cofano: astrazione a driver (LVM di riferimento, Ceph in produzione, storage commerciali
come NetApp/Pure). Volume type: classi di storage diverse (es. veloce su SSD, capiente su HDD).

Come si incastra: quando colleghi un volume, Nova gira la richiesta a Cinder; Cinder prepara il volume
nel backend e nova-compute lo presenta alla VM come dispositivo a blocchi.

Doc: <https://docs.openstack.org/cinder/latest/>

---

## Horizon — Dashboard (interfaccia web)

Compito: la dashboard web ufficiale. Dal browser crei istanze, reti, volumi e vedi lo stato del cloud.

Concetto chiave: Horizon NON sa fare niente di suo. E' solo una faccia grafica sopra le API.
Ogni bottone = una chiamata API a un servizio (clicchi "Crea istanza" -> stessa richiesta a Nova
che faresti da CLI). Nulla che tu possa fare da Horizon e' impossibile via API/CLI.

Tecnicamente: app web (Django/Python) sul control plane. Il dettaglio conta poco, conta il ruolo.

Rapporto con Keystone: quando fai login, Horizon gira le credenziali a Keystone, ottiene un token
e lo usa per parlare con gli altri servizi per conto tuo. E' un client come un altro.
Conseguenza: vedi solo cio' che il tuo ruolo permette (member vede il suo progetto; admin ha la vista globale).

Quando si usa: ottima per imparare ed esplorare (vedi i concetti con gli occhi) e per operazioni occasionali.
Per l'automazione ripetibile si usa la CLI (client openstack) o l'IaC (Heat/Terraform).
Regola DevOps: interfaccia grafica per capire/esplorare, codice per produrre.

Doc: <https://docs.openstack.org/horizon/latest/>

---

## Swift — Object Storage (archivio di oggetti)

Compito: storage a oggetti. Depositi e ritiri file interi ("oggetti") via HTTP, senza montarli come dischi.
Simile ad Amazon S3 (ha anche un'API compatibile con S3).

Analogia: il guardaroba del teatro. Consegni l'oggetto intero allo sportello, con lo scontrino lo riprendi.
Non entri a sistemarlo sullo scaffale.

Organizzazione (gerarchia piatta, non ad albero):

- Account: livello alto, legato al progetto.
- Container: grandi contenitori per raggruppare (es. "backup", "log").
- Object: i file veri, con metadati. Ogni oggetto ha un URL.
- Le "cartelle" sono solo una convenzione sui nomi (es. 2026/gennaio/report.pdf), non struttura reale.

Proprieta' chiave:

- Ridondanza -> durabilita': piu' copie (di default 3) su server e zone diverse. Se qualcosa si rompe,
  il dato resta. Vale per file piccoli e grandi: il punto sono le copie, non la dimensione.
- Scalabilita' orizzontale: piu' spazio/capacita' = aggiungi server. Nessun collo di bottiglia centrale.
- The ring: il meccanismo interno che mappa gli oggetti sui dischi fisici e ribilancia.
- Consistenza eventuale: dopo una modifica le copie si allineano in un breve tempo (compromesso da grande scala).

Uso tipico: file non strutturati che devono durare ed essere accessibili via rete (backup, archivi,
foto/video, asset di siti, log). Non per il disco di sistema di una VM (quello e' Cinder).
Puo' fare da backend di storage per Glance.

Doc: <https://docs.openstack.org/swift/latest/>

---

## Heat — Orchestration (infrastructure-as-code)

Compito: orchestrazione, l'IaC nativo di OpenStack. Descrivi un'intera infrastruttura in un file di testo
e Heat la costruisce tutta insieme, nell'ordine giusto.

Due parole chiave:

- Template: la descrizione, in YAML (formato HOT). Tre sezioni:
  - parameters: gli input personalizzabili (immagine, flavor, chiave SSH...).
  - resources: le cose da creare, ciascuna di un tipo (OS::Nova::Server, OS::Neutron::Net,
    OS::Cinder::Volume...).
  - outputs: i valori restituiti a fine creazione (es. il floating IP assegnato).
- Stack: l'insieme concreto di risorse reali create da un template, gestite come un blocco unico.
  (Lo stack e' cio' che il template descrive, qualunque cosa sia -- non un set fisso di risorse.)

Dichiarativo vs imperativo:

- Imperativo (Horizon/CLI): specifichi i passi, uno per uno, nell'ordine giusto.
- Dichiarativo (Heat): descrivi lo stato finale; il sistema capisce quali passi fare e in che ordine.
- Vantaggi per il DevOps: ripetibilita' (stesso file, stesso ambiente), infrastruttura sotto controllo
  di versione (Git), gestione automatica delle dipendenze (sa che la VM viene dopo la rete, ecc.).

Ciclo di vita:

- create: crea lo stack dal template.
- update: modifichi il template; Heat calcola la differenza e applica solo cio' che serve.
- delete: smonta tutte le risorse in modo ordinato (ordine inverso), senza lasciare pezzi orfani.

Alternativa diffusa e multi-cloud: Terraform (e OpenTofu), agnostico rispetto al cloud (OpenStack, AWS, Azure).
Heat resta il riferimento nativo dentro OpenStack.

Doc: <https://docs.openstack.org/heat/latest/>

---

## Scenario completo: VM con SSH da Internet + disco persistente (via Heat)

- Heat: legge il template e orchestra la creazione di tutto.
- Keystone: autentica e autorizza.
- Glance: fornisce l'immagine (lo stampo del disco di sistema).
- Nova: crea l'istanza (la VM).
- Neutron: rete, subnet, port, piu' router e floating IP per l'accesso da fuori.
- Cinder: il volume persistente da collegare.
- Security group: aperto sulla porta 22, altrimenti niente SSH.
