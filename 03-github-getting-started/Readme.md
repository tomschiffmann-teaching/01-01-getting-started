# GitHub

GitHub ist eine Plattform im Internet, auf der man Git-Repositories speichern kann. Dein Repository liegt dann nicht mehr nur lokal auf deinem Rechner, sondern zusätzlich auf einem Server – das nennt man **Remote-Repository**.

Vorteile:

- **Backup**: Dein Code ist gesichert, auch wenn dein Laptop kaputtgeht
- **Zusammenarbeit**: Mehrere Leute können am selben Projekt arbeiten
- **Zugriff von überall**: Du kannst dein Projekt auf jedem Rechner mit `git clone` herunterladen

## Grundbegriffe

### Was ist ein Remote?

Ein Remote ist die Verbindung von deinem lokalen Repository zu einem Repository im Internet. Der Standardname für diese Verbindung ist `origin`.

### Push und Pull

- `git push` – deine lokalen Commits zu GitHub **hochladen**
- `git pull` – Änderungen von GitHub **herunterladen**

## Account anlegen

1. Auf [github.com](https://github.com) registrieren
2. E-Mail-Adresse bestätigen

## SSH – warum überhaupt?

Damit GitHub weiß, dass wirklich *du* etwas hochlädst, musst du dich anmelden. Dafür gibt es zwei Wege:

- **HTTPS**: Du musst bei jedem Push einen Token (eine Art Passwort) eingeben
- **SSH**: Du hinterlegst einmalig einen digitalen Schlüssel – danach funktioniert alles automatisch

SSH funktioniert mit einem **Schlüsselpaar**:

| Schlüssel                        | Wo liegt er?           | Vergleich       |
| -------------------------------- | ---------------------- | --------------- |
| **Privater Schlüssel** (`id_ed25519`)     | Nur bei dir in der WSL | Dein Hausschlüssel – **niemals weitergeben!** |
| **Öffentlicher Schlüssel** (`id_ed25519.pub`) | Wird bei GitHub hinterlegt | Das Türschloss – darf jeder sehen |

GitHub prüft bei jeder Verbindung, ob dein privater Schlüssel zum hinterlegten öffentlichen Schlüssel passt. Nur dann darfst du pushen. Ein Passwort wird nie übertragen.

## Aufgabe 1: SSH-Verbindung zu GitHub einrichten

Alle Befehle führst du **in der WSL** aus (Ubuntu-Terminal oder das Terminal in VS Code).

### Schritt 1: Prüfen, ob schon ein Schlüssel existiert

```bash
ls -al ~/.ssh
```

Wenn dort eine Datei `id_ed25519.pub` auftaucht, hast du bereits einen Schlüssel und kannst Schritt 2 überspringen.

### Schritt 2: Schlüsselpaar erzeugen

```bash
ssh-keygen -t ed25519 -C "deine-email@example.com"
```

- Bei **„Enter file in which to save the key“** einfach `Enter` drücken (Standardpfad übernehmen)
- Bei **„Enter passphrase“** kannst du `Enter` drücken (kein Passwort) oder ein Passwort vergeben

Jetzt liegen in `~/.ssh` zwei Dateien: `id_ed25519` (privat) und `id_ed25519.pub` (öffentlich).

### Schritt 3: Öffentlichen Schlüssel anzeigen und kopieren

```bash
cat ~/.ssh/id_ed25519.pub
```

Markiere die komplette Ausgabe (beginnt mit `ssh-ed25519 ...`) und kopiere sie mit `Strg + Shift + C`.

### Schritt 4: Schlüssel bei GitHub hinterlegen

1. Auf GitHub oben rechts auf dein Profilbild → **Settings**
2. Links im Menü auf **SSH and GPG keys**
3. Button **New SSH key**
4. **Title**: z. B. `WSL Laptop`
5. **Key**: den kopierten Schlüssel einfügen
6. Auf **Add SSH key** klicken

### Schritt 5: Verbindung testen

```bash
ssh -T git@github.com
```

Beim ersten Mal fragt SSH, ob du dem Server vertraust – mit `yes` bestätigen. Wenn alles passt, erscheint:

```
Hi <dein-benutzername>! You've successfully authenticated, but GitHub does not provide shell access.
```

Die Meldung „does not provide shell access“ ist **kein Fehler** – sie ist normal.

## Aufgabe 2: Dein Repository zu GitHub hochladen

Wir nehmen das Repository aus Kapitel 02 (`mein-erstes-repo`).

### Schritt 1: Repository auf GitHub anlegen

1. Auf GitHub oben rechts auf **+** → **New repository**
2. **Repository name**: `mein-erstes-repo`
3. **Public** oder **Private** wählen
4. Alle Häkchen (README, .gitignore, License) **weglassen** – wir haben ja schon ein Repository
5. Auf **Create repository** klicken

### Schritt 2: SSH-Adresse kopieren

Auf der folgenden Seite auf den Reiter **SSH** klicken und die Adresse kopieren. Sie sieht so aus:

```
git@github.com:dein-benutzername/mein-erstes-repo.git
```

> Wichtig: **nicht** die HTTPS-Adresse (`https://github.com/...`) nehmen, sonst wird nach einem Passwort gefragt.

### Schritt 3: Remote verbinden und hochladen

Im Terminal in deinen Projektordner wechseln und ausführen:

```bash
git remote add origin git@github.com:dein-benutzername/mein-erstes-repo.git
git branch -M main
git push -u origin main
```

Was passiert hier?

- `git remote add origin ...` – die Verbindung zu GitHub anlegen
- `git branch -M main` – den Branch in `main` umbenennen (GitHub-Standard)
- `git push -u origin main` – die Commits hochladen; das `-u` merkt sich die Verbindung, danach reicht `git push`

### Schritt 4: Ergebnis prüfen

Lade die GitHub-Seite deines Repositories neu – deine Dateien und Commits sind jetzt dort sichtbar.

### Schritt 5: Weiterarbeiten mit VS Code

Ab jetzt kannst du wie in Kapitel 02 über die **Quellcodeverwaltung** arbeiten. Neu ist der Button **Änderungen synchronisieren** (_Sync Changes_) – er führt `git pull` und `git push` in einem Schritt aus.

1. Ändere `notizen.md`, stage die Datei und erstelle einen Commit
2. Klicke auf **Änderungen synchronisieren**
3. Prüfe auf GitHub, ob der neue Commit angekommen ist

## Kontrollfragen

- Warum darf der private Schlüssel niemals weitergegeben werden?
- Was ist der Unterschied zwischen `git commit` und `git push`?
- Wofür steht `origin`?
- Woran erkennst du, ob eine Repository-Adresse SSH oder HTTPS ist?
