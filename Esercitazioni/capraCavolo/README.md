# Lupo, Capra e Cavolo — Architettura Distribuita con Vagrant e Docker

Implementazione informatica del classico problema logistico del contadino, del lupo, della capra e del cavolo, realizzata tramite macchine virtuali Vagrant e container Docker orchestrati da uno script Bash.

---

## Il Problema

Un contadino deve attraversare un fiume in barca potendo trasportare, oltre a se stesso, un solo elemento alla volta tra: un lupo, una capra e un cesto di cavoli.

Vincoli:
- Il lupo, se lasciato solo con la capra, la mangia.
- La capra, se lasciata sola con il cavolo, lo mangia.
- Il lupo non mangia il cavolo.

L'obiettivo e trasportare tutti gli elementi dall'altra parte del fiume senza che nessuno venga mangiato.

---

## Architettura

Il problema viene tradotto in un sistema distribuito composto da due macchine virtuali e quattro container Docker.

| Componente | Tecnologia | Ruolo |
|---|---|---|
| Sponda 1 (`m1`) | Ubuntu 24.04 VM — `192.168.100.2` | Nodo sorgente |
| Sponda 2 (`m2`) | Ubuntu 24.04 VM — `192.168.100.3` | Nodo destinazione |
| Barca / Orchestratore | Script Bash (`cavolo.sh`) | Logica di controllo e supervisione |
| `farmer` | Docker Container (Alpine) | Attore di controllo |
| `wolf` | Docker Container (Alpine) | Attore subordinato al farmer |
| `sheep` | Docker Container (Alpine) | Attore critico |
| `cabbage` | Docker Container (Alpine) | Risorsa passiva |

Le due VM sono collegate tramite una rete privata (`private_network`) e vengono entrambe provisionate con Docker, Apache2 e il servizio systemd `docker-monitor`.

---

## Provisioning Automatico (Vagrantfile)

Ogni VM viene configurata con le seguenti specifiche:

- **Box**: `bento/ubuntu-24.04`
- **RAM**: 2048 MB
- **CPU**: 2 vCPU
- **Provider**: VirtualBox

Durante il provisioning vengono installati automaticamente:
- `docker.io`
- `apache2`
- `openssh-server`

Viene inoltre creato e abilitato un servizio systemd dedicato: `docker-monitor`.

---

## Il Servizio docker-monitor

Il servizio `docker-monitor` e il cuore della logica di guardia del sistema. Viene installato su entrambe le VM come unit systemd (`/etc/systemd/system/docker-monitor.service`) e avviato automaticamente ad ogni boot.

Lo script `/etc/docker-monitor/docker-monitor.sh` controlla ogni secondo lo stato dei container presenti sulla VM e applica le seguenti regole di sicurezza:

| Regola | Condizione | Azione |
|---|---|---|
| 1 | `farmer` assente, `wolf` + `sheep` + `cabbage` presenti | Arresta `sheep` e `cabbage` |
| 2 | `farmer` e `cabbage` assenti, `sheep` presente | Arresta `sheep` |
| 3 | `farmer` e `wolf` assenti, `cabbage` presente | Arresta `cabbage` |

Ogni intervento viene registrato nel log `/var/log/docker-monitor.log` con timestamp.

Questo meccanismo garantisce che, anche in caso di errore nello script di orchestrazione, le invarianti del problema non vengano mai violate.

---

## Soluzione Implementata

La soluzione segue la sequenza classica ottimale in sei mosse:

1. Il farmer porta la **pecora** su `m2`.
2. Il farmer torna su `m1` e porta il **cavolo** su `m2`.
3. Il farmer riprende la **pecora** da `m2` e la riporta su `m1`.
4. Il farmer lascia la pecora su `m1` e porta il **lupo** su `m2`.
5. Il farmer torna su `m1` a prendere la **pecora**.
6. Il farmer porta la pecora su `m2`: tutti gli attori sono a destinazione.

Lo spostamento di un container tra VM viene simulato tramite `docker rm -f` sulla VM sorgente e `docker run` sulla VM destinazione, eseguiti dallo script Bash tramite `vagrant ssh`.

---

## Output di Esecuzione

```
Sponda1: farmer, wolf, sheep, cabbage
Sponda2: (vuota)

I 4 attori sono pronti a fare la traversata!
Il fattore porta la pecora sull'altra sponda.
Il fattore torna a prendere il cavolo.
Il fattore porta il cavolo sull'altra sponda.
Il fattore lascia il cavolo e riprende la pecora.
Ora il fattore torna a prendere il lupo e lasciare la pecora.
Il fattore porta il lupo sull'altra sponda ed e pronto per la traversata finale!

Sponda1: (vuota)
Sponda2: farmer, wolf, sheep, cabbage

Gioco riuscito! Il fattore, il lupo, la pecora e il cavolo sono tutti sull'altra sponda!
```

---

## Prerequisiti

- [Vagrant](https://www.vagrantup.com/) >= 2.x
- [VirtualBox](https://www.virtualbox.org/)
- Bash

Docker viene installato automaticamente dal provisioning Vagrant; non e necessario averlo in locale.

---

## Utilizzo

**Avvio delle macchine virtuali e provisioning:**

```bash
vagrant up
```

**Esecuzione della traversata:**

```bash
bash cavolo.sh
```

**Pulizia dei container residui:**

```bash
bash RM.sh
```

> Eseguire `RM.sh` prima di ogni nuova run per garantire uno stato pulito su entrambe le VM.

---

## Struttura del Repository

```
.
├── Vagrantfile                  # Definizione delle due VM e provisioning
├── cavolo.sh                    # Orchestrazione della traversata
├── RM.sh                        # Pulizia dei container
└── README.md
```

---

## Note Tecniche

- I container utilizzano l'immagine `alpine` con comando `sleep infinity` per rappresentare la presenza degli attori su una sponda.
- Lo "spostamento" di un attore è implementato come distruzione del container sulla VM sorgente e ricreazione sulla VM destinazione.
- Il `docker-monitor` costituisce un livello di sicurezza indipendente dallo script principale: anche se `cavolo.sh` venisse interrotto a meta esecuzione, le regole di guardia continuerebbero a essere applicate in background.
- I log del monitor sono consultabili con `journalctl -u docker-monitor` o direttamente in `/var/log/docker-monitor.log`.