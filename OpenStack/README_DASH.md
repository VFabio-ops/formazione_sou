# Creazione di un'istanza da dashboard (Horizon)

Guida al flusso corretto per creare un'istanza da Horizon e renderla
raggiungibile via SSH, seguendo il modello a floating IP (quello usato in
produzione: rete privata protetta, esposizione selettiva tramite floating IP).

Contesto: OpenStack all-in-one (Kolla-Ansible), rete privata `demo-net`
(`10.0.0.0/24`), rete esterna `public1` (`192.168.56.0/24`), accesso dall'host
sulla rete `192.168.56.x`.

---

## Modello di rete (il concetto da tenere fisso)

Le istanze si attaccano SOLO alla rete privata `demo-net`. Da fuori non sono
raggiungibili direttamente, perche' gli IP `10.0.0.x` sono isolati. Per
raggiungerle si assegna un floating IP, un indirizzo pubblico preso dalla rete
esterna `public1`; il router di Neutron fa da ponte (NAT) tra il floating IP e
l'IP privato dell'istanza.

Schema: istanza (10.0.0.x su demo-net) -> router -> floating IP (192.168.56.x su
public1) -> raggiungibile dall'host.

Perche' questo modello (e non attaccare le VM direttamente alla rete esterna):
in produzione le istanze stanno protette in reti private, e si decide caso per
caso quali esporre assegnando o togliendo un floating IP. E' piu' sicuro e piu'
controllabile. La rete esterna e' un serbatoio di indirizzi pubblici, non una
rete a cui le VM si agganciano direttamente.

---

## Procedura da dashboard

1. Compute > Istanze > "Avvia istanza".
2. Dettagli: nome dell'istanza.
3. Sorgente: selezionare l'immagine (es. `cirros`). Se si sceglie "Avvia da
   volume", l'istanza nasce da un volume Cinder persistente (in tal caso la
   colonna immagine mostrera' "booted from volume").
4. Sapore (flavor): scegliere la taglia. Con QEMU (niente KVM) usare un flavor
   piccolo (es. `m1.tiny`) per tempi di avvio ragionevoli.
5. Reti: selezionare SOLO `demo-net`. NON selezionare `public1`.
   Questo e' il punto critico: attaccare l'istanza direttamente a `public1`
   rompe il modello (vedi sezione Errori sotto).
6. Gruppi di sicurezza: assegnare un security group con le regole di ingresso
   per SSH (tcp/22) e ICMP (ping). Se si lascia `default`, verificare che quelle
   regole ci siano.
7. Coppia di chiavi: selezionare la chiave (es. `mykey`), cosi' viene iniettata
   nell'istanza per l'accesso SSH.
8. Avviare. Attendere lo stato `Attivo` (con QEMU puo' richiedere qualche minuto).

### Assegnare il floating IP (dopo la creazione)

1. Nella lista Istanze, menu Azioni dell'istanza > "Associa IP mobile".
2. Scegliere un floating IP esistente, oppure crearne uno nuovo con "+"
   selezionando la rete `public1`.
3. Associare. L'istanza mostrera' due indirizzi: quello privato `10.0.0.x` e il
   floating `192.168.56.x`.

Nota: il floating IP e' un passaggio esplicito, ma l'utente del progetto puo'
farlo da solo dalla dashboard, senza intervento dell'amministratore.

### Accesso SSH

Dall'host, con la chiave privata corrispondente a quella iniettata:

```bash
chmod 600 <chiave-privata>
ssh -i <chiave-privata> cirros@<floating-ip>
```

(utente `cirros` per l'immagine CirrOS).

---

## Provvedimenti presi e conseguenze

### Errore commesso: istanza attaccata direttamente a public1

Creando la prima istanza da dashboard, era stata selezionata sia `demo-net` sia
`public1` nella scelta delle reti. Risultato in `openstack server list`:

```bash
demo-net=10.0.0.67; public1=192.168.56.184
```

Conseguenza: l'istanza aveva un'interfaccia direttamente sulla rete esterna, ma
quell'indirizzo `192.168.56.184` NON era un floating IP (non compariva in
`openstack floating ip list`). Mancava il percorso di NAT del router, quindi
l'istanza era irraggiungibile: timeout sia in SSH sia in ping.

Segnale diagnostico: il security group risultava `default` due volte
(`[{'name': 'default'}, {'name': 'default'}]`), indice delle due interfacce di
rete.

### Provvedimento: ricreare l'istanza solo su demo-net + floating IP

- Ricreata l'istanza attaccandola SOLO a `demo-net`.
- Assegnato un floating IP vero dalla rete `public1`.

Conseguenza: l'istanza ha un IP privato su `demo-net` e un floating IP con NAT
dietro. Verifica corretta in `openstack floating ip list`: la riga del floating
mostra `Fixed IP Address` = IP interno dell'istanza e `Port` valorizzata. Da qui
ping e SSH funzionano.

Comandi equivalenti da CLI:

```bash
openstack floating ip create public1
openstack server add floating ip <istanza> <floating-ip>
openstack floating ip list
```

Chiarimento utile: `openstack floating ip create public1` NON crea una nuova
rete. `public1` e' la rete esterna (una sola), e il comando genera un floating IP
prendendolo da quel serbatoio. Se ne creano quanti ne servono, tutti dalla stessa
rete, fino a esaurire l'intervallo assegnato (qui `.150-.199`).

---

## Punti di controllo rapidi (checklist)

- `openstack server list`: l'istanza ha un solo IP interno `10.0.0.x` su
  `demo-net` (non un attacco diretto a `public1`).
- `openstack floating ip list`: il floating IP ha `Fixed IP Address` sull'IP
  interno dell'istanza e `Port` non vuota.
- Security group dell'istanza: ingress per tcp/22 e icmp presenti (controllare
  il gruppo effettivamente assegnato, non un `default` a caso).
- Chiave SSH: la stessa iniettata nell'istanza (es. `id_ecdsa` per `mykey`).

---

## Nota sul modello (produzione vs laboratorio)

Questo README segue il modello a floating IP, corretto per la produzione: reti
private isolate, esposizione selettiva e controllata. Esiste un'alternativa da
laboratorio (provider network: le istanze prendono direttamente un IP
raggiungibile, senza floating IP), piu' comoda ma meno sicura e senza controllo
selettivo dell'esposizione. Non adottata qui, per restare aderenti al modello
reale.

Evoluzione "da professionista", per il futuro: automatizzare l'assegnazione del
floating IP alla creazione con un template Heat (istanza + floating IP +
associazione in un unico stack), mantenendo il modello a floating IP ma
togliendo il passaggio manuale.
