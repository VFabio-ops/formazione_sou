#!/bin/bash 
# Esegui questo script per generare il file metriche.txt di 100 righe 
SERVER_LIST=("srv-web01" "srv-db02" "srv-auth01" "srv-cache03") 
FILE_OUTPUT="metriche.txt" 
# Svuota il file se esiste già 
> "$FILE_OUTPUT" 
echo "Generazione di 100 righe in corso..." 
for i in {1..100}; do 
    # Seleziona un server casuale dall'array 
    rand_server=${SERVER_LIST[$((RANDOM % 4))]} 
    # Genera un valore di CPU casuale tra 10 e 99 
    rand_cpu=$((RANDOM % 90 + 10)) 
    # Scrive nel file 
    echo "$rand_server $rand_cpu" >> "$FILE_OUTPUT" 
done > "$FILE_OUTPUT" 
echo "File '$FILE_OUTPUT' generato con successo!" 