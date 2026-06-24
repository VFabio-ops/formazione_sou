# IPv4 Validator

Script Bash per la validazione di indirizzi IPv4 in notazione decimale puntata (dotted decimal notation), tramite espressione regolare.

## Descrizione

Lo script richiede in input una stringa e verifica, tramite pattern matching con espressione regolare, se rappresenta un indirizzo IPv4 sintatticamente valido. Un indirizzo è considerato valido se è composto da quattro numeri separati da un punto, ciascuno compreso nell'intervallo 0-255, senza zeri iniziali superflui.

## Requisiti

- Bash (l'operatore `=~` per il pattern matching è disponibile dalla versione 3.0 in poi)
- Nessuna dipendenza esterna

## Utilizzo

Rendere lo script eseguibile e lanciarlo:

```bash
chmod +x regex.sh
./regex.sh
```

Lo script chiede l'inserimento di un indirizzo IP da tastiera e restituisce un messaggio che ne indica la validità:

```
Inserisci IP: 192.168.1.1
Questo IP 192.168.1.1 è valido
```

```
Inserisci IP: 999.1.1.1
Questo IP 999.1.1.1 non è valido
```

## Logica dell'espressione regolare

La validazione si basa su un singolo blocco riutilizzato per ciascuno dei quattro ottetti dell'indirizzo:

```
([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])
```

Questo gruppo, posto in alternanza (OR), copre l'intero intervallo numerico valido 0-255 suddiviso in cinque fasce:

| Alternativa | Intervallo coperto | Descrizione |
|---|---|---|
| `[0-9]` | 0-9 | Singola cifra |
| `[1-9][0-9]` | 10-99 | Due cifre, senza zero iniziale |
| `1[0-9][0-9]` | 100-199 | Tre cifre che iniziano per 1 |
| `2[0-4][0-9]` | 200-249 | Tre cifre che iniziano per 2, seconda cifra 0-4 |
| `25[0-5]` | 250-255 | Tre cifre che iniziano per 25 |

Il blocco viene ripetuto quattro volte, separato da un punto letterale (`\.`, dove il backslash neutralizza il significato speciale del punto come metacarattere), e l'intera espressione è ancorata a inizio (`^`) e fine (`$`) stringa, per garantire che l'intero input, e non solo una sua porzione, corrisponda al pattern.

L'espressione regolare completa è:

```
^([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$
```

## Note implementative

- Il pattern è memorizzato in una variabile (`REGEX`) e confrontato tramite l'operatore `=~` all'interno di un test `[[ ]]`. La variabile contenente il pattern non viene racchiusa tra virgolette nel confronto, per evitare che Bash la interpreti come stringa letterale invece che come espressione regolare.
- Bash utilizza la sintassi POSIX ERE (Extended Regular Expressions) per l'operatore `=~`. La regex impiegata in questo script è compatibile con tale sintassi.
- L'assenza di zeri iniziali (es. `01`, `007`) è gestita implicitamente dalla struttura delle alternative: ogni fascia a più cifre impone che la prima cifra non possa essere `0`.

## Casi di test

| Input | Esito | Motivo |
|---|---|---|
| `192.168.1.1` | Valido | Tutti gli ottetti nell'intervallo 0-255 |
| `0.0.0.0` | Valido | Limite inferiore dell'intervallo |
| `255.255.255.255` | Valido | Limite superiore dell'intervallo |
| `256.1.1.1` | Non valido | 256 supera il limite massimo di 255 |
| `999.1.1.1` | Non valido | Valore fuori intervallo |
| `192.168.01.1` | Non valido | Zero iniziale non consentito nell'ottetto a due cifre |
| `1.2.3` | Non valido | Numero di ottetti insufficiente (3 invece di 4) |
| `1.2.3.4.5` | Non valido | Numero di ottetti eccessivo (5 invece di 4) |

## Limiti

Lo script valida la correttezza sintattica dell'indirizzo in notazione decimale puntata. Non verifica la raggiungibilità dell'host, l'appartenenza a classi di rete riservate o private, né l'effettiva esistenza dell'indirizzo su una rete.