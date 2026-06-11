#!/bin/bash

# Usage: ./analisi_ip.sh 
FILE=accessi.txt
# Questo script serve per analizzare un file di testo contenente vari indirizzi ip,
# ordinarli e contarli dando in output i 3 indirizzi ip più comuni

sort "$FILE" | uniq -c | sort -rn | head -3

# sort       : ordina gli IP (mette vicini quelli uguali)
# uniq -c    : conta le occorrenze consecutive
# sort -rn   : riordina dal numero più alto al più basso
# head -3    : prende solo i primi 3 risultati