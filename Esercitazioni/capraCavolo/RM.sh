#!/usr/bin/env bash
vagrant ssh m1 -c "sudo docker rm -f farmer"
vagrant ssh m1 -c "sudo docker rm -f wolf"
vagrant ssh m1 -c "sudo docker rm -f sheep"
vagrant ssh m1 -c "sudo docker rm -f cabbage"
vagrant ssh m2 -c "sudo docker rm -f farmer"
vagrant ssh m2 -c "sudo docker rm -f wolf"
vagrant ssh m2 -c "sudo docker rm -f sheep"
vagrant ssh m2 -c "sudo docker rm -f cabbage"
