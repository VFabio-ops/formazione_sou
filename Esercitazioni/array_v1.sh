#!/bin/bash
# printf "%s\n" ${arr[@]} | tr -d [:digit:] | tr -s [:space:] | tr [:lower:] [:upper:] | sort 
declare -a arr=("Pippo" "Franco" "Spugna" "Forte" "Sapone" "Banana" "Zeppa" "Ciabatta" "Pippo")

sortedArr=($(printf "%s\n" "${arr[@]}" | sort -u))
list="${sortedArr[@]}"
trans=$(echo $list | tr [:upper:] [:lower:])

echo $trans
