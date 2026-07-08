# Gestione dei Secret in Kubernetes

Esercizio sulla creazione e sull'uso dei Secret in Kubernetes: creazione da riga
di comando, ispezione e modifica del formato YAML, iniezione in un Pod come
variabili d'ambiente. In chiusura, una nota sulla cifratura at rest.

Tutti i comandi presuppongono un cluster attivo e `kubectl` configurato. Gli
esempi usano un Secret chiamato `db-credentials` con le chiavi `username` e
`password`; sostituire i nomi con i propri.

## 1. Creazione del Secret con `--from-literal`

Per coppie chiave-valore arbitrarie si usa un Secret di tipo `generic`. L'opzione
`--from-literal` si può ripetere una volta per ogni chiave.

```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=s3cr3t

kubectl get secret db-credentials
```

## 2. Ispezione in YAML e creazione di un secondo Secret

Il Secret viene esportato in YAML e salvato su file:

```bash
kubectl get secret db-credentials -o yaml > secret.yaml
```

Nel file, la sezione `data:` contiene i valori codificati in Base64. Per creare un
Secret nuovo a partire da questo template:

- cambiare `metadata.name`;
- rimuovere i campi generati dal cluster (`creationTimestamp`, `resourceVersion`,
  `uid`), che non vanno ricopiati;
- sostituire i valori in `data:` con le nuove credenziali codificate.

La codifica va fatta con l'opzione `-n`, per evitare che `echo` aggiunga un
carattere di fine riga che finirebbe nel valore:

```bash
echo -n 'nuovo-utente' | base64
echo -n 'nuova-password' | base64
```

Per verificare un valore, si esegue la decodifica inversa:

```bash
echo 'VALORE_BASE64' | base64 -d; echo
```

Applicazione del nuovo Secret:

```bash
kubectl apply -f secret.yaml
```

Nota: esiste anche il campo `stringData:`, che accetta valori in chiaro e li
codifica automaticamente. In questo esercizio si usa `data:` di proposito, per
lavorare direttamente con la codifica Base64.

## 3. Pod con il Secret come variabili d'ambiente

Manifest del Pod (`pod.yaml`). Ogni voce sotto `env` associa il nome della
variabile all'interno del container a una chiave specifica del Secret tramite
`secretKeyRef`. Il nome della variabile può differire dal nome della chiave.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-demo
spec:
  containers:
    - name: demo
      image: busybox
      command: ["sleep", "3600"]
      env:
        - name: MY_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: MY_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
```

Il comando `sleep` mantiene il container in esecuzione: senza, `busybox`
terminerebbe subito e il Pod non resterebbe accessibile.

In alternativa, per iniettare tutte le chiavi del Secret in blocco (le variabili
assumono il nome delle chiavi), si sostituisce il blocco `env` con:

```yaml
      envFrom:
        - secretRef:
            name: db-credentials
```

Applicazione e verifica:

```bash
kubectl apply -f pod.yaml
kubectl get pod secret-demo          # attendere lo stato Running
kubectl exec -it secret-demo -- sh
# all'interno del Pod:
echo $MY_USER
echo $MY_PASSWORD
```

In caso il Pod non raggiunga lo stato `Running`, `kubectl describe pod secret-demo`
riporta la causa nella sezione `Events`.

## 4. Nota sulla cifratura at rest (approfondimento)

Base64 non è una cifratura: è una semplice codifica, reversibile con `base64 -d`.
I Secret vengono salvati nel database del cluster (etcd) e, di default, vi
risiedono solo in Base64: chiunque possa leggere etcd può leggerne il contenuto.

Le soluzioni per la cifratura at rest, non implementate in questo esercizio:

- Cifratura nativa di Kubernetes tramite `EncryptionConfiguration` passata
  all'API server con `--encryption-provider-config`, con provider come `aescbc`,
  `aesgcm`, `secretbox` o `kms` (KMS v2). Riferimento: documentazione ufficiale
  "Encrypting Confidential Data at Rest".
- Cluster locali: k3s offre l'opzione `--secrets-encryption`; su kind e minikube
  la configurazione va fornita manualmente all'API server.
- Approcci complementari che mantengono i segreti fuori da etcd o li cifrano a
  monte: Sealed Secrets, HashiCorp Vault, External Secrets Operator.

In tutti i casi, il controllo degli accessi (RBAC) su chi può leggere i Secret
resta parte integrante della loro protezione.