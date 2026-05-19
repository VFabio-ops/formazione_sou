#!/usr/bin/env bash
barra(){
    echo -n "Ping"
for ((i=0; i<58; i++)); do
    echo -n "="
    sleep 1
done
echo -n "Pong"
sleep 1 
clear
}

while (true); do

vagrant ssh m1 -c "docker rm -f echoServer" > /dev/null 2>&1 
vagrant ssh m1 -c "docker pull ealen/echo-server:latest" > /dev/null 2>&1
vagrant ssh m1 -c "docker run -d --name echoServer ealen/echo-server" > /dev/null 2>&1 
barra
vagrant ssh m1 -c "docker rm -f echoServer" > /dev/null 2>&1 

vagrant ssh m2 -c "docker rm -fechoServer" > /dev/null 2>&1 
vagrant ssh m2 -c "docker pull ealen/echo-server:latest" > /dev/null 2>&1
vagrant ssh m2 -c "docker run -d --name echoServer ealen/echo-server" > /dev/null 2>&1
barra
vagrant ssh m2 -c "docker rm -f echoServer" > /dev/null 2>&1 

done

