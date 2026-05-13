#!/bin/bash

# PortScanner Script using netcat 
# Usage:./port_scanner.sh <IP_ADDRESS> <PORT> <PORT>
HOST_IP=$1
HOST_PORT1=$2
HOST_PORT2=$3
	if [[ $# -ne 3 ]];
	then
		echo "INPUT non valido"
		echo "Usage:./port_scanner.sh <IP_ADDRESS> <PORT> <PORT>"
		exit 1
	fi



	if echo $HOST_IP | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$';  
	then
			echo "Indirizzo $HOST_IP valido!"
		else
			echo "Indirizzo $HOST_IP non valido."
			exit 1
	fi
	
	if [[ $HOST_PORT1 < '1' ]];
	then
		echo "The port is invalid, can't go under 1"
		exit 1
	fi

	if [[ $HOST_PORT2 > '65535' ]];

	then

		echo "The port doesn't exist! Max is 65535" 
		exit 1
	fi

 	for port in $(seq $HOST_PORT1 $HOST_PORT2); 

	do

		nc -w 1 $HOST_IP $port <<< "" && echo "Porta $port aperta."
	done
	echo "Scansione terminata."
