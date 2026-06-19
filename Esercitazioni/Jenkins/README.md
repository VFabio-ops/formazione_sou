# DevOps Lab - Jenkins su Podman con Vagrant e Ansible

Ambiente di laboratorio per il provisioning automatizzato di un'infrastruttura Jenkins basata su container Podman, distribuita all'interno di una macchina virtuale Rocky Linux gestita con Vagrant e configurata tramite Ansible.

Il progetto rappresenta l'infrastruttura di supporto utilizzata dalla pipeline CI/CD: un Jenkins Master e un Jenkins Agent, entrambi eseguiti come container Podman, comunicanti su una rete dedicata.

## Indice

- [Panoramica](#panoramica)
- [Architettura](#architettura)
- [Struttura del repository](#struttura-del-repository)
- [Requisiti](#requisiti)
- [Avvio dell'ambiente](#avvio-dellambiente)
- [Componenti Ansible](#componenti-ansible)
- [Variabili principali](#variabili-principali)
- [Accesso a Jenkins](#accesso-a-jenkins)
- [Note di sicurezza](#note-di-sicurezza)
- [Licenza](#licenza)

## Panoramica

Questo repository automatizza la creazione di un ambiente Jenkins containerizzato pensato per scopi didattici e di test. L'intero processo, dalla creazione della macchina virtuale alla configurazione dei container, è gestito senza interventi manuali tramite Vagrant e Ansible.

Al termine del provisioning sono disponibili:

- un **Jenkins Master**, raggiungibile via interfaccia web, con utente amministratore preconfigurato e wizard di setup iniziale disabilitato;
- un **Jenkins Agent**, basato su un'immagine personalizzata con Podman, collegato automaticamente al Master tramite il protocollo JNLP.

## Architettura

```
Host
 └── Vagrant (VirtualBox)
      └── VM Rocky Linux 9 "devops-lab"
           └── Podman
                ├── Rete "jenkins-net" (172.20.0.0/24)
                ├── Container jenkins-master (172.20.0.10:8080)
                └── Container jenkins-agent  (172.20.0.11)
```

Il container `jenkins-agent` viene eseguito in modalità privilegiata e monta il binario e il socket Podman dell'host, in modo da poter avviare a sua volta build basate su Podman ("Podman in Podman").

## Struttura del repository

```
.
├── Vagrantfile                  # Definizione della VM e avvio del provisioning Ansible
├── ansible.cfg                  # Configurazione del comportamento di Ansible
├── site.yml                     # Playbook principale
├── group_vars/
│   └── all.yml                  # Variabili globali (rete, immagini, credenziali, IP)
├── roles/
│   ├── podman/
│   │   └── tasks/main.yml       # Installazione e configurazione di Podman
│   ├── container_network/
│   │   └── tasks/main.yml       # Creazione della rete dedicata ai container
│   ├── jenkins_master/
│   │   └── tasks/main.yml       # Provisioning del container Jenkins Master
│   └── jenkins_agent/
│       └── tasks/main.yml       # Provisioning del container Jenkins Agent
└── Containerfile.Podman         # Immagine custom dell'agent Jenkins con Podman incluso
```

## Requisiti

- [Vagrant](https://www.vagrantup.com/) 2.x
- [VirtualBox](https://www.virtualbox.org/) come provider
- Ansible (installato sull'host, utilizzato dal provisioner Vagrant)
- Connessione di rete per il download del box `generic/rocky9` e delle immagini container

## Avvio dell'ambiente

Dalla directory principale del repository, è sufficiente eseguire:

```bash
vagrant up
```

Vagrant si occuperà di:

1. Scaricare e avviare la VM Rocky Linux 9 con 2 CPU e 4 GB di RAM.
2. Configurare la rete privata sull'indirizzo `192.168.56.10`.
3. Eseguire automaticamente il playbook Ansible `site.yml`, che installa Podman, crea la rete container e avvia i container Jenkins Master e Jenkins Agent.

Per ripetere il provisioning senza ricreare la VM:

```bash
vagrant provision
```

Per eseguire solo un sottoinsieme di ruoli, è possibile usare i tag definiti in `site.yml` (ad esempio `jenkins`, `master`, `agent`, `network`, `podman`):

```bash
vagrant provision --provision-with ansible -- --tags jenkins
```

## Componenti Ansible

Il playbook `site.yml` esegue, in ordine, i seguenti ruoli:

| Ruolo | Descrizione |
|---|---|
| `podman` | Installa Podman, Buildah, Skopeo e le librerie Python necessarie; abilita il socket Podman per l'accesso via API REST e configura il registry DockerHub. |
| `container_network` | Crea la rete bridge dedicata `jenkins-net` con subnet e gateway definiti, utilizzata da entrambi i container Jenkins. |
| `jenkins_master` | Prepara le directory dati, genera gli script di inizializzazione Groovy per creare l'utente amministratore e disabilitare il setup wizard, e avvia il container del Master. |
| `jenkins_agent` | Verifica la raggiungibilità del Master, avvia il container dell'Agent e attende che si connetta correttamente al Master. |

## Variabili principali

Le variabili di configurazione sono centralizzate in `group_vars/all.yml`:

| Variabile | Descrizione |
|---|---|
| `container_runtime` | Runtime container utilizzato (`podman`) |
| `container_network_name` | Nome della rete container (`jenkins-net`) |
| `container_network_subnet` / `container_network_gateway` | Subnet e gateway della rete |
| `jenkins_master_ip` / `jenkins_agent_ip` | Indirizzi IP statici assegnati ai container |
| `jenkins_master_image` / `jenkins_agent_image` | Immagini container utilizzate |
| `jenkins_master_http_port` / `jenkins_master_agent_port` | Porte esposte dal Master |
| `jenkins_admin_user` / `jenkins_admin_password` | Credenziali amministratore Jenkins |
| `jenkins_agent_secret` | Secret utilizzato dall'Agent per autenticarsi al Master |

## Accesso a Jenkins

Una volta completato il provisioning, l'interfaccia di Jenkins è raggiungibile da:

```
http://localhost:8080
```

grazie al port forwarding configurato nel Vagrantfile, oppure direttamente all'indirizzo della VM:

```
http://192.168.56.10:8080
```

Le credenziali di accesso sono quelle definite dalle variabili `jenkins_admin_user` e `jenkins_admin_password`.

## Note di sicurezza

Questo ambiente è pensato esclusivamente per uso didattico e di test in locale. Prima di un eventuale utilizzo in contesti diversi, è opportuno:

- spostare credenziali e secret (`jenkins_admin_password`, `jenkins_agent_secret`) in un vault Ansible o in un sistema di gestione segreti dedicato;
- rivedere i permessi impostati su `/usr/bin/podman` e sul socket Podman (`0777`), attualmente molto permissivi;
- valutare l'esecuzione del container Agent senza la modalità `privileged`, dove possibile.

## Licenza

Questo progetto è distribuito sotto licenza MIT. Per i dettagli completi consultare il file LICENSE incluso nel repository.
