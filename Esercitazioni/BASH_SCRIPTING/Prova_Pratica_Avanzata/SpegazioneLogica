## Esercizio 2 — Calcolo della media CPU per server
 
### Obiettivo
 
Leggere un file (`metriche.txt`) contenente coppie `server valore_cpu`, calcolare la media di utilizzo CPU per ogni server e stamparla a schermo.
 
### Soluzione
 
```bash
#!/usr/bin/env bash
 
FILE="metriche.txt"
 
declare -A somma
declare -A occorrenze
 
while read SRV CPU; do
    somma[$SRV]=$(( somma[$SRV] + $CPU ))
    occorrenze[$SRV]=$(( occorrenze[$SRV] + 1 ))
done < "$FILE"
 
echo "=== REPORT UTILIZZO MEDIO CPU ==="
 
for SRV in "${!somma[@]}"; do
    MEDIA=$(( somma[$SRV] / occorrenze[$SRV] ))
    echo "$SRV: $MEDIA%"
done
```
 
### Logica dello script
 
Lo script si articola in tre fasi.
 
**Fase 1 — Dichiarazione degli array associativi**
 
```bash
declare -A somma
declare -A occorrenze
```
 
`declare -A` dichiara array associativi, ovvero strutture dati in cui la chiave è una stringa (in questo caso il nome del server) anziché un indice numerico. Vengono usati due array separati: uno per accumulare la somma dei valori CPU e uno per contare le occorrenze.
 
**Fase 2 — Lettura del file con ciclo `while`**
 
```bash
while read SRV CPU; do
    somma[$SRV]=$(( somma[$SRV] + $CPU ))
    occorrenze[$SRV]=$(( occorrenze[$SRV] + 1 ))
done < "$FILE"
```
 
Il costrutto `while read SRV CPU` legge il file una riga alla volta e assegna automaticamente il primo campo a `SRV` e il secondo a `CPU`. Il reindirizzamento `< "$FILE"` alimenta il ciclo con il contenuto del file. Ad ogni iterazione la somma e il contatore del server corrente vengono aggiornati tramite aritmetica intera `$(( ))`.
 
**Fase 3 — Calcolo e stampa con ciclo `for`**
 
```bash
for SRV in "${!somma[@]}"; do
    MEDIA=$(( somma[$SRV] / occorrenze[$SRV] ))
    echo "$SRV: $MEDIA%"
done
```
 
`${!somma[@]}` restituisce l'elenco delle chiavi dell'array, cioè i nomi univoci dei server. Per ciascuno viene calcolata la media con una divisione intera e stampata nel formato richiesto. La divisione intera è sufficiente ai fini dell'esercizio: Bash non supporta nativamente la virgola mobile.
 
### Problema riscontrato
 
Su macOS, lo shebang `#!/bin/bash` punta alla versione 3.x di Bash inclusa nel sistema, che non supporta `declare -A`. Utilizzando `#!/usr/bin/env bash` lo shebang risolve il `bash` più aggiornato disponibile nel PATH (tipicamente installato via Homebrew), che supporta correttamente gli array associativi.