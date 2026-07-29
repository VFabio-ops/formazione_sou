#!/usr/bin/env bash
# Usage: ./analizza_metriche.sh 
FILE=metriche.txt     # Dichiarata la variabile $FILE
declare -A somma      # Dichiarato l'array associativo ${somma[@]}
declare -A occorrenze # Dichiarato l'array associativo ${occorrenze[@]}

# Ciclo while per la lettura del file riga per riga con assegnazione di due variabili: $SRV $CPU 
# che utilizzeremo come chiavi per i nostri array associativi.
while read SRV CPU; do
    somma[$SRV]=$(( somma[$SRV] + $CPU ))        # In questa stringa calcoliamo la somma della CPU accumulata dai server
    occorrenze[$SRV]=$(( occorrenze[$SRV] + 1 )) # In questa stringa calcoliamo il numero di volte che compaiono i server 
done < "$FILE"                                   # all'interno del file 
                                                 
echo "=== REPORT UTILIZZO MEDIO CPU ==="         # Un semplice comando echo che stampa a terminale una stringa 

# Ciclo for per la generazione dell'output. # La sintassi "${!somma[@]}" serve a richiamare le chiavi con "!"
for SRV in "${!somma[@]}"; do               # mentre si usa "@" per richiamare tutto l'array  
MEDIA=$(( somma[$SRV] / occorrenze[$SRV] )) # In questa stringa calcoliamo la media del consumo di CPU
echo "$SRV: $MEDIA%"                        # E con questa stringa stampiamo a schermo la media per ogni server
done