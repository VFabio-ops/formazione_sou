#!/usr/bin/env bash

# Questo script serve per stampare una sequenza di numeri da 1 a quello inserito al fine 
# di vedere se sono pari o dispari

# Usage: ./oddEven.sh 

echo "Inserisci un numero intero da 0 a 999: "
read num

if [ -z "$num" ]; then
    echo "Errore: inserire un numero intero" >&2
    exit 1
fi

if ! [[ "$num" =~ ^[0-9]+$ ]]; then
    echo "Errore: l'argomento deve essere un numero intero" >&2
    exit 1
fi

for ((i=1; i<="$num"; i++)); do
    if (( i % 2 == 0 )); then
        echo "$i È pari"
    else
        echo "$i È dispari"
    fi
done