#!/usr/bin/env bash
vagrant ssh m1 -c "sudo docker run -d  --name farmer alpine sleep infinity" > /dev/null 2>&1
    vagrant ssh m1 -c "sudo docker run -d --name wolf alpine sleep infinity"    > /dev/null 2>&1
        vagrant ssh m1 -c "sudo docker run -d  --name sheep alpine sleep infinity" > /dev/null 2>&1
            vagrant ssh m1 -c "sudo docker run -d  --name cabbage alpine sleep infinity" > /dev/null 2>&1

vagrant ssh m1 -c "echo Sponda1 && sudo docker ps" && vagrant ssh m2 -c "echo Sponda2 && sudo docker ps" 
    echo "I 4 attori sono pronti a fare la traversata!"

vagrant ssh m1 -c "sudo docker rm -f sheep && sudo docker rm -f farmer" > /dev/null 2>&1
        echo "Il fattore porta la pecora sull'altra sponda."

vagrant ssh m2 -c "sudo docker run -d --name sheep alpine sleep infinity" > /dev/null 2>&1
    vagrant ssh m1 -c "echo Sponda1 && sudo docker ps" && vagrant ssh m2 -c "echo Sponda2 && sudo docker ps"
        echo "La pecora è ora sull'altra sponda."
            sleep 5

vagrant ssh m1 -c "sudo docker run -d --name farmer alpine sleep infinity" > /dev/null 2>&1
    vagrant ssh m1 -c "echo Sponda1 && sudo docker ps" && vagrant ssh m2 -c "echo Sponda2 && sudo docker ps"
        echo "Il fattore torna a prendere il cavolo."
            sleep 5

vagrant ssh m1 -c "sudo docker rm -f cabbage" > /dev/null 2>&1
    vagrant ssh m1 -c "sudo docker rm -f farmer" > /dev/null 2>&1
        echo "Il fattore porta il cavolo sull'altra sponda."

vagrant ssh m2 -c "sudo docker rm -f sheep"  > /dev/null 2>&1
    vagrant ssh m2 -c "sudo docker run -d --name cabbage alpine sleep infinity" > /dev/null 2>&1
        echo "Il fattore lascia il cavolo e riprende la pecora."
            sleep 5

vagrant ssh m1 -c "echo Sponda1 && sudo docker ps" && vagrant ssh m2 -c "echo Sponda2 && sudo docker ps"
    vagrant ssh m1 -c "sudo docker rm -f wolf" > /dev/null 2>&1
        echo "Ora il fattore torna a prendere il lupo e lasciare la pecora."
            sleep 5

vagrant ssh m1 -c "sudo docker run -d --name sheep alpine sleep infinity"  > /dev/null 2>&1  
    sleep 5

vagrant ssh m2 -c "sudo docker run -d --name wolf alpine sleep infinity" > /dev/null 2>&1
        sleep 5

vagrant ssh m1 -c "echo Sponda1 && sudo docker ps" && vagrant ssh m2 -c "echo Sponda2 && sudo docker ps"
    echo "Il fattore porta il lupo sull'altra sponda ed è pronto per la traversata finale!"
        sleep 5

vagrant ssh m1 -c "sudo docker rm -f sheep" > /dev/null 2>&1
    sleep 5

vagrant ssh m1 -c "echo Sponda1 && sudo docker ps" && vagrant ssh m2 -c "echo Sponda2 && sudo docker ps"
    sleep 5

vagrant ssh m2 -c "sudo docker run -d --name farmer alpine sleep infinity" > /dev/null 2>&1
    vagrant ssh m2 -c "sudo docker run -d --name sheep alpine sleep infinity" > /dev/null 2>&1
        sleep 5

vagrant ssh m1 -c "echo Sponda1 && sudo docker ps" && vagrant ssh m2 -c "echo Sponda2 && sudo docker ps"
    echo "Gioco riuscito! Il fattore, il lupo, la pecora e il cavolo sono tutti sull'altra sponda!"
