# Merge Konflikte

Ein **Merge Konflikt** entsteht, wenn zwei Branches **dieselbe Stelle in derselben Datei** unterschiedlich geändert haben. Git kann dann nicht selbst entscheiden, welche Version die richtige ist – und fragt dich.

Das ist **kein Fehler und nichts Schlimmes**: Konflikte gehören zum normalen Alltag in einem Team. Wichtig ist nur, dass man weiß, wie man sie auflöst.

## Wann entsteht ein Konflikt?

| Situation                                                              | Konflikt?                       |
| ---------------------------------------------------------------------- | ------------------------------- |
| Zwei Branches ändern **verschiedene Dateien**                          | Nein – Git merged automatisch   |
| Zwei Branches ändern **verschiedene Zeilen** in derselben Datei         | Nein – Git merged automatisch   |
| Zwei Branches ändern **dieselbe Zeile** in derselben Datei              | **Ja** – du musst entscheiden   |

## Wie sieht ein Konflikt aus?

Git schreibt beide Versionen mit sogenannten **Konfliktmarkern** in die Datei:

```
<<<<<<< HEAD
# Arbeiten mit Merge Konflikten
=======
# Merge Konflikte beheben
>>>>>>> main
```

- `<<<<<<< HEAD` – deine Version (der Branch, auf dem du gerade bist)
- `=======` – die Trennlinie
- `>>>>>>> main` – die Version aus dem Branch, den du hereinmergen willst

**Auflösen heißt:** Du entscheidest dich für eine Version (oder schreibst etwas Neues) und löschst **alle** Markerzeilen (`<<<<<<<`, `=======`, `>>>>>>>`).

In VS Code musst du das nicht von Hand machen – über der Konfliktstelle erscheinen die Buttons **Aktuelle Änderung übernehmen** (_Accept Current Change_), **Eingehende Änderung übernehmen** (_Accept Incoming Change_) und **Beide Änderungen übernehmen** (_Accept Both Changes_).

## Aufgabe: Einen Merge Konflikt erzeugen und beheben

Wir bauen den Konflikt **absichtlich** nach: Zwei Branches ändern dieselbe Überschrift in derselben Datei.

> **Vorher prüfen:** Schau nach, ob die Datei `Merge_Conflicts.md` bzw. die Branches `dev-1-test` und `dev-2-test` in deinem Repository noch **nicht** existieren. Jede/r arbeitet im eigenen Repository – so ist am Ende jedes Repo abgedeckt und ihr kommt euch nicht gegenseitig in die Quere.

### Schritt 1: Ausgangslage auf `main` schaffen

```bash
git checkout main
```

1. Lege im Projektordner eine neue Datei `Merge_Conflicts.md` an
2. Schreibe genau eine Zeile hinein:

```markdown
# Merge Conflicts
```

3. Speichern, stagen, committen und auf `main` pushen:

```bash
git add Merge_Conflicts.md
git commit -m "Merge_Conflicts.md angelegt"
git push
```

### Schritt 2: Ersten Branch anlegen (`dev-1-test`)

```bash
git checkout -b dev-1-test
```

1. Ändere die Überschrift in `Merge_Conflicts.md` zu:

```markdown
# Merge Konflikte beheben
```

2. Committen und den Branch veröffentlichen:

```bash
git add Merge_Conflicts.md
git commit -m "Ueberschrift angepasst"
git push -u origin dev-1-test
```

3. Auf [github.com](https://github.com) den **Pull Request (PR-1)** von `dev-1-test` nach `main` erstellen – **noch nicht mergen!**

### Schritt 3: Zweiten Branch anlegen (`dev-2-test`)

Wichtig: `dev-2-test` startet vom **unveränderten** `main` – deshalb erst zurück auf `main` und pullen.

```bash
git checkout main
git pull
git checkout -b dev-2-test
```

1. Ändere die Überschrift in `Merge_Conflicts.md` zu:

```markdown
# Arbeiten mit Merge Konflikten
```

2. Committen und den Branch veröffentlichen:

```bash
git add Merge_Conflicts.md
git commit -m "Ueberschrift angepasst"
git push -u origin dev-2-test
```

3. Auf GitHub den **Pull Request (PR-2)** von `dev-2-test` nach `main` erstellen.

### Schritt 4: PR-1 mergen

1. Öffne auf GitHub **PR-1** und klicke auf **Merge pull request** → **Confirm merge**
2. `main` enthält jetzt die Überschrift `# Merge Konflikte beheben`

### Schritt 5: Den Konflikt sichtbar machen

1. Öffne auf GitHub **PR-2**
2. GitHub zeigt jetzt: **This branch has conflicts that must be resolved** – der Merge-Button ist gesperrt
3. Klappe die Konfliktanzeige auf und schau dir an, welche Datei betroffen ist

Warum? `main` und `dev-2-test` haben **dieselbe Zeile** unterschiedlich geändert.

### Schritt 6: Konflikt lokal in VS Code beheben

1. Öffne VS Code
2. Hole dir den aktuellen Stand von `main` und merge ihn in deinen Branch:

```bash
git checkout main && git pull
git checkout dev-2-test
git merge main
```

3. Git meldet: `CONFLICT (content): Merge conflict in Merge_Conflicts.md`
4. Öffne die Datei in VS Code – du siehst die Konfliktmarker und die Buttons darüber
5. Entscheide dich für eine Version (z. B. `# Arbeiten mit Merge Konflikten`) und stelle sicher, dass **keine** Markerzeilen mehr in der Datei stehen
6. Speichern, stagen, committen und pushen:

```bash
git add Merge_Conflicts.md
git commit -m "Merge Konflikt behoben"
git push
```

### Schritt 7: PR-2 mergen

1. Lade **PR-2** auf GitHub neu
2. Es sollte jetzt **Able to merge** stehen – der Konflikt ist weg
3. Mergen und den Branch anschließend löschen

### Schritt 8: Ergebnis teilen und Feedback geben

1. Schickt den **Link zu eurem PR/MR** in den Kurs-Chat
2. Schaut euch die PRs der anderen an und hinterlasst bei **mindestens einem** anderen Teilnehmer einen **Kommentar** im PR (Reiter **Conversation** oder direkt an einer Zeile unter **Files changed**)

So übt ihr nicht nur das Beheben von Konflikten, sondern auch das **Review** – genau so läuft die Zusammenarbeit im Team.

## Kontrollfragen

- Warum entsteht in Schritt 5 überhaupt ein Konflikt, obwohl beide Branches vom selben `main` gestartet sind?
- Was bedeuten die Zeilen `<<<<<<< HEAD`, `=======` und `>>>>>>>`?
- Was passiert, wenn du die Konfliktmarker aus Versehen in der Datei stehen lässt und committest?
- Warum ist es sinnvoll, `main` **in den Feature-Branch** zu mergen, statt den Konflikt direkt auf `main` zu lösen?
- Wie hättet ihr den Konflikt von vornherein vermeiden können?
