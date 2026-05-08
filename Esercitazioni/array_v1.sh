#!/bin/bash
# declare -a serve per dichiarare un array.

declare -a arr=("Pippo" "Franco" "Spugna" "Forte" "Sapone" "Banana" "Zeppa" "Ciabatta" "Pippo")

# printf stampa i valori dell'array "%s\n" serve invece per andare a capo.
# "tr", letteralmente translate, la sua funzione è di sostituzione o rimozione di caratteri in base a quale flag viene utilizzata.
# "tr -s" serve a comprimere (in questo caso lo spazio) 
# "tr [:upper:] [:lower:]" rende tutti i caratteri MAIUSCOLI in minuscoli
# sort -u permette di ordinare alfabeticamente il contenuto dell'array e grazie alla flag (che equivarrebbe a uniq) eliminare i "doppioni"


printf "%s\n" ${arr[@]} | tr -d [:digit:] | tr -s [:space:] | tr [:lower:] [:upper:] | sort -u
