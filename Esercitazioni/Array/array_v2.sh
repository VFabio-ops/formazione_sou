#!/bin/bash
# Usage: ./ar.ray.sh

# array da manipolare
frutta=("Banana" "Mela" "Pera" "Ciliegie" "Prugna" "Fragole" "Pomodori" "BaNana" "PeRA" "Pesca" "PruGna")

# Conversione in lowercase
for i in "${!frutta[@]}"; do              		     # Il carattere "@" permette di accedere all'indice dell'array
	frutta[$i]="${frutta[$i],,}"       				 # così da poter modificare ogni elemento al suo interno.
done					   							 # {variabile,,} è una sintassi bash che converte in lowercase

# Bubble sort
n=${#frutta[@]}
for (( i=0; i < n-1; i++ )); do						# Il bubble sort confronta ogni coppia di
	for (( j=0; j < n-i-1; j++ )); do				# elementi adiacenti e li scambia se sono
		if [[ "${frutta[$j]}"  > "${frutta[$((j+1))]}" ]]; then	# nell'ordine sbagliato.
			tmp="${frutta[$j]}"						# Lo scambio usa una variabile temporanea "$tmp"
			frutta[$j]="${frutta[$((j+1))]}"		 
			frutta[$((j+1))]="$tmp"				
		fi
	done
done

# Rimozione duplicati
risultato=()
precedente=""
for elemento in "${frutta[@]}"; do		        	# Stesso funzionamento di "uniq", scorre l'array e aggiunge 
	if [[ "$elemento" != "$precedente" ]]; then		# ogni elemento al risultato solo se diverso da quello 
		risultato+=("$elemento")					# precedente.
		precedente="$elemento"						# Utilizziamo "!=" per controllare se l'elemento è diverso 
	fi												# rispetto ad un altro.
done

# Stampa risultato				
echo "=== RISULTATO ==="							# Utilizziamo il comando "echo" per stampare il risultato.
for array in "${risultato[@]}"; do	
	echo "$array"			
done					
