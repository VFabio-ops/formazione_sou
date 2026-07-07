# Accesso remoto a un cluster Kind e deploy con Helm

Configurazione dell'accesso da una macchina client verso un cluster Kubernetes
Kind ospitato su una seconda macchina, con successivo deploy di un'applicazione
tramite Helm. L'esercizio ha finalità didattiche: comprendere il networking e la
gestione delle credenziali di Kubernetes, distinguendo i tre livelli coinvolti
nell'accesso a un cluster (raggiungibilità di rete, identità TLS del server,
autenticazione e autorizzazione del client).

## Architettura

Due macchine virtuali provisionate con Vagrant (provider VirtualBox), collegate
da una rete privata `192.168.100.0/24`.

| Macchina  | IP privato       | Ruolo                                             |
|-----------|------------------|---------------------------------------------------|
| `cluster` | `192.168.100.3`  | Ospita il cluster Kind; espone l'API server su 6443 |
| `kubectl` | `192.168.100.2`  | Client di orchestrazione; esegue `kubectl` e `helm` |

Il file `kubeconfig` utilizzato dal client impacchetta le informazioni dei tre
livelli: indirizzo dell'API server e CA di cui fidarsi (sezione `clusters`),
credenziale del client (sezione `users`) e loro associazione (sezione `contexts`).

## Prerequisiti

- Vagrant e VirtualBox sulla macchina host.
- Le due VM avviate a partire dal `Vagrantfile` del progetto.
- Sulla VM `cluster`: Docker, Kind e kubectl.
- Sulla VM `kubectl`: kubectl e Helm.

La cartella condivisa di default `/vagrant` è montata su entrambe le VM e punta
alla stessa directory dell'host: viene usata per scambiare i file (kubeconfig,
certificati) tra le due macchine. In alternativa si può usare `scp` sulla rete
privata.

## 1. Creazione del cluster Kind esposto

Il certificato dell'API server deve includere l'IP della VM `cluster` tra i
Subject Alternative Names (SAN); poiché il certificato non è modificabile a
posteriori, il cluster va creato con la configurazione corretta fin dall'inizio.

File `kind-config.yaml` (sulla VM `cluster`):

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "0.0.0.0"   # in ascolto su tutte le interfacce
  apiServerPort: 6443           # porta fissa, così il kubeconfig resta stabile
kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      certSANs:
        - "192.168.100.3"
        - "127.0.0.1"
        - "localhost"
```

Creazione del cluster:

```bash
kind delete cluster
kind create cluster --config kind-config.yaml
docker ps    # verifica la pubblicazione della porta: 0.0.0.0:6443->6443/tcp
```

Nota: Kind non è progettato per essere esposto in produzione. L'esposizione qui
descritta è accettabile solo in un ambiente di laboratorio isolato.

## 2. Estrazione della CA e trasferimento dei file

La CA del cluster serve al client per verificare l'identità dell'API server. Va
estratta una sola volta e riutilizzata da tutti i metodi di credenziali.

```bash
# sulla VM cluster, con il contesto amministrativo attivo
kubectl config view --raw --minify \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' \
  | base64 -d > /vagrant/ca.crt
```

## 3. Credenziali di accesso

Sono documentati tre metodi. In tutti e tre cambia soltanto la sezione `users`
del kubeconfig (la credenziale), mentre la sezione `clusters` (indirizzo e CA)
resta invariata.

### 3.1 Metodo A - Kubeconfig amministrativo

Riutilizza il certificato client `cluster-admin` generato da Kind. Utile come
verifica iniziale della connettività di rete e del TLS.

Sulla VM `cluster`:

```bash
kind get kubeconfig > /vagrant/admin.kubeconfig
# Kind scrive l'indirizzo come 0.0.0.0: va sostituito con l'IP raggiungibile
sed -i 's#https://0.0.0.0:6443#https://192.168.100.3:6443#' /vagrant/admin.kubeconfig
```

Sulla VM `kubectl`:

```bash
nc -zv 192.168.100.3 6443            # verifica preliminare della raggiungibilità
export KUBECONFIG=/vagrant/admin.kubeconfig
kubectl get nodes
```

### 3.2 Metodo B - ServiceAccount con token

La credenziale è un bearer token a tempo. I permessi sono assegnati esplicitamente
tramite RBAC e confinati a un singolo namespace.

Sulla VM `cluster`:

```bash
kubectl create namespace demo
kubectl create serviceaccount deployer -n demo

# associazione al ClusterRole predefinito "edit", limitata al namespace demo
kubectl create rolebinding deployer-edit \
  --clusterrole=edit --serviceaccount=demo:deployer -n demo

# generazione del token (nelle versioni recenti non è più permanente di default)
TOKEN=$(kubectl create token deployer -n demo --duration=8h)

# costruzione del kubeconfig basato sul token
kubectl config set-cluster kind \
  --server=https://192.168.100.3:6443 \
  --certificate-authority=/vagrant/ca.crt --embed-certs=true \
  --kubeconfig=/vagrant/sa.kubeconfig
kubectl config set-credentials deployer --token=$TOKEN \
  --kubeconfig=/vagrant/sa.kubeconfig
kubectl config set-context deployer@kind \
  --cluster=kind --user=deployer --namespace=demo \
  --kubeconfig=/vagrant/sa.kubeconfig
kubectl config use-context deployer@kind --kubeconfig=/vagrant/sa.kubeconfig
```

Verifica del confinamento RBAC dalla VM `kubectl`:

```bash
export KUBECONFIG=/vagrant/sa.kubeconfig
kubectl get pods -n demo    # consentito
kubectl get nodes           # negato: risorsa cluster-scoped fuori dal RoleBinding
```

### 3.3 Metodo C - Certificato client tramite CSR

La credenziale è un certificato client firmato dalla CA del cluster. Nel soggetto
del certificato, il campo `CN` diventa lo username e il campo `O` diventa il
gruppo; l'autorizzazione RBAC può quindi essere associata all'uno o all'altro.

Sulla VM `cluster`:

```bash
# 1. chiave privata e richiesta di firma (CN = utente, O = gruppo)
openssl genrsa -out /vagrant/jane.key 2048
openssl req -new -key /vagrant/jane.key -out /vagrant/jane.csr \
  -subj "/CN=jane/O=dev-team"

# 2. incapsulamento della CSR in un oggetto Kubernetes
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jane
spec:
  request: $(base64 -w0 /vagrant/jane.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
  expirationSeconds: 86400
EOF

# 3. approvazione ed estrazione del certificato firmato
kubectl certificate approve jane
kubectl get csr jane -o jsonpath='{.status.certificate}' | base64 -d > /vagrant/jane.crt

# 4. associazione RBAC al gruppo dichiarato nel certificato
kubectl create rolebinding jane-edit \
  --clusterrole=edit --group=dev-team -n demo

# 5. costruzione del kubeconfig basato su certificato e chiave
kubectl config set-cluster kind \
  --server=https://192.168.100.3:6443 \
  --certificate-authority=/vagrant/ca.crt --embed-certs=true \
  --kubeconfig=/vagrant/cert.kubeconfig
kubectl config set-credentials jane \
  --client-certificate=/vagrant/jane.crt --client-key=/vagrant/jane.key \
  --embed-certs=true --kubeconfig=/vagrant/cert.kubeconfig
kubectl config set-context jane@kind \
  --cluster=kind --user=jane --namespace=demo \
  --kubeconfig=/vagrant/cert.kubeconfig
kubectl config use-context jane@kind --kubeconfig=/vagrant/cert.kubeconfig
```

## 4. Deploy dell'applicazione con Helm

Helm non dispone di un proprio sistema di autenticazione: utilizza lo stesso
kubeconfig di kubectl. L'identità impiegata deve quindi avere i permessi RBAC per
tutte le risorse create dal chart nel namespace di destinazione.

Il chart è disponibile localmente sulla VM `kubectl` (repository clonato). Il
comando va lanciato dalla directory che contiene `Chart.yaml`, indicando il chart
come percorso locale (`.`) e non come riferimento a un repository remoto.

```bash
export KUBECONFIG=/vagrant/sa.kubeconfig    # oppure cert.kubeconfig
helm upgrade --install flask-app-example . --namespace demo
```

Output della prima installazione:

```
Release "flask-app-example" does not exist. Installing it now.
NAME: flask-app-example
LAST DEPLOYED: Tue Jul  7 07:48:30 2026
NAMESPACE: demo
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
```

L'uso di `upgrade --install` rende il comando idempotente: installa il release se
non esiste, altrimenti lo aggiorna. Questo conclude l'esercizio.

## 5. Verifica del deploy

```bash
helm list -n demo
kubectl get all -n demo
```

## Risoluzione dei problemi

I tre errori più comuni corrispondono ciascuno a uno dei tre livelli di accesso:

- `connection refused` o timeout: problema di rete o di firewall. Verificare la
  raggiungibilità della porta con `nc -zv 192.168.100.3 6443` prima di indagare
  altrove.
- Errore `x509: certificate is valid for ..., not 192.168.100.3`: l'IP della VM
  non è presente nei SAN del certificato dell'API server. Ricreare il cluster con
  i `certSANs` corretti (sezione 1).
- `Forbidden`: autenticazione riuscita ma permessi RBAC insufficienti. Verificare
  Role/RoleBinding associati all'identità in uso.

Per Helm, l'errore che segnala un repository inesistente si verifica quando il
chart locale viene passato senza percorso esplicito e Helm lo interpreta come
riferimento a un repository remoto. Indicare sempre il chart con `.` o con un
percorso (relativo con `./` o assoluto). Il rendering dei manifest senza toccare
il cluster è ottenibile con:

```bash
helm install flask-app-example . -n demo --dry-run --debug
```

## Pulizia

```bash
helm uninstall flask-app-example -n demo
kind delete cluster
```