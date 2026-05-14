Gestione di un Conflitto Git

Questa esercitazione simula e risolve un conflitto Git, una delle situazioni più comuni nel lavoro collaborativo su repository condivise.

**Argomenti trattati:**
- Comprensione di come nascono i conflitti (modifiche concorrenti sullo stesso file/riga)
- Lettura e interpretazione dei marcatori di conflitto (`<<<<<<<`, `=======`, `>>>>>>>`)
- Strategie di risoluzione: accettare la versione locale, remota o creare una versione combinata
- Utilizzo di tool grafici (`git mergetool`) e risoluzione manuale

**Flusso dell'esercizio:**
```bash
# 1. Creare due branch che modificano lo stesso file
git checkout -b branch-A
echo "Modifica da branch A" >> file.txt
git add . && git commit -m "Modifica da A"

git checkout main
git checkout -b branch-B
echo "Modifica da branch B" >> file.txt
git add . && git commit -m "Modifica da B"

# 2. Effettuare il merge e provocare il conflitto
git checkout main
git merge branch-A
git merge branch-B    # ← qui scatta il conflitto

# 3. Risolvere il conflitto manualmente, poi:
git add file.txt
git commit -m "Risolto conflitto tra branch-A e branch-B"