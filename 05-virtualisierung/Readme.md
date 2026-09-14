# AWS EC2 & nginx: Deine erste Webseite im Internet

Bisher lief alles lokal auf deinem Rechner. In diesem Kapitel mietest du dir einen **eigenen Server in der Cloud**, verbindest dich per **SSH** darauf und installierst den Webserver **nginx**. Am Ende kann **jeder auf der Welt** deine Webseite im Browser aufrufen.

## Grundbegriffe

### Was ist Virtualisierung?

Ein großer, physischer Server in einem Rechenzentrum wird in viele kleine **virtuelle Maschinen (VMs)** aufgeteilt. Jede VM verhält sich wie ein eigener Computer – mit eigenem Betriebssystem, eigener IP-Adresse und eigenem Speicher. Du merkst nicht, dass du dir die Hardware mit anderen teilst.

### Was ist AWS EC2?

**AWS** (Amazon Web Services) ist ein Cloud-Anbieter. **EC2** (Elastic Compute Cloud) ist der Dienst, mit dem man dort virtuelle Maschinen mietet. Eine solche VM heißt bei AWS **Instanz** (_Instance_).

| Begriff                            | Bedeutung                                                                                   | Vergleich                          |
| ---------------------------------- | ------------------------------------------------------------------------------------------- | ---------------------------------- |
| **Instanz** (_Instance_)           | Deine virtuelle Maschine in der Cloud                                                       | Ein gemieteter Computer            |
| **AMI** (_Amazon Machine Image_)   | Die Vorlage, aus der die Instanz erstellt wird (z. B. Ubuntu)                               | Die Installations-DVD              |
| **Instanztyp** (_Instance type_)   | Wie viel CPU und Arbeitsspeicher die Instanz hat (z. B. `t3.micro`)                         | Die Größe des Computers            |
| **Schlüsselpaar** (_Key pair_)     | Der SSH-Schlüssel, mit dem du dich anmeldest                                                | Wie bei GitHub: dein Hausschlüssel |
| **VPC** (_Virtual Private Cloud_)  | Dein eigenes, abgeschottetes Netzwerk in AWS (hast du bereits angelegt)                     | Das Grundstück                     |
| **Subnetz** (_Subnet_)             | Ein Teilbereich des VPCs. **Öffentlich** = mit Weg ins Internet (über das Internet Gateway) | Ein Gebäude auf dem Grundstück     |
| **Security Group**                 | Die Firewall der Instanz: legt fest, welche **Ports** von außen erreichbar sind             | Der Türsteher                      |
| **Öffentliche IP** (_Public IPv4_) | Die Adresse, unter der deine Instanz im Internet erreichbar ist                             | Die Hausnummer                     |

### Was ist ein Port?

Auf einem Server laufen oft mehrere Dienste gleichzeitig. Damit klar ist, welcher Dienst gemeint ist, hat jeder eine eigene **Portnummer** – wie Wohnungsnummern in einem Haus mit derselben Adresse.

| Port | Dienst   | Wofür brauchen wir ihn?                    |
| ---- | -------- | ------------------------------------------ |
| `22` | **SSH**  | Damit **du** dich auf den Server einloggst |
| `80` | **HTTP** | Damit **Besucher** deine Webseite sehen    |

### Was ist nginx?

**nginx** (ausgesprochen „Engine-X“) ist ein **Webserver**: ein Programm, das auf Anfragen aus dem Browser wartet und dann die passende Datei (z. B. `index.html`) zurückschickt.

### Das Gesamtbild

```
  Dein Laptop (WSL)                         AWS Cloud – dein VPC
 ┌──────────────────┐        ┌──────────────────────────────────────────────┐
 │                  │        │                  Öffentliches Subnetz        │
 │  Terminal        │─ SSH ─▶│  Internet   ┌────────────────────────────┐   │
 │                  │ (22)   │  Gateway ──▶│ Security Group (22 + 80)   │   │
 │  Browser         │─ HTTP ▶│             │  EC2-Instanz (Ubuntu)      │   │
 │                  │ (80)   │             │  nginx ─▶ index.html       │   │
 └──────────────────┘        │             └────────────────────────────┘   │
                             └──────────────────────────────────────────────┘
```

## Voraussetzungen

- Zugang zur **AWS-Konsole** (eigener Account oder Zugangsdaten aus dem Kurs)
- Dein **eigenes VPC** mit mindestens einem **öffentlichen Subnetz** (Internet Gateway angehängt, Route `0.0.0.0/0` → Internet Gateway)
- **WSL mit Ubuntu** (siehe Kapitel 01)
- Grundlegende Linux-Befehle wie `cd`, `ls`, `pwd` (siehe Haupt-Readme)

> **Tipp:** Stellt die Sprache der AWS-Konsole unten links (Zahnrad bzw. **Language**) auf **English**. Die Anleitung verwendet die englischen Bezeichnungen, so findet ihr alles leichter wieder.

---

## Aufgabe 1: EC2-Instanz erstellen

### Schritt 1: Region auswählen

1. In der [AWS-Konsole](https://console.aws.amazon.com) anmelden
2. Oben rechts die **Region** auf **US (North Virginia) us-east-1** stellen

Die Region ist der Standort des Rechenzentrums. North Virginia ist nah an uns, deshalb ist die Verbindung schnell.

> **Wichtig:** Eine Instanz ist nur in der Region sichtbar, in der sie erstellt wurde. Wenn eure Instanz „verschwunden“ ist, prüft zuerst die Region!

### Schritt 2: Den Assistenten starten

1. Oben in die Suche `EC2` eingeben und den Dienst öffnen
2. Auf den orangen Button **Launch instance** klicken

### Schritt 3: Name und Betriebssystem

1. **Name**: z. B. `webserver-vorname`
2. **Application and OS Images (AMI)**: **Ubuntu** auswählen und darunter **Ubuntu Server … LTS** mit dem Hinweis **Free tier eligible**

> **LTS** steht für _Long Term Support_: Diese Version bekommt jahrelang Sicherheitsupdates.

### Schritt 4: Instanztyp

**Instance type**: einen Typ mit dem Hinweis **Free tier eligible** wählen, z. B. `t3.micro` oder `t2.micro`.

Für eine einfache Webseite reicht das völlig.

### Schritt 5: Schlüsselpaar erstellen

Ohne Schlüssel kommst du später **nicht** auf den Server!

1. Bei **Key pair (login)** auf **Create new key pair** klicken
2. **Key pair name**: z. B. `ec2-kurs-key`
3. **Key pair type**: `ED25519` (derselbe Typ wie bei GitHub)
4. **Private key file format**: `.pem`
5. Auf **Create key pair** klicken – die Datei `ec2-kurs-key.pem` wird automatisch in deinen **Downloads**-Ordner geladen

> **Achtung:** Diese Datei ist dein **privater Schlüssel**. AWS speichert ihn **nicht** – wenn du ihn verlierst, kannst du dich nicht mehr einloggen. Und: **niemals weitergeben oder in ein Git-Repository committen!**

### Schritt 6: Netzwerkeinstellungen – dein VPC auswählen

Standardmäßig würde AWS die Instanz in das **Default-VPC** legen. Wir wollen aber **dein eigenes VPC** aus der letzten Aufgabe verwenden.

1. Im Bereich **Network settings** oben rechts auf **Edit** klicken
2. **VPC**: dein eigenes VPC auswählen (z. B. `vpc-vorname`) – **nicht** das mit `(default)` markierte
3. **Subnet**: ein **öffentliches** Subnetz deines VPCs auswählen (z. B. `public-subnet-1`)
4. **Auto-assign public IP**: auf **Enable** stellen

> **Warum ein öffentliches Subnetz?** Nur ein Subnetz, dessen Route Table eine Route `0.0.0.0/0` zum **Internet Gateway** hat, ist aus dem Internet erreichbar. In einem privaten Subnetz kommst du weder per SSH noch per Browser an deine Instanz.
>
> **Warum „Auto-assign public IP“?** In selbst angelegten Subnetzen ist diese Einstellung meist **ausgeschaltet**. Dann bekommt die Instanz keine öffentliche IP – und ohne Adresse findet sie niemand im Internet.

### Schritt 7: Security Group anlegen

Direkt darunter bei **Firewall (security groups)** legst du fest, wer deinen Server erreichen darf:

1. **Create security group** auswählen
2. **Security group name**: z. B. `webserver-sg`
3. Die erste Regel ist schon da – so einstellen:
   - **Type**: `ssh` (Port `22`)
   - **Source type**: **Anywhere** (`0.0.0.0/0`)
   - So darf sich nur dein aktueller Internetanschluss per SSH verbinden
4. Auf **Add security group rule** klicken und die zweite Regel einstellen:
   - **Type**: `HTTP` (Port `80`)
   - **Source type**: **Anywhere** (`0.0.0.0/0`)
   - Ohne diese Regel kann niemand deine Webseite sehen!

> **Warum normalerweise nicht einfach „Anywhere“ bei SSH?** Dann könnte jeder Rechner im Internet versuchen, sich einzuloggen. Automatisierte Angriffe auf Port 22 passieren ständig. Also: nur so viel öffnen wie nötig.

### Schritt 8: Instanz starten

1. **Configure storage** auf dem Standardwert lassen
2. Rechts auf **Launch instance** klicken
3. Auf **View all instances** klicken
4. Warten, bis bei deiner Instanz **Instance state: Running** steht (ca. 1 Minute)

### Schritt 9: Öffentliche IP-Adresse notieren

1. Deine Instanz in der Liste anklicken
2. Unten im Reiter **Details** die **Public IPv4 address** kopieren (z. B. `3.121.45.67`)

Diese Adresse brauchst du gleich für SSH und für den Browser.

> **Das Feld ist leer?** Dann war **Auto-assign public IP** nicht eingeschaltet. Am einfachsten: Instanz beenden (**Terminate**) und neu erstellen – diesmal mit **Enable** in Schritt 6.

---

## Aufgabe 2: Per SSH auf die Instanz verbinden

Alle Befehle führst du **in der WSL** aus (Ubuntu-Terminal oder das Terminal in VS Code).

### Schritt 1: Schlüssel in die WSL kopieren

Der Schlüssel liegt im Windows-Downloads-Ordner. Die WSL erreicht deine Windows-Laufwerke unter `/mnt/c/`.

```bash
mkdir -p ~/.ssh
cp /mnt/c/Users/<Windows-Benutzername>/Downloads/ec2-kurs-key.pem ~/.ssh/
```

- `mkdir -p ~/.ssh` – den Ordner `.ssh` anlegen (falls er schon existiert, passiert nichts)
- `cp <quelle> <ziel>` – die Datei kopieren (_copy_)
- `<Windows-Benutzername>` durch deinen Windows-Benutzernamen ersetzen. Du findest ihn mit `ls /mnt/c/Users/`

### Schritt 2: Dateirechte setzen

```bash
chmod 400 ~/.ssh/ec2-kurs-key.pem
```

`chmod 400` bedeutet: **Nur du darfst die Datei lesen** – niemand sonst, und auch keiner darf sie verändern.

SSH ist hier streng: Wenn andere den privaten Schlüssel lesen könnten, **verweigert SSH die Verbindung**. Deshalb kopieren wir den Schlüssel auch in die WSL – auf dem Windows-Laufwerk (`/mnt/c/...`) funktioniert `chmod` nicht richtig.

### Schritt 3: Verbinden

```bash
ssh -i ~/.ssh/ec2-kurs-key.pem ubuntu@<Public-IP>
```

Beispiel: `ssh -i ~/.ssh/ec2-kurs-key.pem ubuntu@3.121.45.67`

Was bedeutet der Befehl?

- `ssh` – eine verschlüsselte Verbindung zu einem anderen Computer aufbauen
- `-i ~/.ssh/ec2-kurs-key.pem` – diesen Schlüssel verwenden (_identity file_)
- `ubuntu` – der Benutzername auf dem Server (bei Ubuntu-AMIs heißt er immer `ubuntu`)
- `@<Public-IP>` – die Adresse deiner Instanz

Beim ersten Mal fragt SSH, ob du dem Server vertraust:

```
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Mit `yes` bestätigen – genau wie bei GitHub.

> **Tipp:** In der AWS-Konsole gibt es bei deiner Instanz oben den Button **Connect** → Reiter **SSH client**. Dort steht der passende Befehl schon fertig zum Kopieren (nur den Pfad zum Schlüssel musst du anpassen).

### Schritt 4: Bin ich wirklich auf dem Server?

Schau dir die Eingabezeile an. Sie hat sich verändert:

```
ubuntu@ip-172-31-12-34:~$
```

- `ubuntu` – du bist als Benutzer `ubuntu` angemeldet
- `ip-172-31-12-34` – der Name des Servers (das ist seine **interne** IP im AWS-Netzwerk, nicht die öffentliche)

Probiere ein paar bekannte Befehle aus: `pwd`, `ls -a`, `whoami`.

**Alles, was du jetzt eintippst, läuft auf dem Server in North Virginia – nicht auf deinem Laptop!**

Mit `exit` trennst du die Verbindung wieder. Für die nächste Aufgabe bleibst du aber verbunden.

---

## Aufgabe 3: nginx installieren und die Webseite aufrufen

### Schritt 1: Paketliste aktualisieren

```bash
sudo apt update
```

- `sudo` – den Befehl mit Administratorrechten ausführen (_superuser do_)
- `apt update` – die Liste der verfügbaren Programme neu herunterladen (es wird noch nichts installiert)

### Schritt 2: nginx installieren

```bash
sudo apt install -y nginx
```

Das `-y` beantwortet die Rückfrage „Möchten Sie fortfahren?“ automatisch mit **Ja**.

### Schritt 3: Prüfen, ob nginx läuft

```bash
systemctl status nginx
```

Wenn alles passt, steht dort in grün: **active (running)**. Mit der Taste `q` kommst du wieder zurück zur Eingabezeile.

Unter Ubuntu startet nginx nach der Installation automatisch – und auch nach jedem Neustart des Servers.

Zusätzlich kannst du die Webseite direkt **auf dem Server** abrufen:

```bash
curl localhost
```

`curl` lädt eine Webseite im Terminal herunter. Du siehst den HTML-Code der nginx-Startseite.

### Schritt 4: Die Webseite im Browser öffnen 🎉

Öffne in deinem Browser (auf Windows):

```
http://<Public-IP>
```

Du solltest die Seite **„Welcome to nginx!“** sehen.

> **Wichtig:** Tippe unbedingt `http://` (**ohne s**) vor die IP. Viele Browser versuchen sonst automatisch `https://` – das haben wir nicht eingerichtet, und die Seite lädt ewig.

Schicke den Link an deine Sitznachbarin oder deinen Sitznachbarn – die Seite ist wirklich **öffentlich im Internet**!

---

## Zusatzaufgabe 1: Die Webseite bearbeiten

Die Startseite von nginx ist langweilig. Wir bauen eine eigene.

### Schritt 1: Wo liegt die Webseite?

nginx liefert alle Dateien aus dem Ordner `/var/www/html` aus:

```bash
cd /var/www/html
ls
```

Dort liegt die Datei `index.nginx-debian.html` – das ist die „Welcome to nginx!“-Seite.

nginx sucht in diesem Ordner zuerst nach einer Datei `index.html`. Gibt es sie, wird **sie** angezeigt. Wir legen also einfach eine eigene `index.html` an.

### Schritt 2: Datei mit dem Editor `nano` öffnen

```bash
sudo nano /var/www/html/index.html
```

- `nano` ist ein einfacher Texteditor im Terminal
- `sudo` brauchen wir, weil der Ordner `/var/www/html` dem Administrator (`root`) gehört

Es öffnet sich ein leerer Editor.

### Schritt 3: HTML-Code einfügen

Kopiere diesen Code und füge ihn im Terminal mit **Rechtsklick** oder `Strg + Shift + V` ein:

```html
<!DOCTYPE html>
<html lang="de">
  <head>
    <meta charset="UTF-8" />
    <title>Meine erste Webseite</title>
  </head>
  <body>
    <h1>Hallo Internet! 👋</h1>
    <p>Diese Seite läuft auf meinem eigenen Server bei AWS.</p>
    <p>Erstellt von: DEIN NAME</p>
  </body>
</html>
```

Ersetze `DEIN NAME` durch deinen Namen. In `nano` bewegst du dich mit den **Pfeiltasten** – die Maus funktioniert hier nicht.

### Schritt 4: Speichern und schließen

| Tastenkombination | Aktion                                                  |
| ----------------- | ------------------------------------------------------- |
| `Strg + O`        | Speichern (_Write Out_) – danach mit `Enter` bestätigen |
| `Strg + X`        | `nano` beenden                                          |

Unten in `nano` stehen diese Befehle übrigens auch: `^` bedeutet `Strg`.

### Schritt 5: Ergebnis ansehen

Lade die Seite im Browser neu. Siehst du noch die alte Seite? Dann mit `Strg + F5` neu laden – der Browser hat sie zwischengespeichert (_Cache_).

nginx muss **nicht** neu gestartet werden: Er liest die Datei bei jedem Aufruf neu.

## Zusatzaufgabe 2: Eine zweite Seite verlinken

### Schritt 1: Neue Seite anlegen

```bash
sudo nano /var/www/html/ueber-mich.html
```

```html
<!DOCTYPE html>
<html lang="de">
  <head>
    <meta charset="UTF-8" />
    <title>Über mich</title>
  </head>
  <body>
    <h1>Über mich</h1>
    <p>Hier steht etwas über mich.</p>
    <a href="index.html">Zurück zur Startseite</a>
  </body>
</html>
```

Speichern (`Strg + O`, `Enter`) und schließen (`Strg + X`).

### Schritt 2: Link auf der Startseite einfügen

Öffne die `index.html` erneut und füge vor `</body>` diese Zeile ein:

```html
<a href="ueber-mich.html">Über mich</a>
```

### Schritt 3: Testen

- `http://<Public-IP>` öffnen und auf den Link klicken
- Die zweite Seite ist auch direkt unter `http://<Public-IP>/ueber-mich.html` erreichbar

**Zum Knobeln:** Gib `http://<Public-IP>/gibtsnicht.html` ein. Was zeigt nginx an – und warum?

## Zusatzaufgabe 3 (für Fortgeschrittene): Webseite über GitHub veröffentlichen

Direkt auf dem Server mit `nano` zu arbeiten ist mühsam. In der Praxis schreibt man den Code **lokal in VS Code**, lädt ihn zu **GitHub** hoch und holt ihn auf dem Server ab. Hier kommt alles zusammen, was du in den Kapiteln 02 und 03 gelernt hast!

```
VS Code (WSL) ── git push ──▶ GitHub ◀── git pull ── EC2-Server (nginx)
```

### Schritt 1: Lokal ein Repository anlegen

1. In der **WSL auf deinem Laptop** einen Ordner `meine-webseite` anlegen und in VS Code öffnen
2. Eine Datei `index.html` mit deinem HTML-Code erstellen
3. Committen und auf GitHub in ein **neues, öffentliches** (_Public_) Repository `meine-webseite` pushen (wie in Kapitel 03)

> Das Repository muss **Public** sein, damit der Server es ohne Anmeldung herunterladen kann.

### Schritt 2: Ordner auf dem Server vorbereiten

Auf dem **Server** (per SSH verbunden):

```bash
sudo chown -R ubuntu:ubuntu /var/www/html
cd /var/www/html
rm -f *.html
```

- `chown -R ubuntu:ubuntu` – der Benutzer `ubuntu` wird Besitzer des Ordners (_change owner_). Ab jetzt brauchst du dort kein `sudo` mehr
- `rm -f *.html` – alle HTML-Dateien im **aktuellen Ordner** löschen, damit der Ordner leer ist

> **Vorsicht mit `rm`:** Gelöschte Dateien landen nicht im Papierkorb, sie sind sofort weg. Prüfe vorher mit `pwd`, dass du wirklich in `/var/www/html` bist!

### Schritt 3: Repository auf den Server klonen

Kopiere auf GitHub die **HTTPS**-Adresse deines Repositories (hier ausnahmsweise nicht SSH, weil auf dem Server kein GitHub-Schlüssel hinterlegt ist):

```bash
git clone https://github.com/<dein-benutzername>/meine-webseite.git .
```

Der **Punkt** am Ende ist wichtig: Er bedeutet „in den aktuellen Ordner klonen“ – sonst würde ein Unterordner `meine-webseite` entstehen.

Browser neu laden – jetzt ist deine Seite aus GitHub online.

### Schritt 4: Änderung veröffentlichen

1. **Lokal** in VS Code die `index.html` ändern, committen und pushen
2. **Auf dem Server**:

```bash
cd /var/www/html
git pull
```

3. Browser neu laden – die Änderung ist live 🚀

Genau so (nur automatisiert) funktioniert das Veröffentlichen (_Deployment_) von Webseiten in echten Projekten.

---

## Aufräumen: Instanz stoppen oder beenden

Eine laufende Instanz kann **Kosten verursachen**. Deshalb nach dem Kurs unbedingt aufräumen!

In der EC2-Übersicht die Instanz auswählen → **Instance state**:

| Aktion                          | Was passiert?                                                                                              | Wann sinnvoll?                |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------- | ----------------------------- |
| **Stop instance**               | Server wird ausgeschaltet, Daten bleiben erhalten. **Die öffentliche IP ändert sich beim nächsten Start!** | Du willst später weitermachen |
| **Terminate (delete) instance** | Server wird **endgültig gelöscht** – inklusive aller Dateien                                               | Du bist fertig                |

## Fehlerbehebung

| Fehlermeldung / Problem                            | Mögliche Ursache und Lösung                                                                                                           |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `WARNING: UNPROTECTED PRIVATE KEY FILE!`           | Dateirechte zu offen → `chmod 400 ~/.ssh/ec2-kurs-key.pem`                                                                            |
| `Permission denied (publickey)`                    | Falscher Benutzername (muss `ubuntu` sein) oder falscher Schlüssel bei `-i`                                                           |
| `No such file or directory` beim `cp` oder `ssh`   | Pfad oder Dateiname falsch → mit `ls` prüfen, wo die Datei wirklich liegt                                                             |
| `Connection timed out` bei SSH                     | Deine IP hat sich geändert (z. B. anderes WLAN) → in der **Security Group** die SSH-Regel wieder auf **My IP** setzen                 |
| Instanz hat keine **Public IPv4 address**          | **Auto-assign public IP** war aus → Instanz beenden und mit **Enable** neu erstellen                                                  |
| `Connection timed out` bei SSH **und** im Browser  | Instanz liegt im **privaten Subnetz** oder das VPC hat kein **Internet Gateway** / keine Route `0.0.0.0/0` → VPC-Einstellungen prüfen |
| Browser lädt ewig                                  | `https://` statt `http://` verwendet **oder** die HTTP-Regel (Port 80, Source `0.0.0.0/0`) fehlt in der Security Group                |
| Seite ging gestern noch, heute nicht               | Instanz wurde gestoppt und neu gestartet → **neue öffentliche IP** in der Konsole nachschauen                                         |
| Immer noch „Welcome to nginx!“ nach dem Bearbeiten | Datei heißt nicht genau `index.html` oder liegt nicht in `/var/www/html` → mit `ls /var/www/html` prüfen; `Strg + F5` im Browser      |
| `Permission denied` beim Speichern in `nano`       | `sudo` vor `nano` vergessen                                                                                                           |

## Kontrollfragen

- Was ist der Unterschied zwischen einem physischen Server und einer EC2-Instanz?
- Wofür brauchst du Port `22` und wofür Port `80`?
- Warum muss die Instanz in einem **öffentlichen** Subnetz liegen? Was macht ein Subnetz „öffentlich“?
- Was macht die **Security Group** – und warum öffnen wir SSH nur für **My IP**?
- Warum musst du `chmod 400` auf den Schlüssel anwenden?
- Woran erkennst du im Terminal, ob du gerade auf deinem Laptop oder auf dem Server arbeitest?
- Was ist die Aufgabe von nginx?
- Warum brauchst du `sudo`, um Dateien in `/var/www/html` zu bearbeiten?
- Was ist der Unterschied zwischen **Stop** und **Terminate**?
- Warum ist deine Webseite nach einem Stopp und Neustart der Instanz unter einer anderen Adresse erreichbar?
