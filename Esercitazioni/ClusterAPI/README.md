# Deploy di un'applicazione su un workload cluster Cluster API (provider Docker)

Questo repository documenta l'intero processo di provisioning di un cluster
Kubernetes con [Cluster API](https://cluster-api.sigs.k8s.io/) usando il provider
di infrastruttura Docker (CAPD), e il deploy di un'applicazione di esempio su di
esso tramite Helm. Il setup segue la
[Quick Start ufficiale di Cluster API](https://cluster-api.sigs.k8s.io/user/quick-start.html).

## Panoramica

Un cluster [kind](https://kind.sigs.k8s.io/) già esistente viene usato come
**management cluster**. Da questo, Cluster API effettua il provisioning di un
**workload cluster** separato (`capi-quickstart`), i cui nodi girano come
container Docker sullo stesso host. Calico viene installato come CNI, e
un'applicazione Flask di esempio viene deployata tramite un chart Helm puntando
al workload cluster.

| Componente | Valore |
|------------|--------|
| Management cluster | kind |
| Provider di infrastruttura | Docker (CAPD) |
| Workload cluster | `capi-quickstart` |
| Versione Kubernetes | v1.36.1 |
| Topologia | 3 nodi control-plane, 3 nodi worker |
| CNI | Calico v3.26.1 |
| Workload di esempio | `flask-app-example` (chart Helm) |

## Prerequisiti

- Docker
- `kind`
- `kubectl`
- `clusterctl`
- `helm`

Si assume che il management cluster abbia già Cluster API inizializzato con il
provider Docker (`clusterctl init --infrastructure docker`).

## Cosa definisce `capi-quickstart.yaml`

Il manifest è una topologia autocontenuta basata su ClusterClass. I suoi
componenti principali sono:

- Una **ClusterClass** chiamata `quick-start`, che collega control-plane
  (`KubeadmControlPlaneTemplate`), i template di infrastruttura Docker e le classi
  worker, oltre agli health check per nodi e macchine.
- Un **Cluster** chiamato `capi-quickstart` che referenzia la ClusterClass tramite
  la sua `topology`, richiedendo 3 repliche di control-plane e un MachineDeployment
  `default-worker` (`md-0`) con 3 repliche su Kubernetes v1.36.1.
- Il networking del cluster con pod CIDR `192.168.0.0/16` e service CIDR
  `10.128.0.0/12`. Il pod CIDR corrisponde volutamente al range di default di
  Calico.
- I Pod Security Standard abilitati tramite una patch di admission configuration
  (`enforce: baseline`, `audit`/`warn: restricted`).

## Procedura

### 1. Applicare la definizione del cluster

Applicata contro il management cluster (il context di default del kubeconfig):

```bash
kubectl apply -f capi-quickstart.yaml
```

### 2. Monitorare il provisioning

```bash
kubectl get cluster
clusterctl describe cluster capi-quickstart
kubectl get kubeadmcontrolplane
```

`clusterctl describe cluster capi-quickstart` fornisce una vista ad albero del
control plane, delle macchine e delle loro condizioni: è il modo più rapido per
verificare che il cluster stia salendo. Attendere che il control plane risulti
inizializzato prima di procedere.

### 3. Recuperare il kubeconfig del workload cluster

```bash
kind get kubeconfig --name capi-quickstart > capi-quickstart.kubeconfig
```

Questo funziona perché CAPD crea i nodi come container Docker che kind riesce a
vedere. Il comando canonico di Cluster API per lo stesso scopo è:

```bash
clusterctl get kubeconfig capi-quickstart > capi-quickstart.kubeconfig
```

Da notare che il kubeconfig prodotto qui punta a `https://0.0.0.0:55000`. In caso
di problemi di connessione, rigenerarlo con `clusterctl get kubeconfig`, che
imposta un indirizzo raggiungibile.

### 4. Installare la CNI (Calico)

Applicata contro il **workload cluster**, usando il suo kubeconfig:

```bash
kubectl --kubeconfig=./capi-quickstart.kubeconfig \
  apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
```

Finché non viene installata una CNI, i nodi del workload cluster restano
`NotReady`. Dopo che Calico è attivo, verificare:

```bash
kubectl --kubeconfig=./capi-quickstart.kubeconfig get nodes
```

Tutti i nodi control-plane e worker dovrebbero risultare `Ready`.

### 5. Deployare l'applicazione con Helm

Helm risolve il cluster di destinazione tramite lo stesso meccanismo di kubeconfig
di `kubectl`. Per deployare sul workload cluster invece che sul management
cluster, il kubeconfig del workload viene passato esplicitamente:

```bash
helm upgrade --install flask-app-example charts/flask-app-example \
  --kubeconfig=./capi-quickstart.kubeconfig
```

Passare `--kubeconfig` direttamente è l'opzione più affidabile in questo caso,
dato che il context del workload vive in un file separato e non è mergiato nel
kubeconfig di default.

### 6. Verificare la release

```bash
helm --kubeconfig=./capi-quickstart.kubeconfig list -A
```

La release risulta `deployed` alla revision 1.

### 7. Accedere all'applicazione

L'applicazione viene raggiunta in locale tramite un port-forward contro il
workload cluster:

```bash
kubectl --kubeconfig=./capi-quickstart.kubeconfig \
  port-forward svc/flask-app-example 8080:80
```

L'app è quindi disponibile su `http://localhost:8080`.

## Riferimento per la selezione del cluster

Un punto ricorrente in questo workflow è assicurarsi che ogni comando colpisca il
cluster desiderato:

```bash
# Quale cluster colpirebbe un comando senza flag?
kubectl config current-context

# Elenca tutti i context disponibili (quello attivo è marcato con *)
kubectl config get-contexts

# Conferma a cosa punta davvero un kubeconfig
kubectl --kubeconfig=./capi-quickstart.kubeconfig get nodes
```

Il workload cluster mostra nomi di nodi in stile CAPD e sei nodi in totale; il
management cluster kind mostra un solo nodo control-plane. Ispezionare i nodi,
invece di fidarsi del nome del context, è il modo più sicuro per distinguerli.

## Cleanup

Eliminare l'oggetto `Cluster` dal management cluster smonta l'intero workload
cluster e i suoi container Docker:

```bash
kubectl delete cluster capi-quickstart
```

## Riferimenti

- [Cluster API Quick Start](https://cluster-api.sigs.k8s.io/user/quick-start.html)
- [Cluster API Book](https://cluster-api.sigs.k8s.io/)
- [Installazione di Calico](https://docs.tigera.io/calico/latest/getting-started/kubernetes/)