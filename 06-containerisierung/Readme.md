# Docker & Container: Deine Webseite als Image in die Cloud

Im letzten Kapitel hast du nginx **direkt** auf einer EC2-Instanz installiert. Das funktioniert – aber was, wenn du dieselbe Webseite auf 10 Servern brauchst? Oder wenn es auf dem Server plötzlich anders aussieht als auf deinem Laptop („Bei mir läuft's aber!“)?

In diesem Kapitel packst du deine Webseite in einen **Container**. Du installierst **Docker**, lernst die wichtigsten Befehle, baust ein eigenes **Image**, lädst es zu **Docker Hub** hoch und startest es am Ende mit einem einzigen Befehl auf deiner **EC2-Instanz**.

## Übung aus dem Kurs:

- [Getting started Übung: Schritt für Schritt von Docker Webseite](https://docs.docker.com/get-started/tutorials/run-an-app/)

## Grundbegriffe

### Was ist Containerisierung?

Ein **Container** ist ein abgeschottetes Paket, das eine Anwendung **zusammen mit allem, was sie zum Laufen braucht**, enthält: Programmcode, Bibliotheken, Konfiguration. Der Container läuft überall gleich – auf deinem Laptop, auf dem Server deiner Kollegin oder in der Cloud.

> **Vergleich:** Ein Schiffscontainer hat immer dieselbe Form. Egal ob Bananen oder Autos drin sind – jedes Schiff, jeder Kran und jeder LKW kann ihn transportieren. Genau daher kommt der Name.

### Container vs. virtuelle Maschine

Beides sorgt dafür, dass Anwendungen voneinander getrennt laufen. Der große Unterschied: **Eine VM bringt ein komplettes eigenes Betriebssystem mit – ein Container nicht.** Alle Container auf einem Rechner teilen sich den **Kernel** (den Kern des Betriebssystems) des Hosts.

```
        Virtualisierung                            Containerisierung
 ┌──────────┬──────────┬──────────┐       ┌──────────┬──────────┬──────────┐
 │  App A   │  App B   │  App C   │       │  App A   │  App B   │  App C   │
 ├──────────┼──────────┼──────────┤       ├──────────┼──────────┼──────────┤
 │ Biblioth.│ Biblioth.│ Biblioth.│       │ Biblioth.│ Biblioth.│ Biblioth.│
 ├──────────┼──────────┼──────────┤       └──────────┴──────────┴──────────┘
 │ Gast-OS  │ Gast-OS  │ Gast-OS  │       ┌────────────────────────────────┐
 │ (Ubuntu) │ (Debian) │(Windows) │       │   Container-Engine (Docker)    │
 └──────────┴──────────┴──────────┘       ├────────────────────────────────┤
 ┌────────────────────────────────┐       │   Betriebssystem des Hosts     │
 │  Hypervisor (z. B. AWS Nitro)  │       │   (ein gemeinsamer Kernel)     │
 ├────────────────────────────────┤       ├────────────────────────────────┤
 │      Physische Hardware        │       │ Hardware (oder eine VM!)       │
 └────────────────────────────────┘       └────────────────────────────────┘
```

| Eigenschaft             | Virtuelle Maschine (VM)                                     | Container                                                    |
| ----------------------- | ----------------------------------------------------------- | ------------------------------------------------------------ |
| **Was wird virtuell?**  | Die komplette **Hardware**                                  | Nur das **Betriebssystem** (Prozesse, Dateisystem, Netzwerk) |
| **Eigenes OS?**         | Ja, jede VM hat ein vollständiges Betriebssystem            | Nein, teilt sich den Kernel des Hosts                        |
| **Größe**               | Mehrere **Gigabyte**                                        | Oft nur wenige **Megabyte**                                  |
| **Startzeit**           | Sekunden bis Minuten (das OS muss hochfahren)               | Meist **unter einer Sekunde**                                |
| **Ressourcenverbrauch** | Hoch – jedes Gast-OS braucht eigenen Arbeitsspeicher        | Gering – nur die Anwendung selbst                            |
| **Isolation**           | Sehr stark (getrennt durch den Hypervisor)                  | Gut, aber schwächer (gemeinsamer Kernel)                     |
| **Andere OS möglich?**  | Ja, z. B. Windows-VM auf Linux-Host                         | Nein, Linux-Container brauchen einen Linux-Kernel            |
| **Typisches Beispiel**  | EC2-Instanz, VirtualBox, WSL 2                              | Docker, Podman, Kubernetes                                   |
| **Vergleich**           | Ein **Einfamilienhaus** – eigenes Fundament, eigene Heizung | Eine **Wohnung** – eigene Tür, aber gemeinsames Fundament    |

**Kein Entweder-oder:** In der Praxis laufen Container fast immer **in einer VM**. Genau das machst du heute: Deine EC2-Instanz ist eine VM, und darin startest du einen Docker-Container. Auch deine WSL ist technisch eine kleine VM.

### Die wichtigsten Docker-Begriffe

| Begriff                | Bedeutung                                                                                         | Vergleich                       |
| ---------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------- |
| **Docker**             | Das bekannteste Werkzeug, um Container zu bauen und zu starten                                    | Der Kran im Hafen               |
| **Image**              | Eine **unveränderliche Vorlage** mit Anwendung und allen Abhängigkeiten                           | Das Rezept / die Backform       |
| **Container**          | Eine **laufende Instanz** eines Images. Aus einem Image kann man beliebig viele Container starten | Der fertige Kuchen              |
| **Dockerfile**         | Eine Textdatei mit der Bauanleitung für ein Image                                                 | Die Rezeptkarte                 |
| **Registry**           | Ein Online-Speicher für Images                                                                    | Wie GitHub, nur für Images      |
| **Docker Hub**         | Die größte öffentliche Registry (`hub.docker.com`)                                                | Das „GitHub“ für Images         |
| **Repository**         | Ein Ordner in der Registry für ein bestimmtes Image (z. B. `nginx`) mit mehreren Versionen        | Ein GitHub-Repository           |
| **Tag**                | Die Versionsbezeichnung eines Images, z. B. `nginx:1.27` oder `nginx:latest`                      | Ein Etikett auf dem Karton      |
| **Port-Weiterleitung** | Verbindet einen Port des Hosts mit einem Port im Container (`-p 8080:80`)                         | Eine Durchreiche in die Wohnung |

### Das Gesamtbild

```
   Dein Laptop (WSL)                   Docker Hub                   AWS EC2-Instanz
 ┌─────────────────────┐          ┌─────────────────┐          ┌─────────────────────┐
 │ Dockerfile          │          │                 │          │                     │
 │ index.html          │          │ <user>/         │          │                     │
 │     │               │          │  meine-webseite │          │                     │
 │     ▼ docker build  │          │   :1.0          │          │                     │
 │ Image               │─ push ──▶│   :2.0          │── pull ─▶│ Image               │
 │     │               │          │                 │          │     │               │
 │     ▼ docker run    │          └─────────────────┘          │     ▼ docker run    │
 │ Container (:8080)   │                                       │ Container (:80) ◀───┼── Browser
 └─────────────────────┘                                       └─────────────────────┘
```

**Build once, run anywhere:** Das Image wird **einmal** gebaut und läuft danach auf jedem Rechner mit Docker – genau gleich.

## Voraussetzungen

- **WSL mit Ubuntu** (siehe Kapitel 01)
- Eine **laufende EC2-Instanz** mit Ubuntu, auf die du dich per SSH verbinden kannst, und einer Security Group, die Port `80` erlaubt (siehe Kapitel 05)
- Eine E-Mail-Adresse für den **Docker Hub**-Account
- Grundlegende Linux-Befehle und `nano` (siehe Haupt-Readme und Kapitel 05)

---

## Aufgabe 1: Docker auf Ubuntu installieren

Diese Anleitung gilt für **jedes Ubuntu** – du führst sie zuerst **in deiner WSL** aus und später in Aufgabe 5 noch einmal **auf der EC2-Instanz**.

Wir installieren Docker aus der **offiziellen Paketquelle von Docker**. Das Paket `docker.io` aus der Ubuntu-Paketquelle ist oft veraltet.

> **Hinweis für Windows:** Alternativ gibt es **Docker Desktop** für Windows, das sich automatisch in die WSL integriert. Wir installieren Docker hier bewusst direkt in Ubuntu, weil du es auf dem Server genauso machen musst. **Nicht beides gleichzeitig verwenden!**

### Schritt 0 (nur WSL): Ist systemd aktiv?

Docker wird unter Ubuntu von **systemd** gestartet (das Programm, das auch nginx automatisch gestartet hat). In neueren WSL-Versionen ist es standardmäßig aktiv. Prüfe es:

```bash
cat /etc/wsl.conf
```

Dort sollte stehen:

```
[boot]
systemd=true
```

Fehlt der Eintrag, füge ihn mit `sudo nano /etc/wsl.conf` hinzu. Danach **in PowerShell** (Windows) die WSL neu starten:

```powershell
wsl --shutdown
```

Anschließend das Ubuntu-Terminal wieder öffnen.

### Schritt 1: Alte Versionen entfernen

Falls schon einmal eine inoffizielle Docker-Version installiert wurde, kann das zu Konflikten führen:

```bash
sudo apt remove docker.io docker-compose docker-doc podman-docker containerd runc
```

Meldet `apt`, dass keines dieser Pakete installiert ist, ist das **kein Fehler** – dann ist alles sauber.

### Schritt 2: Benötigte Hilfsprogramme installieren

```bash
sudo apt update
sudo apt install -y ca-certificates curl
```

- `ca-certificates` – damit Ubuntu verschlüsselten Verbindungen (HTTPS) vertrauen kann
- `curl` – zum Herunterladen von Dateien (kennst du aus Kapitel 05)

### Schritt 3: Den Schlüssel von Docker hinzufügen

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

- Zeile 1: den Ordner `/etc/apt/keyrings` anlegen (für Schlüssel von fremden Paketquellen)
- Zeile 2: den **öffentlichen Schlüssel** von Docker herunterladen
- Zeile 3: die Datei für alle lesbar machen (`a+r` = _all + read_)

**Warum ein Schlüssel?** Jedes Docker-Paket ist digital **signiert**. Mit dem Schlüssel prüft `apt`, dass das Paket wirklich von Docker kommt und unterwegs nicht verändert wurde. Das Prinzip kennst du von SSH: öffentlicher Schlüssel zum Prüfen, privater Schlüssel (liegt bei Docker) zum Signieren.

### Schritt 4: Die Docker-Paketquelle eintragen

Den kompletten Block auf einmal kopieren und einfügen:

```bash
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```

Damit weiß `apt`, dass es Pakete auch bei Docker suchen soll. Der Teil `$(. /etc/os-release && ...)` setzt automatisch den Codenamen deiner Ubuntu-Version ein (z. B. `noble` für Ubuntu 24.04).

Paketliste neu laden:

```bash
sudo apt update
```

In der Ausgabe sollte jetzt eine Zeile mit `download.docker.com` auftauchen.

### Schritt 5: Docker installieren

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

| Paket                   | Aufgabe                                                         |
| ----------------------- | --------------------------------------------------------------- |
| `docker-ce`             | Der **Docker-Dienst** (_Docker Engine, Community Edition_)      |
| `docker-ce-cli`         | Der Befehl `docker`, mit dem du den Dienst steuerst             |
| `containerd.io`         | Das Programm, das Container im Hintergrund tatsächlich ausführt |
| `docker-buildx-plugin`  | Zum Bauen von Images (`docker build`)                           |
| `docker-compose-plugin` | Zum Starten mehrerer Container auf einmal (brauchen wir später) |

### Schritt 6: Prüfen, ob Docker läuft

```bash
sudo systemctl status docker
```

Es sollte in grün **active (running)** stehen. Mit `q` zurück.

```bash
sudo docker run hello-world
```

Wenn alles funktioniert, erscheint unter anderem:

```
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

Lies dir die Ausgabe genau durch – Docker erklärt dort selbst, was gerade passiert ist!

### Schritt 7: Docker ohne `sudo` verwenden

Damit du nicht vor jeden Befehl `sudo` schreiben musst, fügst du deinen Benutzer zur Gruppe `docker` hinzu:

```bash
sudo usermod -aG docker $USER
```

- `usermod` – einen Benutzer ändern (_user modify_)
- `-aG docker` – zur Gruppe `docker` **hinzufügen** (_append Group_). Ohne `-a` würde der Benutzer aus allen anderen Gruppen entfernt!
- `$USER` – wird automatisch durch deinen Benutzernamen ersetzt

Die Änderung gilt erst nach einer **neuen Anmeldung**. Am einfachsten:

- **WSL:** Terminal schließen und neu öffnen (klappt es nicht: `wsl --shutdown` in PowerShell)
- **EC2:** mit `exit` abmelden und per `ssh` neu verbinden

Danach testen – diesmal **ohne** `sudo`:

```bash
docker run hello-world
```

> **Sicherheitshinweis:** Mitglieder der Gruppe `docker` haben praktisch **Administratorrechte** auf dem Rechner. Auf einem Lern- oder eigenen Server ist das in Ordnung – in Firmen wird das oft eingeschränkt.

> **Tipp für später:** Docker bietet auch ein Installationsskript an, das die Schritte 2–5 in einem Befehl erledigt: `curl -fsSL https://get.docker.com | sh`. Praktisch – aber du führst dabei ein Skript aus dem Internet mit Administratorrechten aus, ohne es gelesen zu haben. Deshalb machen wir es hier einmal Schritt für Schritt.

---

## Aufgabe 2: Die wichtigsten Docker-Befehle

Alle Befehle führst du **in der WSL** aus.

### Schritt 1: Ein Image herunterladen

```bash
docker pull nginx
```

Docker lädt das offizielle nginx-Image von **Docker Hub** herunter. Weil kein Tag angegeben ist, wird automatisch `nginx:latest` verwendet.

Du siehst mehrere Zeilen mit `Pull complete` – ein Image besteht aus mehreren **Schichten** (_Layers_), die einzeln heruntergeladen werden.

### Schritt 2: Lokale Images anzeigen

```bash
docker images
```

```
REPOSITORY    TAG       IMAGE ID       CREATED       SIZE
nginx         latest    a1b2c3d4e5f6   2 weeks ago   192MB
hello-world   latest    f6e5d4c3b2a1   4 months ago  10kB
```

Vergleiche die Größe mit einem Ubuntu-Server: Die EC2-Festplatte hatte **8 GB**!

### Schritt 3: Einen Container starten

```bash
docker run -d -p 8080:80 --name mein-nginx nginx
```

| Teil                | Bedeutung                                                                                           |
| ------------------- | --------------------------------------------------------------------------------------------------- |
| `docker run`        | Einen neuen Container aus einem Image erstellen und starten                                         |
| `-d`                | Im **Hintergrund** laufen lassen (_detached_) – sonst ist dein Terminal blockiert                   |
| `-p 8080:80`        | **Port 8080 deines Rechners** wird an **Port 80 im Container** weitergeleitet (`Host:Container`)    |
| `--name mein-nginx` | Dem Container einen Namen geben. Ohne Namen erfindet Docker einen zufälligen (z. B. `happy_turing`) |
| `nginx`             | Das Image, aus dem der Container entsteht                                                           |

Öffne im Browser (auf Windows): **http://localhost:8080** – du siehst wieder **„Welcome to nginx!“**. Diesmal läuft nginx aber nicht direkt in Ubuntu, sondern in einem Container.

> **Warum Port 8080 und nicht 80?** Ports unter 1024 sind unter Linux besonders geschützt, und Port 80 ist auf deinem Laptop oft schon belegt. Im Container darf nginx aber ruhig auf Port 80 laufen – der Container hat sein **eigenes Netzwerk**.

### Schritt 4: Laufende Container anzeigen

```bash
docker ps
```

```
CONTAINER ID   IMAGE   COMMAND                  STATUS         PORTS                  NAMES
3f2a1b0c9d8e   nginx   "/docker-entrypoint.…"   Up 2 minutes   0.0.0.0:8080->80/tcp   mein-nginx
```

`docker ps` zeigt nur **laufende** Container. Mit `-a` (_all_) siehst du auch die beendeten – zum Beispiel die `hello-world`-Container von vorhin:

```bash
docker ps -a
```

### Schritt 5: Logs ansehen

```bash
docker logs mein-nginx
```

Hier siehst du alle Ausgaben von nginx – auch jeden Aufruf aus deinem Browser. Lade die Seite ein paar Mal neu und führe den Befehl erneut aus.

Mit `docker logs -f mein-nginx` werden neue Zeilen live angezeigt (_follow_). Beenden mit `Strg + C`.

### Schritt 6: In einen Container „hineinschauen“

```bash
docker exec -it mein-nginx bash
```

- `exec` – einen **zusätzlichen** Befehl in einem laufenden Container ausführen
- `-it` – interaktiv mit Terminal (_interactive + tty_), damit du tippen kannst
- `bash` – der Befehl, der ausgeführt wird: eine Shell

Die Eingabezeile ändert sich, z. B. zu `root@3f2a1b0c9d8e:/#`. **Du bist jetzt im Container!** Probiere:

```bash
cat /etc/os-release
ls /usr/share/nginx/html
exit
```

Im Container läuft ein **Debian**, obwohl dein Laptop **Ubuntu** hat. Aber: Es ist nur das Dateisystem von Debian – der Kernel ist der deiner WSL. Prüfe es mit `uname -r` einmal im Container und einmal außerhalb: **gleiche Ausgabe!** Genau das ist der Unterschied zur VM.

### Schritt 7: Container stoppen, starten und löschen

```bash
docker stop mein-nginx     # Container anhalten
docker ps -a               # Status: Exited
docker start mein-nginx    # wieder starten
docker stop mein-nginx
docker rm mein-nginx       # Container löschen
```

`docker rm` löscht nur den **Container**, nicht das Image. Das Image ist weiterhin da (`docker images`) und du kannst jederzeit neue Container daraus starten.

> **Container sind Wegwerfware:** Alles, was du **im** Container änderst, ist nach `docker rm` weg. Deshalb ändert man Container nicht von Hand, sondern baut ein neues Image – das machst du in Aufgabe 3.

### Schritt 8: Ein Image löschen

```bash
docker rmi hello-world
```

Kommt eine Fehlermeldung wie `image is being used by stopped container`? Dann gibt es noch Container aus diesem Image. Lösche sie zuerst mit `docker rm <Name oder ID>` (IDs findest du mit `docker ps -a`).

### Bonus: Ein komplettes Ubuntu in einer Sekunde

```bash
docker run -it --rm ubuntu bash
```

- `--rm` – der Container wird beim Beenden **automatisch gelöscht**

Wie lange hat das Starten gedauert? Vergleiche das mit dem Start deiner EC2-Instanz. Mit `exit` verlässt du den Container – und er ist weg.

---

## Aufgabe 3: Beispielprojekt – eigenes Image bauen

Jetzt packst du **deine eigene Webseite** in ein Image.

### Schritt 1: Projektordner anlegen

In der **WSL**:

```bash
mkdir -p ~/docker-webseite
cd ~/docker-webseite
code .
```

VS Code öffnet sich mit dem leeren Ordner.

### Schritt 2: Die Webseite erstellen

Lege in VS Code eine Datei `index.html` an:

```html
<!DOCTYPE html>
<html lang="de">
  <head>
    <meta charset="UTF-8" />
    <title>Meine Container-Webseite</title>
  </head>
  <body>
    <h1>Hallo aus dem Container! 🐳</h1>
    <p>Diese Seite läuft in einem Docker-Container.</p>
    <p>Erstellt von: DEIN NAME</p>
    <p>Version: 1.0</p>
  </body>
</html>
```

Ersetze `DEIN NAME` durch deinen Namen.

### Schritt 3: Das Dockerfile schreiben

Lege im selben Ordner eine Datei mit dem Namen **`Dockerfile`** an – genau so geschrieben, großes `D`, **ohne** Dateiendung:

```dockerfile
# Basis-Image: ein sehr kleines nginx auf Alpine Linux
FROM nginx:alpine

# Unsere Webseite in den Ordner kopieren, aus dem nginx ausliefert
COPY index.html /usr/share/nginx/html/index.html

# Dokumentation: Der Container lauscht auf Port 80
EXPOSE 80
```

| Anweisung | Bedeutung                                                                                     |
| --------- | --------------------------------------------------------------------------------------------- |
| `FROM`    | Auf welchem Image bauen wir auf? Wir müssen nginx nicht selbst installieren                   |
| `COPY`    | Eine Datei **von deinem Rechner** in das Image kopieren (`Quelle Ziel`)                       |
| `EXPOSE`  | Hinweis, welcher Port im Container verwendet wird. Öffnet den Port **nicht** – das macht `-p` |

Kommt dir der Ordner bekannt vor? In Kapitel 05 lag die Webseite in `/var/www/html` – im offiziellen nginx-Image ist es `/usr/share/nginx/html`.

> **Warum `nginx:alpine`?** **Alpine Linux** ist eine extrem kleine Linux-Distribution. Das Image ist dadurch nur einen Bruchteil so groß wie `nginx:latest`. Vergleiche nach dem Bauen die Größen mit `docker images`.

> **Musterlösung:** Alle Dateien aus diesem Beispielprojekt (inklusive einer `compose.yaml`) findest du im Ordner [`beispiel/`](./beispiel/). Starten mit `docker compose up -d --build` – dann ist die Webseite unter `http://localhost:8080` und Apache unter `http://localhost:8081` erreichbar.

Dein Ordner sieht jetzt so aus:

```
docker-webseite/
├── Dockerfile
└── index.html
```

### Schritt 4: Das Image bauen

Im Terminal (du musst im Ordner `~/docker-webseite` sein – prüfe mit `pwd`):

```bash
docker build -t meine-webseite:1.0 .
```

- `build` – ein Image nach der Anleitung im `Dockerfile` bauen
- `-t meine-webseite:1.0` – dem Image einen Namen und ein Tag geben (_tag_)
- `.` – der **Punkt** ist wichtig: Er bedeutet „das Dockerfile und die Dateien liegen im aktuellen Ordner“ (der sogenannte _Build-Kontext_)

Prüfen:

```bash
docker images
```

Dein Image `meine-webseite` mit dem Tag `1.0` steht in der Liste.

### Schritt 5: Das Image testen

```bash
docker run -d -p 8080:80 --name webseite meine-webseite:1.0
```

Öffne **http://localhost:8080** – du siehst deine eigene Seite 🎉

### Schritt 6: Eine neue Version bauen

1. In `index.html` die Zeile `Version: 1.0` in `Version: 2.0` ändern und speichern
2. Browser neu laden – **es passiert nichts!** Der Container läuft noch mit dem alten Image. Die Datei wurde beim Bauen **in das Image kopiert**, deine Änderung auf dem Laptop kennt der Container nicht.
3. Neues Image bauen und den alten Container ersetzen:

```bash
docker build -t meine-webseite:2.0 .
docker stop webseite
docker rm webseite
docker run -d -p 8080:80 --name webseite meine-webseite:2.0
```

4. Browser neu laden – jetzt steht dort **Version: 2.0**

Mit `docker images` siehst du beide Versionen. Du könntest jederzeit wieder Version 1.0 starten – so einfach sind **Rollbacks** mit Containern.

> **Tipp:** Beim zweiten Bauen steht bei manchen Schritten `CACHED`. Docker baut nur die Schichten neu, die sich geändert haben – deshalb geht es so schnell.

Container zum Schluss aufräumen:

```bash
docker stop webseite
docker rm webseite
```

---

## Aufgabe 4: Docker Hub – Account anlegen und Image hochladen

Bisher existiert dein Image nur auf deinem Laptop. Damit die EC2-Instanz es herunterladen kann, lädst du es zu **Docker Hub** hoch.

### Schritt 1: Account anlegen

1. [hub.docker.com](https://hub.docker.com) öffnen und auf **Sign up** klicken
2. **E-Mail**, **Username** und **Passwort** eingeben (oder mit GitHub/Google anmelden)
3. Die **E-Mail bestätigen** – ohne Bestätigung kannst du nichts hochladen
4. Bei der Frage nach dem Plan **Personal** (kostenlos) wählen

> **Merke dir deinen Username genau!** Er wird Teil jedes Image-Namens, z. B. `maxmuster/meine-webseite`. Docker-Namen bestehen nur aus **Kleinbuchstaben**, Zahlen und wenigen Sonderzeichen.

### Schritt 2: Access Token erstellen

Statt deines Passworts verwendest du im Terminal ein **Personal Access Token** – so wie bei GitHub. Ein Token kann man jederzeit einzeln widerrufen, ohne das Passwort zu ändern.

1. Oben rechts auf dein Profilbild → **Account settings**
2. Links **Personal access tokens** → **Generate new token**
3. **Access token description**: z. B. `wsl-laptop`
4. **Expiration date**: z. B. 30 Tage
5. **Access permissions**: **Read & Write**
6. Auf **Generate** klicken und das Token **sofort kopieren** – es wird nur **ein einziges Mal** angezeigt!

> **Achtung:** Das Token ist so geheim wie ein Passwort. **Niemals** in ein Git-Repository committen oder weitergeben.

### Schritt 3: Im Terminal anmelden

```bash
docker login -u <dein-username>
```

Bei `Password:` das **Token** einfügen (Rechtsklick oder `Strg + Shift + V`) und `Enter` drücken. Beim Einfügen siehst du **keine Zeichen** – das ist normal.

Erfolgreich, wenn dort steht:

```
Login Succeeded
```

### Schritt 4: Das Image richtig benennen

Docker Hub weiß am **Namen**, wohin ein Image gehört. Das Format ist:

```
<username>/<repository>:<tag>
```

Mit `docker tag` gibst du deinem vorhandenen Image einen **zusätzlichen Namen** (es wird nichts kopiert):

```bash
docker tag meine-webseite:1.0 <dein-username>/meine-webseite:1.0
docker tag meine-webseite:2.0 <dein-username>/meine-webseite:2.0
```

Mit `docker images` siehst du: Die neuen Einträge haben **dieselbe IMAGE ID** wie die alten – es ist dasselbe Image unter zwei Namen.

### Schritt 5: Hochladen

```bash
docker push <dein-username>/meine-webseite:1.0
docker push <dein-username>/meine-webseite:2.0
```

Beim zweiten Push steht bei vielen Schichten `Layer already exists` – die nginx-Schichten sind in beiden Versionen gleich und werden nur einmal gespeichert.

> **Wichtig für Mac-Nutzer (Apple M1/M2/…) und Windows-Laptops mit ARM-Prozessor:** Dein Image wird für die **ARM**-Architektur gebaut. Eine `t3.micro`-Instanz hat aber einen **Intel/AMD**-Prozessor (`amd64`). Baue das Image dann so:
>
> ```bash
> docker build --platform linux/amd64 -t <dein-username>/meine-webseite:1.0 .
> ```
>
> Welche Architektur du hast, zeigt `uname -m`: `x86_64` = amd64 (passt), `aarch64`/`arm64` = ARM.

### Schritt 6: Auf Docker Hub prüfen

1. Auf [hub.docker.com](https://hub.docker.com) oben auf **My Hub** bzw. **Repositories** klicken
2. Dein Repository `meine-webseite` öffnen
3. Im Reiter **Tags** siehst du `1.0` und `2.0`

Neue Repositories sind bei Docker Hub standardmäßig **Public** – jeder kann dein Image herunterladen, ohne sich anzumelden. Das brauchen wir gleich. Deshalb gehören in ein öffentliches Image **niemals** Passwörter oder Schlüssel!

---

## Aufgabe 5: Das Image auf der EC2-Instanz starten

Jetzt kommt alles zusammen: Dein Image aus Docker Hub läuft auf deinem Server in der Cloud.

### Schritt 1: Instanz starten und verbinden

1. In der AWS-Konsole (Region **us-east-1**) prüfen, ob deine Instanz **Running** ist. Falls sie gestoppt ist: **Instance state** → **Start instance**
2. Die **Public IPv4 address** kopieren – sie hat sich nach einem Neustart **geändert**!
3. In der WSL verbinden:

```bash
ssh -i ~/.ssh/ec2-kurs-key.pem ubuntu@<Public-IP>
```

Achte auf die Eingabezeile `ubuntu@ip-...` – ab jetzt arbeitest du **auf dem Server**.

### Schritt 2: Docker installieren

Führe **Aufgabe 1, Schritte 1 bis 7** auf dem Server aus (Schritt 0 gilt nur für die WSL und entfällt hier). Denk an das Ab- und wieder Anmelden nach Schritt 7.

Kontrolle:

```bash
docker run hello-world
```

### Schritt 3: nginx aus Kapitel 05 stoppen

Auf dem Server läuft noch das nginx, das du in Kapitel 05 direkt installiert hast. Es belegt **Port 80** – und ein Port kann nur von **einem** Programm gleichzeitig verwendet werden.

```bash
sudo systemctl stop nginx
sudo systemctl disable nginx
```

- `stop` – nginx jetzt beenden
- `disable` – nginx beim nächsten Neustart des Servers **nicht** automatisch starten

Hast du Kapitel 05 auf einer neuen Instanz übersprungen? Dann meldet der Befehl, dass es `nginx.service` nicht gibt – das ist in Ordnung.

### Schritt 4: Das Image herunterladen

```bash
docker pull <dein-username>/meine-webseite:1.0
docker images
```

Ein `docker login` ist hier **nicht nötig**, weil dein Repository öffentlich ist.

### Schritt 5: Den Container starten

```bash
docker run -d -p 80:80 --restart unless-stopped --name webseite <dein-username>/meine-webseite:1.0
```

Neu dabei:

- `-p 80:80` – diesmal **Port 80** des Servers, denn den hast du in der Security Group freigegeben
- `--restart unless-stopped` – Docker startet den Container **automatisch neu**, wenn er abstürzt oder der Server neu startet. Nur wenn du ihn selbst mit `docker stop` anhältst, bleibt er aus

Prüfen:

```bash
docker ps
curl localhost
```

### Schritt 6: Die Webseite im Browser öffnen 🎉

```
http://<Public-IP>
```

Du siehst **deine** Seite mit **Version: 1.0** – gebaut auf deinem Laptop, gespeichert bei Docker Hub, ausgeführt in der Cloud. Du musstest auf dem Server **keine einzige Datei** von Hand bearbeiten.

> **Wichtig:** Wie in Kapitel 05 `http://` (**ohne s**) verwenden!

### Schritt 7: Auf Version 2.0 aktualisieren

```bash
docker pull <dein-username>/meine-webseite:2.0
docker stop webseite
docker rm webseite
docker run -d -p 80:80 --restart unless-stopped --name webseite <dein-username>/meine-webseite:2.0
```

Browser neu laden (ggf. `Strg + F5`) – **Version: 2.0** ist online 🚀

Vergleiche das mit Kapitel 05: Dort musstest du Dateien auf dem Server bearbeiten oder per `git pull` holen. Jetzt tauschst du einfach das komplette, getestete Paket aus.

---

## Zusatzaufgabe 1: Der komplette Update-Kreislauf

Spiele einmal den kompletten Ablauf durch, wie er in echten Projekten (nur automatisiert) passiert:

1. **Lokal:** In `index.html` etwas ändern (z. B. eine Liste deiner Hobbys) und `Version: 3.0` eintragen
2. **Lokal:** Image bauen und direkt mit dem Docker-Hub-Namen versehen:

   ```bash
   docker build -t <dein-username>/meine-webseite:3.0 .
   ```

3. **Lokal:** Mit `docker run -p 8080:80 ...` auf `http://localhost:8080` testen
4. **Lokal:** `docker push <dein-username>/meine-webseite:3.0`
5. **Server:** alten Container stoppen und löschen, `3.0` herunterladen und starten
6. **Browser:** `http://<Public-IP>` prüfen

**Zum Knobeln:** Die Version 3.0 enthält einen Fehler. Wie kommst du auf dem Server in wenigen Sekunden zurück zu Version 2.0?

## Zusatzaufgabe 2: Ein fremdes Image auf dem Server starten

Auf Docker Hub gibt es tausende fertige Anwendungen. Starte auf dem Server zusätzlich das offizielle Image **httpd** (der Webserver _Apache_) auf **Port 8080**:

1. In der AWS-Konsole in der **Security Group** deiner Instanz eine Regel hinzufügen: **Type** `Custom TCP`, **Port range** `8080`, **Source** `Anywhere-IPv4` (`0.0.0.0/0`)
2. Auf dem Server:

   ```bash
   docker run -d -p 8080:80 --name apache httpd
   ```

3. `http://<Public-IP>:8080` im Browser öffnen – dort steht **„It works!“**

Jetzt laufen **zwei verschiedene Webserver** auf derselben Instanz, und beide denken, sie hätten Port 80 für sich allein. Mit `docker ps` siehst du beide.

**Zum Knobeln:** Was passiert, wenn du einen dritten Container mit `-p 8080:80` starten willst? Probier es aus und lies die Fehlermeldung.

## Zusatzaufgabe 3 (für Fortgeschrittene): Docker Compose

Lange `docker run`-Befehle kann man sich schlecht merken. Mit **Docker Compose** schreibst du sie in eine Datei.

Auf dem **Server**:

```bash
mkdir -p ~/app
cd ~/app
nano compose.yaml
```

```yaml
services:
  webseite:
    image: <dein-username>/meine-webseite:2.0
    ports:
      - "80:80"
    restart: unless-stopped

  apache:
    image: httpd
    ports:
      - "8080:80"
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 64M
          cpus: "0.5"
```

Der Block `deploy.resources.limits` begrenzt den Container auf **höchstens 64 MB Arbeitsspeicher** und **eine halbe CPU**. Braucht er mehr Speicher, beendet ihn der Kernel (_Out of Memory_, kurz **OOM**). So kann ein fehlerhafter Container nicht den ganzen Server lahmlegen – wichtig bei einer `t3.micro` mit nur 1 GB RAM. Mit `docker stats` siehst du in der Spalte `MEM USAGE / LIMIT` das Limit. Ohne Compose geht das gleiche mit `docker run --memory 64m --cpus 0.5 ...`.

> In YAML-Dateien sind die **Einrückungen** wichtig: immer mit **Leerzeichen**, nie mit Tabs.

Vorher die Container aus den Aufgaben entfernen (sonst sind die Ports belegt):

```bash
docker stop webseite apache
docker rm webseite apache
```

Dann alles mit **einem** Befehl starten:

```bash
docker compose up -d
docker compose ps
```

Stoppen und entfernen geht genauso einfach: `docker compose down`.

Für ein Update änderst du nur das Tag in `compose.yaml` und führst erneut `docker compose up -d` aus – Compose tauscht den Container automatisch aus.

---

## Befehlsübersicht

| Befehl                                          | Was passiert?                                             |
| ----------------------------------------------- | --------------------------------------------------------- |
| `docker pull <image>`                           | Image aus der Registry herunterladen                      |
| `docker images`                                 | Lokale Images anzeigen                                    |
| `docker build -t <name>:<tag> .`                | Image aus dem `Dockerfile` im aktuellen Ordner bauen      |
| `docker tag <alt> <neu>`                        | Einem Image einen zusätzlichen Namen geben                |
| `docker push <user>/<repo>:<tag>`               | Image zu Docker Hub hochladen                             |
| `docker login -u <user>`                        | Bei Docker Hub anmelden                                   |
| `docker run -d -p <host>:<cont> --name <n> <i>` | Container im Hintergrund starten mit Port-Weiterleitung   |
| `docker run -it --rm <image> bash`              | Interaktiven Wegwerf-Container starten                    |
| `docker ps` / `docker ps -a`                    | Laufende / alle Container anzeigen                        |
| `docker logs <container>`                       | Ausgaben eines Containers anzeigen (`-f` = live)          |
| `docker exec -it <container> bash`              | Shell in einem laufenden Container öffnen                 |
| `docker stop <container>`                       | Container anhalten                                        |
| `docker start <container>`                      | Angehaltenen Container wieder starten                     |
| `docker rm <container>`                         | Container löschen (muss gestoppt sein, oder `-f`)         |
| `docker rmi <image>`                            | Image löschen                                             |
| `docker system prune`                           | Alle gestoppten Container und ungenutzten Daten aufräumen |

## Aufräumen

### Auf dem Server und in der WSL

```bash
docker stop webseite
docker rm webseite
docker system prune -a
```

`docker system prune -a` löscht **alle** gestoppten Container und **alle** Images, die gerade von keinem Container verwendet werden. Docker fragt vorher nach – mit `y` bestätigen.

### Die EC2-Instanz

Wie in Kapitel 05: Instanz auswählen → **Instance state** → **Stop instance** (später weitermachen) oder **Terminate (delete) instance** (fertig).

Dein Image liegt sicher bei Docker Hub – auf einer neuen Instanz bist du mit `docker pull` und `docker run` in wenigen Minuten wieder online.

### Docker Hub (optional)

- Nicht mehr benötigtes **Access Token** löschen: **Account settings** → **Personal access tokens**
- Repository löschen: Repository öffnen → **Settings** → **Delete repository**

## Fehlerbehebung

| Fehlermeldung / Problem                                                 | Mögliche Ursache und Lösung                                                                                                                |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `permission denied while trying to connect to the Docker daemon socket` | Benutzer ist nicht in der Gruppe `docker` oder du hast dich danach nicht neu angemeldet → Aufgabe 1, Schritt 7                             |
| `Cannot connect to the Docker daemon ... Is the docker daemon running?` | Docker-Dienst läuft nicht → `sudo systemctl start docker`. In der WSL: prüfen, ob **systemd** aktiv ist (Aufgabe 1, Schritt 0)             |
| `System has not been booted with systemd as init system`                | systemd ist in der WSL nicht aktiv → Aufgabe 1, Schritt 0                                                                                  |
| `Unable to locate package docker-ce`                                    | Paketquelle fehlt oder `sudo apt update` vergessen → Aufgabe 1, Schritte 3 und 4 wiederholen                                               |
| `Conflicting values set for option Signed-By`                           | Die Docker-Quelle ist doppelt eingetragen → `ls /etc/apt/sources.list.d/` prüfen und die ältere Datei (z. B. `docker.list`) löschen        |
| `Bind for 0.0.0.0:80 failed: port is already allocated`                 | Ein anderer Container nutzt den Port schon → `docker ps` prüfen und den alten Container stoppen und löschen                                |
| `failed to bind host port ... address already in use`                   | Ein Programm **außerhalb** von Docker nutzt den Port (meist nginx aus Kapitel 05) → `sudo systemctl stop nginx`                            |
| `Conflict. The container name "/webseite" is already in use`            | Es gibt schon einen (evtl. gestoppten) Container mit dem Namen → `docker rm webseite` oder anderen Namen wählen                            |
| `failed to read dockerfile: open Dockerfile: no such file or directory` | Du bist im falschen Ordner (`pwd`) oder die Datei heißt anders (z. B. `dockerfile.txt`) → mit `ls` prüfen                                  |
| `"docker build" requires exactly 1 argument`                            | Den **Punkt** am Ende von `docker build` vergessen                                                                                         |
| `denied: requested access to the resource is denied` beim Push          | Nicht angemeldet (`docker login`) **oder** der Image-Name beginnt nicht mit **deinem** Username **oder** das Token hat keine Schreibrechte |
| `repository name must be lowercase`                                     | Großbuchstaben im Image-Namen → nur Kleinbuchstaben verwenden                                                                              |
| `pull access denied ... repository does not exist` auf dem Server       | Tippfehler im Namen/Tag oder das Repository ist **Private** → Name auf Docker Hub prüfen, Repository auf **Public** stellen                |
| `exec format error` / `no matching manifest for linux/amd64`            | Image wurde für ARM gebaut (z. B. auf einem Mac) → mit `--platform linux/amd64` neu bauen und pushen                                       |
| `toomanyrequests: You have reached your pull rate limit`                | Docker Hub begrenzt die Anzahl der Downloads ohne Anmeldung → auf dem Server `docker login` ausführen oder später erneut versuchen         |
| `http://localhost:8080` lädt in Windows nicht                           | Container läuft nicht (`docker ps`) oder falscher Port bei `-p` → `docker logs <name>` prüfen                                              |
| Browser zeigt nach `docker build` noch die alte Seite                   | Der **alte Container** läuft noch → stoppen, löschen, mit dem **neuen Tag** neu starten; `Strg + F5` im Browser                            |
| Browser zeigt „Welcome to nginx!“ statt deiner Seite auf dem Server     | Das nginx aus Kapitel 05 antwortet statt dem Container → `sudo systemctl stop nginx`, dann den Container neu starten                       |
| `Connection timed out` im Browser auf dem Server                        | `https://` statt `http://` **oder** Port fehlt in der Security Group **oder** neue Public IP nach Neustart nicht übernommen                |

## Kontrollfragen

- Was ist der wichtigste technische Unterschied zwischen einer **VM** und einem **Container**?
- Warum startet ein Container viel schneller als eine EC2-Instanz?
- Nenne je einen Vorteil von VMs und von Containern.
- Warum laufen Container in der Cloud trotzdem meistens **in** einer VM?
- Was ist der Unterschied zwischen einem **Image** und einem **Container**?
- Wofür ist das **Dockerfile** da, und was machen `FROM` und `COPY`?
- Was bedeutet `-p 8080:80`? Welche Zahl gehört zum Host, welche zum Container?
- Warum sieht der Container deine Änderung an `index.html` nicht, bevor du das Image neu baust?
- Was passiert mit Dateien, die du in einem Container änderst, wenn du ihn mit `docker rm` löschst?
- Warum musst du ein Image vor dem Push mit `docker tag` umbenennen?
- Warum verwendest du bei `docker login` ein **Token** statt deines Passworts?
- Warum brauchst du auf der EC2-Instanz kein `docker login`, um dein Image herunterzuladen?
- Warum musstest du das nginx aus Kapitel 05 stoppen?
- Was bewirkt `--restart unless-stopped`?
- Wie machst du auf dem Server ein **Rollback** auf eine ältere Version?
