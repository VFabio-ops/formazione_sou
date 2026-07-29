# Report Analisi Log e Metriche di Sistema
 
---
 
## Esercizio 1 — Analisi degli accessi al server
 
### Obiettivo
 
Leggere un file di log (`accessi.txt`) contenente un indirizzo IP per riga ed estrarre i 3 indirizzi più frequenti, ordinati dal più al meno ricorrente.
 
### Soluzione
 
```bash
sort accessi.txt | uniq -c | sort -rn | head -3
```
 
### Logica della pipeline
 
Il comando sfrutta una pipeline Unix composta da quattro fasi consecutive. Ogni comando riceve l'output del precedente tramite l'operatore `|`.
 
| Passo | Comando | Funzione |
|-------|---------|----------|
| 1 | `sort` | Ordina gli IP alfabeticamente, portando vicine le righe duplicate |
| 2 | `uniq -c` | Conta le occorrenze consecutive uguali e le prepone alla riga |
| 3 | `sort -rn` | Riordina numericamente (`-n`) in ordine decrescente (`-r`) |
| 4 | `head -3` | Restituisce solo le prime 3 righe |
 
Il passaggio critico è l'ordine tra `sort` e `uniq -c`: `uniq` conta solo righe **consecutive** identiche, quindi senza il `sort` iniziale gli indirizzi IP non adiacenti verrebbero conteggiati separatamente, producendo un risultato errato.