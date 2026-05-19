# PingPong - Esercizio Vagrant Multi-Machine

## Panoramica

Questo progetto dimostra la gestione automatizzata del ciclo di vita di container Docker su due macchine virtuali provisionate con Vagrant. L'esercizio, denominato **PingPong**, simula un ciclo di deployment continuo in cui un echo server containerizzato viene avviato e arrestato alternativamente su due host distinti.

---

## Infrastruttura

L'ambiente è definito tramite un `Vagrantfile` e consiste in due macchine virtuali che eseguono **Ubuntu 22.04 (bento/ubuntu-22.04)**, entrambe provisionate automaticamente all'avvio tramite `provision.sh`.

| Macchina | Hostname | Indirizzo IP     |
|----------|----------|------------------|
| m1       | m1       | 192.168.100.3    |
| m2       | m2       | 192.168.100.2    |

### Risorse allocate (per VM)

| Risorsa   | Valore     |
|-----------|------------|
| RAM       | 1024 MB    |
| CPU       | 1          |
| Provider  | VirtualBox |

---

## Provisioning

Lo script `provision.sh` viene eseguito automaticamente su entrambe le macchine durante `vagrant up`. Esegue le seguenti operazioni:

1. Aggiorna i pacchetti di sistema
2. Installa e avvia **Apache2**
3. Installa **Docker** (`docker.io`)
4. Aggiunge l'utente `vagrant` al gruppo `docker` (per consentire l'accesso a Docker senza privilegi root)

---

## Script PingPong

Lo script `PingPong.sh` è registrato come script di push Vagrant (`local-exec`) e viene eseguito sulla **macchina host**. Coordina le operazioni sui container Docker delle due VM tramite `vagrant ssh`.

### Flusso di esecuzione

Lo script gira in un ciclo infinito con la seguente sequenza:

```
[m1] Rimozione del container echoServer esistente (se presente)
[m1] Download dell'immagine ealen/echo-server:latest
[m1] Avvio del container echoServer in modalita' detached
     --> Attesa di ~60 secondi (barra di avanzamento: Ping====...====Pong)
[m1] Rimozione del container echoServer

[m2] Rimozione del container echoServer esistente (se presente)
[m2] Download dell'immagine ealen/echo-server:latest
[m2] Avvio del container echoServer in modalita' detached
     --> Attesa di ~60 secondi (barra di avanzamento: Ping====...====Pong)
[m2] Rimozione del container echoServer

[ripetizione]
```

### Indicatore di avanzamento

Durante ogni periodo di attesa, il terminale mostra una barra di avanzamento nella forma:

```
Ping==========================================================Pong
```

Ogni carattere `=` viene stampato con un ritardo di 1 secondo, per un'attesa totale di circa 60 secondi per fase.

---

## Prerequisiti

- [Vagrant](https://www.vagrantup.com/) >= 2.x
- [VirtualBox](https://www.virtualbox.org/)
- Accesso a Internet (necessario per il download delle immagini Docker)

---

## Utilizzo

### Avviare l'ambiente

```bash
vagrant up
```

### Eseguire lo script PingPong

```bash
vagrant push
```

Oppure eseguirlo direttamente dalla radice del progetto:

```bash
bash PingPong.sh
```

### Fermare e distruggere l'ambiente

```bash
vagrant halt       # Ferma le VM
vagrant destroy    # Rimuove le VM
```

---

## Problemi noti

- In `PingPong.sh`, il comando `docker rm -f` su `m2` manca di uno spazio prima di `echoServer` (`docker rm -fechoServer`). Questo causa un errore silenzioso nella rimozione del container alla prima iterazione su `m2`. Il comando corretto dovrebbe essere:
  ```bash
  vagrant ssh m2 -c "docker rm -f echoServer"
  ```

---

## Struttura del progetto

```
.
├── Vagrantfile       # Configurazione delle VM (2 macchine, rete privata)
├── provision.sh      # Script di provisioning (Apache2, Docker, SSH)
└── PingPong.sh       # Script di orchestrazione lato host
```

---

## Note

- Tutto l'output dei comandi `vagrant ssh` viene soppresso (`> /dev/null 2>&1`) per mantenere il terminale pulito durante l'esecuzione.
- Il passo `docker pull` viene eseguito ad ogni iterazione, garantendo che venga sempre utilizzata l'immagine piu' aggiornata.
- La rete privata (`192.168.100.x`) isola le due VM dalla rete pubblica, mantenendo al contempo la connettivita' SSH dall'host alle VM.
