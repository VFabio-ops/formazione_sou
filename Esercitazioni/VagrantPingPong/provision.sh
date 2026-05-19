#!/usr/bin/env bash

# Update and apache2 install
sudo apt update -y
sudo apt upgrade -y
sudo apt install openssh-server -y
sudo apt install apache2 -y
sudo service apache2 start
sudo service apache2 restart
sudo apt install docker.io -y
sudo usermod -a -G docker vagrant




