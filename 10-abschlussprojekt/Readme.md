# Kapitel 10: Abschlussprojekt – Alles zusammen

In den letzten Kapiteln hast du viele Werkzeuge **einzeln** kennengelernt: Git und Pull Requests, Docker, Terraform und GitHub Actions. In der Praxis arbeiten diese Werkzeuge aber immer **zusammen**. In diesem Kapitel wiederholst du alles Gelernte und baust daraus **ein komplettes Projekt**:

> Eine kleine Web-App wird bei jedem **Merge Request** automatisch getestet. Nach dem Mergen baut die Pipeline ein **Docker-Image**, schiebt es in eine **private Registry (ECR)**, die **Terraform** angelegt hat, und startet es auf einer **EC2-Instanz** – erreichbar im Browser auf **Port 80**. Als **Zusatzaufgabe** ziehst du die App danach auf **AWS Fargate** um – ganz ohne eigenen Server.

| Thema                       | Was du wiederholst                                          | Kapitel                                                                                         |
| --------------------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| **Git & Merge Requests**    | Branches, Commits, Pull Requests, Merge-Konflikte           | [02](../02-git-getting-started/), [03](../03-github-getting-started/), [04](../04-merge-conflicts/) |
| **Docker**                  | Dockerfile, Image, Container, Ports, Registry               | [06](../06-containerisierung/)                                                                  |
| **IaC mit Terraform**       | Provider, Ressourcen, Variablen, Outputs, Remote State      | [08](../08-terraform/)                                                                          |
| **CI/CD mit GitHub Actions** | Workflows, Jobs, Secrets, Branch-Schutz, Deployment         | [09](../09-ci-cd/)                                                                              |

## Das Zielbild

```
  Du (Laptop)                       GitHub                                              AWS (us-east-1)
 ┌───────────────┐   git push   ┌────────────────────────────────────────┐
 │ feature/xyz   │─────────────▶│ Pull Request ──▶ ci.yml                │
 │  app/         │              │   • App-Tests (node --test)            │
 │  infra/       │              │   • Docker-Image bauen + ausprobieren  │
 │  .github/     │              │   • terraform fmt / validate / plan    │
 └───────────────┘              │                                        │
                                │ Merge nach main ──▶ cd.yml             │
                                │   1. terraform apply ───────────────────────────▶ ┌──────────────────────────┐
                                │                                        │          │ VPC · Subnetz · IGW      │
                                │                                        │          │ ECR-Repository           │
                                │   2. docker build + docker push ───────────────▶  │   └ anna-webapp:<sha>    │
                                │                                        │          │ EC2-Instanz (Docker)     │
                                │   3. Deploy über SSM ──────────────────────────▶  │   └ Container :3000      │
                                │      "docker pull + docker run"        │          │      ▲ Port 80           │
                                └────────────────────────────────────────┘          └──────┼───────────────────┘
                                                                                           │
                                                          Browser: http://<public-ip> ─────┘
```

---

## Wiederholung: Die Bausteine

### 1. Git: Branches, Commits und Merge Requests

**Git** speichert die Geschichte deines Projekts als Folge von **Commits**. Ein **Branch** ist ein beweglicher Zeiger auf einen Commit – damit kannst du an einer Änderung arbeiten, ohne `main` zu stören.

| Befehl                                | Bedeutung                                                         |
| ------------------------------------- | ----------------------------------------------------------------- |
| `git clone <url>`                     | Repository auf den Laptop holen                                   |
| `git switch -c feature/xyz`           | Neuen Branch anlegen und dorthin wechseln                         |
| `git status` / `git diff`             | Was hat sich geändert?                                            |
| `git add <datei>`                     | Änderung für den nächsten Commit vormerken (Staging)              |
| `git commit -m "..."`                 | Vorgemerkte Änderungen als Commit speichern                       |
| `git push -u origin feature/xyz`      | Branch zu GitHub hochladen                                        |
| `git switch main && git pull`         | Zurück auf `main` und den neuesten Stand holen                    |

#### Merge Request = Pull Request

Ein **Merge Request** (so heißt es bei **GitLab**) und ein **Pull Request** (so heißt es bei **GitHub**) sind **dasselbe**: eine Anfrage „Bitte übernimm meinen Branch nach `main`“. Im Merge Request passiert:

1. **Die Pipeline prüft** die Änderung automatisch (Tests, Build, `terraform plan`)
2. **Ein Mensch macht ein Review** und kommentiert oder genehmigt
3. Erst dann wird **gemergt** – und bei uns startet damit das **Deployment**

```
  feature/neue-farbe ──●──●──┐  Merge Request (PR)
                             │  ✔ CI grün  ✔ Review
  main ──●───────────────────●(Merge) ──▶ cd.yml rollt aus
```

#### Merge-Konflikte

Ändern zwei Branches **dieselbe Zeile**, kann Git nicht entscheiden, welche Version gilt. Es markiert die Stelle in der Datei:

```
<<<<<<< HEAD
    <h1>Hallo aus dem Abschlussprojekt! 🚀</h1>
=======
    <h1>Willkommen im Abschlussprojekt!</h1>
>>>>>>> feature/ueberschrift
```

Du entscheidest dich (oder kombinierst), löschst die Markierungen, und schließt mit `git add` + `git commit` ab.

### 2. Docker: Image, Container, Registry

| Begriff        | Bedeutung                                                                     | Vergleich                       |
| -------------- | ----------------------------------------------------------------------------- | ------------------------------- |
| **Dockerfile** | Bauanleitung: Basis-Image, Dateien kopieren, Startbefehl                      | Rezept                          |
| **Image**      | Das fertig gebaute, unveränderliche Paket aus App + Laufzeitumgebung          | Fertiger Kuchen im Kühlschrank  |
| **Container**  | Ein **laufendes** Image – davon kann es viele gleichzeitig geben              | Ein Stück Kuchen auf dem Teller |
| **Registry**   | Speicher für Images, aus dem jeder Server sie ziehen kann (Docker Hub, **ECR**) | Bäckerei-Lager                 |
| **Tag**        | Name einer Image-Version, z. B. `:latest` oder `:3f2a9c1`                     | Etikett mit Datum               |

**Ports:** Ein Container hat sein **eigenes** Netzwerk. Mit `-p HOST:CONTAINER` öffnest du eine Tür vom Host in den Container:

```
  Browser ──▶ http://localhost:8080 ──▶ Host-Port 8080 ──(-p 8080:3000)──▶ Container-Port 3000 (node server.js)
```

| Befehl                                                 | Bedeutung                                         |
| ------------------------------------------------------ | ------------------------------------------------- |
| `docker build -t name:tag ordner`                      | Image aus dem Dockerfile in `ordner` bauen        |
| `docker run -d --name web -p 8080:3000 name:tag`       | Container im Hintergrund starten                  |
| `docker ps` / `docker logs web`                        | Laufende Container / Ausgaben ansehen             |
| `docker rm -f web`                                     | Container stoppen und löschen                     |
| `docker push name:tag` / `docker pull name:tag`        | Image in die Registry hoch- bzw. herunterladen    |

### 3. Terraform: Infrastruktur als Code (IaC)

**Infrastructure as Code** heißt: Deine Server, Netzwerke und Berechtigungen stehen als **Text** im Repository – versioniert, reviewbar und jederzeit reproduzierbar.

| Baustein                 | Bedeutung                                                                 |
| ------------------------ | ------------------------------------------------------------------------- |
| `provider`               | Mit welcher Cloud spricht Terraform? (`aws`, Region `us-east-1`)         |
| `resource`               | Etwas, das Terraform **anlegt** und verwaltet (`aws_instance`, …)        |
| `data`                   | Etwas, das Terraform nur **nachschlägt** (z. B. die neueste AMI)         |
| `variable`               | Eingabewert (`var.vorname`) – z. B. per `TF_VAR_vorname` gesetzt         |
| `output`                 | Ausgabewert nach dem Apply (z. B. IP-Adresse, ECR-URL)                    |
| **State**                | Terraforms Gedächtnis: Was existiert bereits?                             |
| **Backend `s3`**         | Der State liegt im S3-Bucket statt auf deinem Laptop – nötig für Pipelines |

Der Ablauf ist immer: `terraform init` → `terraform plan` → `terraform apply` (→ `terraform destroy`).

### 4. GitHub Actions: CI/CD

| Begriff               | Bedeutung                                                                        |
| --------------------- | -------------------------------------------------------------------------------- |
| **Workflow**          | YAML-Datei unter `.github/workflows/` im **Hauptordner** des Repositorys         |
| **Trigger** (`on:`)   | Wann läuft der Workflow? (`pull_request`, `push`, `workflow_dispatch`)           |
| **Job**               | Läuft auf einer eigenen, frischen VM (`runs-on: ubuntu-latest`)                  |
| **Step**              | Einzelner Befehl (`run:`) oder fertige Action (`uses:`)                          |
| `needs:`              | Reihenfolge: Job B wartet auf Job A                                              |
| Job-`outputs:`        | Werte von einem Job an einen späteren Job weitergeben                            |
| `secrets.NAME`        | Geheime Werte (Access Keys) – werden im Log als `***` angezeigt                  |
| `vars.NAME`           | Nicht geheime Einstellungen (dein Vorname)                                       |

**CI** = jede Änderung wird automatisch geprüft (bei uns: im Pull Request). **CD** = jede geprüfte Änderung wird automatisch ausgeliefert (bei uns: nach dem Merge auf `main`).

### Neu in diesem Kapitel

| Begriff                         | Bedeutung                                                                                                                                                       |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ECR** (Elastic Container Registry) | Die private Docker-Registry von AWS. Ein **Repository** pro App, z. B. `123456789012.dkr.ecr.us-east-1.amazonaws.com/anna-webapp`                               |
| **IAM-Rolle**                   | Berechtigungen für einen **AWS-Dienst** statt für einen Menschen. Unsere EC2-Instanz bekommt eine Rolle, damit sie Images aus ECR ziehen darf – **ohne** Access Key auf dem Server |
| **Instance Profile**            | Der „Halter“, über den eine IAM-Rolle an eine EC2-Instanz gehängt wird                                                                                           |
| **SSM** (Systems Manager) **Run Command** | Damit schickt die Pipeline Befehle an die Instanz – **ohne SSH**, ohne offenen Port 22, ohne privaten Schlüssel in GitHub                                     |
| **`user_data`**                 | Ein Skript, das beim **ersten Start** der Instanz als `root` läuft – bei uns: Docker installieren                                                                 |

> **Warum ECR und nicht Docker Hub?** Das Image liegt im selben AWS-Konto wie der Server. Zugriff wird über IAM geregelt, es gibt keine Download-Limits und das Image ist **privat**.

> **Hinweis zum Namen:** **ECR** ist die Registry (das „Lager“ für Images). **ECS** (Elastic Container Service) ist der Dienst, der Container **ausführt** – den brauchst du erst in der Zusatzaufgabe mit Fargate.

---

## Voraussetzungen

- Ein GitHub-Account und Git auf deinem Laptop (Kapitel 02/03)
- Docker auf deinem Laptop (Kapitel 06)
- Terraform auf deinem Laptop (Kapitel 08) – nur für `fmt` und `validate`, **nicht** für `apply`
- Der **S3-Bucket** für den Terraform-State aus Kapitel 08
- Der **IAM-Benutzer `terraform`** mit Access Key aus Kapitel 08/09

## Überblick: Was machst du?

| Aufgabe                                                        | Thema          | Ergebnis                                                         |
| -------------------------------------------------------------- | -------------- | ---------------------------------------------------------------- |
| [0](#aufgabe-0-vorbereitung)                                   | AWS / GitHub   | Rechte, Repository, Secrets und Variables                        |
| [1](#aufgabe-1-git--der-erste-merge-request)                   | Git            | Der erste Merge Request mit Branch, Commit und Review            |
| [2](#aufgabe-2-docker--die-web-app-containerisieren)           | Docker         | Die Web-App läuft lokal im Container                             |
| [3](#aufgabe-3-terraform--die-infrastruktur-beschreiben)       | Terraform      | ECR, IAM-Rolle, EC2 mit Docker – als Code                        |
| [4](#aufgabe-4-ci--die-pull-request-pipeline)                  | GitHub Actions | Jeder Merge Request wird geprüft, `main` ist geschützt           |
| [5](#aufgabe-5-cd-teil-1--infrastruktur-ausrollen-und-image-nach-ecr-pushen) | GitHub Actions + Docker | `terraform apply`, `docker build` und `docker push` nach ECR |
| [6](#aufgabe-6-cd-teil-2--das-image-auf-ec2-veröffentlichen)   | GitHub Actions + AWS | Die App läuft auf EC2 unter `http://<ip>`                  |
| [7](#aufgabe-7-der-komplette-kreislauf--und-ein-merge-konflikt) | Alles          | Eine Änderung vom Branch bis in Produktion + Merge-Konflikt      |
| [8](#aufgabe-8-aufräumen)                                      | Terraform      | Alles wieder gelöscht                                            |
| [Zusatz](#zusatzaufgabe-fargate-statt-ec2)                     | ECS / Fargate  | Dieselbe App ohne eigenen Server                                 |

Am Ende sieht dein Repository so aus:

```
abschlussprojekt/
├── .github/
│   └── workflows/
│       ├── ci.yml          # Aufgabe 4: läuft bei jedem Pull Request
│       ├── cd.yml          # Aufgabe 5 + 6: läuft nach dem Merge auf main
│       └── destroy.yml     # Aufgabe 8: alles löschen per Knopfdruck
├── app/
│   ├── server.js           # Aufgabe 2: die Web-App
│   ├── server.test.js
│   ├── package.json
│   ├── Dockerfile
│   └── .dockerignore
├── infra/
│   ├── providers.tf        # Aufgabe 3: Terraform
│   ├── variables.tf
│   ├── vpc.tf
│   ├── ecr.tf
│   ├── iam.tf
│   ├── ec2.tf
│   ├── outputs.tf
│   └── .gitignore
├── .gitignore
└── README.md
```

> Die fertigen Dateien findest du in [loesung/](./loesung/) (Endstand nach Aufgabe 8) und [zusatz-fargate/](./zusatz-fargate/) (Endstand nach der Zusatzaufgabe). **Versuche es zuerst selbst** – schau nur nach, wenn du festhängst.

---

## Aufgabe 0: Vorbereitung

### Schritt 1: Rechte für den IAM-Benutzer `terraform` erweitern

Terraform legt diesmal mehr an als in Kapitel 08: ein ECR-Repository, eine IAM-Rolle und (in der Zusatzaufgabe) einen ECS-Cluster. Außerdem nutzt die Pipeline denselben Benutzer, um Images zu pushen und Befehle per SSM zu verschicken.

Gehe in der AWS-Konsole zu **IAM** → **Users** → `terraform` → **Add permissions** → **Attach policies directly** und stelle sicher, dass diese Policies angehängt sind:

| Policy                                   | Wofür?                                                     |
| ---------------------------------------- | ---------------------------------------------------------- |
| `AmazonEC2FullAccess`                    | VPC, Subnetz, Security Group, EC2-Instanz                  |
| `AmazonS3FullAccess`                     | Terraform-State im S3-Bucket                               |
| `AmazonEC2ContainerRegistryFullAccess`   | ECR-Repository anlegen, Images pushen                      |
| `IAMFullAccess`                          | IAM-Rolle und Instance Profile für die EC2-Instanz anlegen |
| `AmazonSSMFullAccess`                    | Befehle per SSM Run Command an die Instanz schicken        |
| `AmazonECS_FullAccess`                   | Nur für die Zusatzaufgabe (Fargate)                        |
| `CloudWatchLogsFullAccess`               | Nur für die Zusatzaufgabe (Container-Logs)                 |

> **Für die Profis:** `IAMFullAccess` ist sehr mächtig – damit könnte sich der Benutzer selbst zum Administrator machen. In echten Projekten schränkt man das stark ein (z. B. nur Rollen mit dem Präfix `anna-` erlauben). Für den Kurs ist es in Ordnung.

### Schritt 2: Das Repository anlegen

1. Lege auf GitHub ein neues, **öffentliches** oder privates Repository `abschlussprojekt` an – **mit** README
2. Klone es auf deinen Laptop:

```bash
git clone git@github.com:<dein-benutzername>/abschlussprojekt.git
cd abschlussprojekt
```

### Schritt 3: Secrets und Variables hinterlegen

Im Repository unter **Settings** → **Secrets and variables** → **Actions**:

| Reiter        | Name                    | Wert                                                       |
| ------------- | ----------------------- | ---------------------------------------------------------- |
| **Secrets**   | `AWS_ACCESS_KEY_ID`     | Access Key ID des IAM-Benutzers `terraform`                |
| **Secrets**   | `AWS_SECRET_ACCESS_KEY` | Secret Access Key des IAM-Benutzers `terraform`            |
| **Variables** | `VORNAME`               | Dein Vorname in **Kleinbuchstaben**, z. B. `anna`          |

<details>
<summary>❓ Warum ist der Vorname eine <b>Variable</b> und kein <b>Secret</b>?</summary>

Der Vorname ist nicht geheim. Secrets werden im Log durch `***` ersetzt – das würde uns beim Lesen der Logs nur stören (z. B. bei der ECR-URL `…/anna-webapp`). Faustregel: **Nur echte Geheimnisse** in Secrets.

</details>

<details>
<summary>❓ Warum Kleinbuchstaben?</summary>

Der Name des ECR-Repositorys wird aus deinem Vornamen gebaut (`anna-webapp`) – und ECR erlaubt nur Kleinbuchstaben, Ziffern, `-`, `_`, `.` und `/`.

</details>

---

## Aufgabe 1: Git – der erste Merge Request

Ab jetzt gilt für **jede** Aufgabe: **Neuer Branch → Commits → Push → Pull Request → Merge.** Niemals direkt auf `main` arbeiten.

### Schritt 1: Branch anlegen

```bash
git switch -c feature/readme
```

### Schritt 2: README anpassen

Schreibe in die `README.md` ein paar Zeilen über das Projekt, z. B.:

```markdown
# Abschlussprojekt

Eine Web-App, die automatisch getestet, als Docker-Image nach AWS ECR gepusht
und auf einer EC2-Instanz veröffentlicht wird.

- `app/` – die Web-App (Node.js) und ihr Dockerfile
- `infra/` – die Infrastruktur (Terraform)
- `.github/workflows/` – die Pipelines (GitHub Actions)
```

Lege außerdem im Hauptordner eine `.gitignore` an:

```gitignore
# Node.js
node_modules/

# macOS
.DS_Store
```

### Schritt 3: Commit und Push

```bash
git status
git add README.md .gitignore
git commit -m "README und .gitignore anlegen"
git push -u origin feature/readme
```

### Schritt 4: Den Merge Request (Pull Request) erstellen und mergen

1. Auf GitHub erscheint ein gelber Hinweis **Compare & pull request** – klicke darauf
2. Gib einen aussagekräftigen Titel und eine kurze Beschreibung ein → **Create pull request**
3. Schau dir den Reiter **Files changed** an – das ist die Ansicht für das Review
4. **Merge pull request** → **Confirm merge** → **Delete branch**
5. Lokal aufräumen:

```bash
git switch main
git pull
git branch -d feature/readme
```

<details>
<summary>❓ Was ist der Unterschied zwischen <code>git fetch</code> und <code>git pull</code>?</summary>

`git fetch` lädt nur die neuen Commits von GitHub herunter, verändert aber deinen Branch nicht. `git pull` = `git fetch` + `git merge` – dein lokaler Branch wird auf den neuen Stand gebracht.

</details>

---

## Aufgabe 2: Docker – die Web-App containerisieren

```bash
git switch -c feature/webapp
mkdir app
```

### Schritt 1: Die Web-App

Lege die Dateien aus [loesung/app/](./loesung/app/) an:

| Datei                                                 | Inhalt                                                                         |
| ----------------------------------------------------- | ------------------------------------------------------------------------------ |
| [server.js](./loesung/app/server.js)                  | Ein kleiner Webserver ohne Abhängigkeiten. `/` liefert HTML, `/health` liefert JSON |
| [server.test.js](./loesung/app/server.test.js)        | Drei Unit-Tests mit dem eingebauten Test-Runner von Node.js                    |
| [package.json](./loesung/app/package.json)            | Projektbeschreibung, `npm test` startet die Tests                              |

Lies dir `server.js` durch. Die App liest drei **Umgebungsvariablen**:

| Variable      | Standard | Wird gesetzt …                                  |
| ------------- | -------- | ----------------------------------------------- |
| `PORT`        | `3000`   | (bleibt bei uns immer 3000)                     |
| `APP_VERSION` | `dev`    | beim **Bauen** des Images (`--build-arg`)       |
| `PLATTFORM`   | `lokal`  | beim **Starten** des Containers (`-e`)          |

Falls du Node.js installiert hast, kannst du die Tests direkt ausführen:

```bash
cd app
npm test
cd ..
```

### Schritt 2: Das Dockerfile

Schreibe selbst ein `app/Dockerfile`. Anforderungen:

- Basis-Image `node:22-alpine`
- Arbeitsverzeichnis `/app`
- Nur `package.json` und `server.js` kopieren (keine Tests)
- Ein Build-Argument `APP_VERSION` (Standard `dev`), das als Umgebungsvariable `APP_VERSION` im Image landet
- Der Container läuft **nicht** als `root`, sondern als Benutzer `node`
- Port `3000` dokumentieren, Startbefehl `node server.js`

<details>
<summary>💡 Lösung anzeigen</summary>

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY package.json server.js ./
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "server.js"]
```

Und eine `app/.dockerignore`:

```
node_modules
*.test.js
Dockerfile
.dockerignore
```

</details>

### Schritt 3: Bauen und starten

```bash
docker build --build-arg APP_VERSION=lokal-1 -t webapp:lokal app
docker run -d --name webapp -p 8080:3000 -e PLATTFORM=Laptop webapp:lokal
```

Öffne <http://localhost:8080> und <http://localhost:8080/health>. Probiere dann:

```bash
docker ps
docker logs webapp
curl http://localhost:8080/health
docker rm -f webapp
```

<details>
<summary>❓ Was zeigt die Zeile „Container (Hostname)“ auf der Webseite – und warum?</summary>

Die **Container-ID** (die ersten 12 Zeichen). Jeder Container bekommt seinen eigenen Hostnamen. Startest du einen neuen Container, ändert sich der Wert – daran erkennst du später, dass die Pipeline wirklich einen **neuen** Container gestartet hat.

</details>

<details>
<summary>❓ Was passiert bei <code>-p 8080:80</code> statt <code>-p 8080:3000</code>?</summary>

Die Seite ist nicht erreichbar: Docker leitet Port 8080 auf Port **80 im Container** weiter – dort lauscht aber niemand, die App lauscht auf **3000**. Merke: **`-p HOST:CONTAINER`** – rechts steht immer der Port, auf dem die App **im** Container lauscht.

</details>

<details>
<summary>❓ Warum ist <code>ARG APP_VERSION</code> erst <b>nach</b> dem <code>COPY</code>?</summary>

Wegen des **Layer-Caches**: Docker baut jede Zeile als Layer und verwendet ihn wieder, solange sich nichts geändert hat. Die Version ändert sich bei **jedem** Commit. Stünde `ARG` ganz oben, müssten alle Layer danach jedes Mal neu gebaut werden.

</details>

### Schritt 4: Merge Request

```bash
git add app
git commit -m "Web-App mit Dockerfile"
git push -u origin feature/webapp
```

Erstelle den Pull Request und merge ihn (noch gibt es keine Pipeline – das ändern wir in Aufgabe 4).

---

## Aufgabe 3: Terraform – die Infrastruktur beschreiben

```bash
git switch main && git pull
git switch -c feature/infrastruktur
mkdir infra
```

### Schritt 1: Bekanntes aus Kapitel 08 übernehmen

Kopiere aus [08-terraform/beispiel-1](../08-terraform/beispiel-1/) nach `infra/`:

- `vpc.tf` – **unverändert**
- `.gitignore` – **unverändert** (Achtung: `terraform.tfstate` und `*.tfvars` dürfen nie ins Repository!)
- `providers.tf` – mit **einkommentiertem** `backend "s3"` und deinem Bucket-Namen. Ändere den `key`:

```hcl
  backend "s3" {
    bucket       = "terraform-state-DEIN-NAME-12345"   # dein Bucket aus Kapitel 08
    key          = "abschlussprojekt/terraform.tfstate" # NEUER Pfad!
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
```

<details>
<summary>❓ Warum ein neuer <code>key</code>?</summary>

Der `key` ist der Dateiname des States im Bucket. Mit dem alten Key würde Terraform glauben, die Infrastruktur aus Kapitel 08/09 gehöre zu diesem Projekt – und sie beim nächsten `apply` **löschen**, weil sie hier nicht im Code steht.

</details>

- `variables.tf` – `vorname` und `instance_type` behalten, `key_name` **löschen** (wir brauchen kein SSH). Neu dazu:

```hcl
variable "container_port" {
  description = "Port, auf dem die App IM Container lauscht"
  type        = number
  default     = 3000
}

variable "host_port" {
  description = "Port, unter dem die App auf der EC2-Instanz erreichbar ist"
  type        = number
  default     = 80
}
```

### Schritt 2: Das ECR-Repository (`infra/ecr.tf`)

Lege ein ECR-Repository mit dem Namen `<vorname>-webapp` an. Schlage in der [Terraform-Dokumentation zu `aws_ecr_repository`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) nach und setze:

- `image_tag_mutability = "MUTABLE"` – damit der Tag `latest` immer auf das neueste Image zeigen darf
- `force_delete = true` – sonst schlägt `terraform destroy` fehl, solange noch Images im Repository liegen
- `scan_on_push = true` – jedes Image wird automatisch auf Sicherheitslücken geprüft

<details>
<summary>💡 Lösung anzeigen</summary>

```hcl
resource "aws_ecr_repository" "app" {
  name                 = "${var.vorname}-webapp"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.vorname}-webapp"
  }
}
```

In [loesung/infra/ecr.tf](./loesung/infra/ecr.tf) findest du zusätzlich eine **Lifecycle Policy**, die nur die letzten 10 Images behält.

</details>

### Schritt 3: Die IAM-Rolle für die Instanz (`infra/iam.tf`)

Die EC2-Instanz muss zwei Dinge dürfen: **Images aus ECR ziehen** und **Befehle über SSM empfangen**. Dafür bekommt sie eine **Rolle**:

```
  aws_iam_role "ec2"  ◀── "Wer darf die Rolle annehmen?"  → der Dienst ec2.amazonaws.com
     ├── Policy: AmazonEC2ContainerRegistryReadOnly       → docker pull aus ECR
     ├── Policy: AmazonSSMManagedInstanceCore             → Befehle per SSM empfangen
     └── aws_iam_instance_profile "ec2"                   → hängt die Rolle an die Instanz
```

Übernimm [loesung/infra/iam.tf](./loesung/infra/iam.tf) und lies die Kommentare.

<details>
<summary>❓ Warum bekommt die Instanz keinen Access Key wie der Benutzer <code>terraform</code>?</summary>

Ein Access Key ist ein **dauerhaftes** Geheimnis. Läge er auf dem Server, könnte ihn jeder auslesen, der Zugriff auf den Server hat – und er wäre gültig, bis ihn jemand manuell löscht. Eine **Rolle** liefert dagegen **kurzlebige** Zugangsdaten, die AWS automatisch alle paar Stunden erneuert. Auf dem Server liegt nichts Geheimes.

</details>

### Schritt 4: Die EC2-Instanz mit Docker (`infra/ec2.tf`)

Nimm `ec2.tf` aus Kapitel 08 als Grundlage und ändere:

| Was                       | Kapitel 08                         | Jetzt                                                       |
| ------------------------- | ---------------------------------- | ----------------------------------------------------------- |
| Security Group: Name      | `terraform-kurs-sg`                | `${var.vorname}-webapp-sg`                                  |
| Eingehende Regel          | Port 22 (SSH)                      | `var.host_port` (80, HTTP) – **kein** SSH mehr              |
| AMI                       | Ubuntu 24.04                       | **Amazon Linux 2023** – AWS CLI und SSM-Agent sind schon drin |
| `key_name`                | Schlüsselpaar                      | **entfernen**                                               |
| `iam_instance_profile`    | –                                  | `aws_iam_instance_profile.ec2.name`                         |
| `user_data`               | –                                  | Skript, das Docker installiert                              |

Die AMI für Amazon Linux 2023:

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
```

Das `user_data`-Skript läuft **einmalig** beim ersten Start als `root`:

```hcl
  user_data = <<-SKRIPT
    #!/bin/bash
    set -eux
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user
  SKRIPT

  user_data_replace_on_change = true
```

<details>
<summary>💡 Komplette Lösung</summary>

Siehe [loesung/infra/ec2.tf](./loesung/infra/ec2.tf).

</details>

### Schritt 5: Outputs (`infra/outputs.tf`)

Die Pipeline braucht nach dem `apply` drei Werte. Lege diese Outputs an:

| Output               | Wert                                                    | Wofür?                         |
| -------------------- | ------------------------------------------------------- | ------------------------------ |
| `ecr_repository_url` | `aws_ecr_repository.app.repository_url`                 | Wohin wird das Image gepusht?  |
| `instance_id`        | `aws_instance.server.id`                                | An welche Instanz geht SSM?    |
| `webapp_url`         | `"http://${aws_instance.server.public_ip}:${var.host_port}"` | Smoke-Test und Browser     |

### Schritt 6: Lokal prüfen – ohne AWS-Zugangsdaten

Du brauchst für diese Prüfungen **keine** Zugangsdaten. `-backend=false` sorgt dafür, dass Terraform nicht mit dem S3-Bucket spricht:

```bash
cd infra
terraform fmt
terraform init -backend=false
terraform validate
cd ..
```

> **Kein `terraform apply` auf dem Laptop!** Ab jetzt rollt **nur** die Pipeline aus.

### Schritt 7: Commit und Push – aber noch nicht mergen

```bash
git status            # Taucht .terraform/ auf? Dann stimmt die .gitignore nicht!
git add infra
git commit -m "Infrastruktur: ECR, IAM-Rolle, EC2 mit Docker"
git push -u origin feature/infrastruktur
```

Erstelle den Pull Request, aber **merge ihn noch nicht** – in Aufgabe 4 bekommt er erst eine Pipeline.

<details>
<summary>❓ Gehört <code>.terraform.lock.hcl</code> ins Repository?</summary>

**Ja!** Die Lock-Datei legt die genaue Provider-Version fest. So nutzen dein Laptop und die Pipeline garantiert **dieselbe** Version. Der Ordner `.terraform/` dagegen gehört **nicht** hinein (er wird mit `terraform init` neu heruntergeladen).

</details>

---

## Aufgabe 4: CI – die Pull-Request-Pipeline

Bleib auf dem Branch `feature/infrastruktur`.

### Schritt 1: Der CI-Workflow

Lege `.github/workflows/ci.yml` an. Der Workflow soll bei jedem **Pull Request nach `main`** drei Jobs ausführen:

```
  app-test ──▶ docker-test          terraform-plan
  (npm test)   (bauen, starten,     (fmt -check, init,
                curl /health)        validate, plan)
```

Anforderungen:

- **Workflow-Ebene `env:`**: die beiden AWS-Secrets, `AWS_REGION: us-east-1`, `TF_VAR_vorname` aus der Variable `VORNAME`, `TF_IN_AUTOMATION: "true"`
- **`app-test`**: Node.js 22 mit `actions/setup-node@v4`, dann `npm test` im Ordner `app`
- **`docker-test`** (`needs: app-test`): Image bauen, Container mit `-p 8080:3000` starten, mit `curl` prüfen, dass `/health` antwortet. Am Ende **immer** (`if: always()`) aufräumen
- **`terraform-plan`**: im Ordner `infra` – `terraform fmt -check`, `init`, `validate`, `plan`. Den Plan in die Job-Zusammenfassung (`$GITHUB_STEP_SUMMARY`) schreiben

> **Tipp:** Mit `defaults.run.working-directory` legst du für einen Job fest, in welchem Ordner alle `run:`-Befehle laufen.

<details>
<summary>💡 Lösung anzeigen</summary>

Siehe [loesung/.github/workflows/ci.yml](./loesung/.github/workflows/ci.yml).

</details>

### Schritt 2: Pushen und den Pull Request beobachten

```bash
git add .github
git commit -m "CI-Pipeline für Pull Requests"
git push
```

Öffne deinen Pull Request → unten erscheinen drei Checks. Wenn sie grün sind: Klicke beim Check **Terraform Plan** auf **Details** → **Summary**. Dort steht, was Terraform anlegen **würde**.

<details>
<summary>❓ Wie viele Ressourcen will Terraform anlegen?</summary>

**15** (`Plan: 15 to add, 0 to change, 0 to destroy`): VPC, Internet Gateway, Subnetz, Route Table, Association (5) + ECR-Repository, Lifecycle Policy (2) + IAM-Rolle, 2 Policy-Attachments, Instance Profile (4) + Security Group, 2 Regeln, EC2-Instanz (4). Ohne Lifecycle Policy sind es 14. Data Sources (`aws_ami`, `aws_iam_policy_document`) zählen nicht – sie legen nichts an.

</details>

### Schritt 3: Absichtlich etwas kaputt machen

Ändere in `app/server.js` die Überschrift von `<h1>` auf `<h2>` (öffnendes und schließendes Tag). Committe und pushe.

- Welcher Job wird rot? Welcher läuft gar nicht erst?
- Mache die Änderung danach wieder rückgängig, committe und pushe erneut.

<details>
<summary>❓ Lösung</summary>

`app-test` wird rot (der Test „Startseite liefert HTML mit Überschrift“ sucht nach `<h1>`). `docker-test` wird **übersprungen**, weil er mit `needs: app-test` auf einen erfolgreichen `app-test` wartet. `terraform-plan` läuft unabhängig davon weiter.

</details>

### Schritt 4: `main` schützen

Unter **Settings** → **Rules** → **Rulesets** → **New ruleset** → **New branch ruleset**:

| Einstellung                                | Wert                                                    |
| ------------------------------------------ | ------------------------------------------------------- |
| Ruleset Name                               | `main-schutz`                                           |
| Enforcement status                         | **Active**                                              |
| Target branches                            | **Add target** → **Include default branch**             |
| ✅ Restrict deletions                       |                                                         |
| ✅ Require a pull request before merging    | (Im Team: Required approvals = 1)                       |
| ✅ Require status checks to pass            | **Add checks**: `App testen`, `Docker-Image testen`, `Terraform Plan` |
| ✅ Block force pushes                       |                                                         |

Probiere aus, ob es wirkt:

```bash
git switch main
echo "test" >> README.md
git commit -am "Direkt auf main"
git push        # ❌ sollte abgelehnt werden
git reset --hard origin/main
```

### Schritt 5: Noch nicht mergen!

Der Pull Request `feature/infrastruktur` ist jetzt grün – aber **warte** mit dem Mergen bis Aufgabe 5. Sonst gibt es noch keinen Workflow, der nach dem Merge ausrollt.

---

## Aufgabe 5: CD Teil 1 – Infrastruktur ausrollen und Image nach ECR pushen

Bleib auf dem Branch `feature/infrastruktur`. Lege `.github/workflows/cd.yml` an. Er läuft bei jedem **Push auf `main`** – also nach jedem gemergten Pull Request.

```
  infrastruktur ──────────▶ build-push ──────────────────▶ deploy-ec2 (Aufgabe 6)
  terraform apply           docker build                   docker pull + run
  outputs:                  docker push → ECR              auf der Instanz
   ecr_url, instance_id,    outputs: image
   webapp_url
```

### Schritt 1: Der Job `infrastruktur`

Wie in Kapitel 09 – nur dass wir am Ende die **Terraform-Outputs** an die nächsten Jobs weitergeben:

```yaml
  infrastruktur:
    name: Terraform Apply
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: infra
    outputs:
      ecr_url: ${{ steps.werte.outputs.ecr_url }}
      instance_id: ${{ steps.werte.outputs.instance_id }}
      webapp_url: ${{ steps.werte.outputs.webapp_url }}
    steps:
      - name: Code auschecken
        uses: actions/checkout@v5

      - name: Terraform installieren
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false

      - name: Init
        run: terraform init -input=false

      - name: Apply
        run: terraform apply -input=false -auto-approve

      - name: Terraform-Outputs an die nächsten Jobs weitergeben
        id: werte
        run: |
          echo "ecr_url=$(terraform output -raw ecr_repository_url)" >> "$GITHUB_OUTPUT"
          echo "instance_id=$(terraform output -raw instance_id)"    >> "$GITHUB_OUTPUT"
          echo "webapp_url=$(terraform output -raw webapp_url)"      >> "$GITHUB_OUTPUT"
```

So kommt ein Wert von einem Step bis in einen anderen Job:

```
  Step "werte"                        Job "infrastruktur"                    Job "build-push"
  echo "ecr_url=…" >> $GITHUB_OUTPUT ─▶ outputs.ecr_url: steps.werte… ─────▶ needs.infrastruktur.outputs.ecr_url
```

<details>
<summary>❓ Warum ist <code>-auto-approve</code> hier in Ordnung?</summary>

Weil der Plan bereits im **Pull Request** geprüft wurde (Job `Terraform Plan`) und `main` geschützt ist: Es kommt nichts auf `main`, was nicht durch CI und Review gegangen ist. Wer zusätzlich eine manuelle Freigabe möchte, nutzt das **Environment `production`** aus Kapitel 09 (siehe Bonus).

</details>

### Schritt 2: Der Job `build-push`

Schreibe einen Job, der

1. `needs: infrastruktur` hat
2. die ECR-URL als Umgebungsvariable `ECR_URL` bekommt
3. sich bei ECR **anmeldet**
4. das Image mit **zwei Tags** baut: dem Commit-Hash (`${{ github.sha }}`) und `latest`
5. beide Tags **pusht**
6. den vollständigen Image-Namen mit Commit-Tag als Output `image` weitergibt

Die Anmeldung bei ECR funktioniert so – die AWS CLI erzeugt ein Passwort, das 12 Stunden gilt, und reicht es an `docker login` weiter:

```bash
REGISTRY="${ECR_URL%%/*}"     # alles vor dem ersten "/" → 123456789012.dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"
```

<details>
<summary>💡 Lösung anzeigen</summary>

```yaml
  build-push:
    name: Docker Build & Push
    runs-on: ubuntu-latest
    needs: infrastruktur
    outputs:
      image: ${{ steps.push.outputs.image }}
    env:
      ECR_URL: ${{ needs.infrastruktur.outputs.ecr_url }}
    steps:
      - name: Code auschecken
        uses: actions/checkout@v5

      - name: Bei ECR anmelden
        run: |
          REGISTRY="${ECR_URL%%/*}"
          aws ecr get-login-password --region "$AWS_REGION" \
            | docker login --username AWS --password-stdin "$REGISTRY"

      - name: Image bauen
        run: |
          docker build \
            --build-arg APP_VERSION=${{ github.sha }} \
            -t "$ECR_URL:${{ github.sha }}" \
            -t "$ECR_URL:latest" \
            app

      - name: Image pushen
        id: push
        run: |
          docker push "$ECR_URL:${{ github.sha }}"
          docker push "$ECR_URL:latest"
          echo "image=$ECR_URL:${{ github.sha }}" >> "$GITHUB_OUTPUT"
```

</details>

<details>
<summary>❓ Warum zwei Tags? Würde <code>latest</code> nicht reichen?</summary>

`latest` ist bequem, sagt aber nicht, **welche** Version das ist – und es wird bei jedem Push überschrieben. Der Commit-Hash ist **eindeutig**: Du siehst sofort, welcher Code in welchem Image steckt, und kannst jederzeit eine **ältere** Version gezielt wieder ausrollen (Rollback).

</details>

### Schritt 3: Der Rest der Datei

Ergänze oben in `cd.yml` den Trigger, `concurrency` und `env:` – wie in Kapitel 09:

```yaml
name: CD

on:
  push:
    branches:
      - main
  workflow_dispatch:

concurrency:
  group: production
  cancel-in-progress: false

env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_REGION: us-east-1
  TF_VAR_vorname: ${{ vars.VORNAME }}
  TF_IN_AUTOMATION: "true"

jobs:
  infrastruktur:
    # ... aus Schritt 1
  build-push:
    # ... aus Schritt 2
```

Den Job `deploy-ec2` ergänzt du in Aufgabe 6. Committe und pushe – und jetzt: **Merge!**

```bash
git add .github/workflows/cd.yml
git commit -m "CD: Terraform Apply und Docker Push nach ECR"
git push
```

Merge den Pull Request auf GitHub. Unter **Actions** startet der Workflow **CD**.

### Schritt 4: Nachprüfen

1. In der Pipeline: Job **Terraform Apply** – `Apply complete! Resources: 15 added`
2. In der AWS-Konsole → **ECR** → **Private registry** → **Repositories** → `<vorname>-webapp`: zwei Tags, `latest` und der Commit-Hash
3. Klicke auf das Image → **Vulnerabilities**: Was hat der Scan gefunden?
4. In der AWS-Konsole → **EC2**: Die Instanz `<vorname>-webapp-server` läuft – aber die Webseite ist **noch nicht** erreichbar. Warum?

<details>
<summary>❓ Antwort</summary>

Auf der Instanz läuft zwar Docker (dank `user_data`), aber **noch kein Container**. Das Image liegt in ECR – niemand hat der Instanz gesagt, dass sie es ziehen und starten soll. Genau das macht Aufgabe 6.

</details>

---

## Aufgabe 6: CD Teil 2 – das Image auf EC2 veröffentlichen

```bash
git switch main && git pull
git switch -c feature/deploy-ec2
```

### So funktioniert das Deployment über SSM

```
  GitHub Actions Runner                          AWS Systems Manager                 EC2-Instanz
 ┌──────────────────────────┐  send-command     ┌──────────────────┐  SSM-Agent     ┌────────────────────────────────┐
 │ aws ssm send-command     │──────────────────▶│ "Führe diese     │ holt Befehle   │ docker login (über IAM-Rolle)  │
 │   --instance-ids i-0abc  │                   │  Befehle auf     │◀───────────────│ docker pull …:<sha>            │
 │   --document-name        │  get-command-     │  i-0abc aus"     │  meldet        │ docker rm -f webapp            │
 │     AWS-RunShellScript   │◀──invocation──────│                  │  Ergebnis ────▶│ docker run -p 80:3000 …        │
 └──────────────────────────┘                   └──────────────────┘                └────────────────────────────────┘
```

Der **SSM-Agent** auf der Instanz baut die Verbindung **von innen nach außen** auf. Deshalb braucht die Instanz **keinen** offenen Port 22 und die Pipeline **keinen** SSH-Schlüssel.

### Schritt 1: Der Job `deploy-ec2`

Ergänze in `cd.yml` den dritten Job. Er braucht Werte aus **beiden** vorherigen Jobs:

```yaml
  deploy-ec2:
    name: Deploy auf EC2
    runs-on: ubuntu-latest
    needs: [infrastruktur, build-push]
    env:
      INSTANCE_ID: ${{ needs.infrastruktur.outputs.instance_id }}
      IMAGE: ${{ needs.build-push.outputs.image }}
      WEBAPP_URL: ${{ needs.infrastruktur.outputs.webapp_url }}
    steps:
      # 1. Warten, bis die Instanz bei SSM "Online" ist (nach dem ersten Start 1–3 Minuten)
      # 2. Befehle per SSM schicken und auf das Ergebnis warten
      # 3. Smoke-Test: liefert $WEBAPP_URL/health die neue Version?
```

Die drei Steps sind etwas länger – übernimm sie aus [loesung/.github/workflows/cd.yml](./loesung/.github/workflows/cd.yml) und **lies sie Zeile für Zeile**. Die Befehle, die **auf der Instanz** laufen, sind genau die, die du in Aufgabe 2 lokal getippt hast:

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <registry>
docker pull <ecr-url>:<sha>
docker rm -f webapp || true
docker run -d --name webapp --restart unless-stopped -p 80:3000 -e PLATTFORM=EC2 <ecr-url>:<sha>
```

<details>
<summary>❓ Warum braucht die Instanz für <code>docker login</code> keinen Access Key?</summary>

Die AWS CLI auf der Instanz holt sich die Zugangsdaten automatisch aus der **IAM-Rolle** (über das Instance Profile aus Aufgabe 3). Die Policy `AmazonEC2ContainerRegistryReadOnly` erlaubt genau das: anmelden und Images **ziehen** – aber nicht pushen oder löschen.

</details>

<details>
<summary>❓ Was bewirkt <code>--restart unless-stopped</code>?</summary>

Stürzt der Container ab oder wird die Instanz neu gestartet, startet Docker den Container **automatisch** wieder – außer jemand hat ihn bewusst mit `docker stop` angehalten.

</details>

<details>
<summary>❓ Wozu dient <code>cloud-init status --wait</code>?</summary>

Beim **allerersten** Deployment ist die Instanz gerade erst gestartet – evtl. installiert `user_data` noch Docker. `cloud-init status --wait` wartet, bis das Startskript fertig ist. Ohne diese Zeile würde `docker pull` mit „command not found“ fehlschlagen.

</details>

### Schritt 2: Merge Request und Deployment

```bash
git add .github/workflows/cd.yml
git commit -m "CD: Deployment auf EC2 über SSM"
git push -u origin feature/deploy-ec2
```

Pull Request erstellen → Checks grün → **mergen**. Beobachte den Workflow **CD**:

- **Terraform Apply**: `No changes.` – die Infrastruktur steht schon
- **Docker Build & Push**: neues Image mit neuem Commit-Hash
- **Deploy auf EC2**: im Log siehst du die Ausgabe von `docker ps` **auf der Instanz**

### Schritt 3: Im Browser öffnen 🎉

Öffne die URL aus der **Zusammenfassung** des Workflows (`http://<public-ip>`). Du siehst deine Web-App mit:

- **Version (Commit)** = der Commit-Hash deines Merges
- **Plattform** = `EC2`

Vergleiche den Hash mit dem letzten Commit auf `main` (`git log -1` nach `git pull`).

### Schritt 4: Auf die Instanz schauen – ohne SSH

In der AWS-Konsole → **EC2** → Instanz auswählen → **Connect** → Reiter **Session Manager** → **Connect**. Du hast eine Shell im Browser:

```bash
sudo docker ps
sudo docker logs webapp
curl localhost/health
```

Unter **Systems Manager** → **Run Command** → **Command history** siehst du außerdem jedes Deployment der Pipeline.

---

## Aufgabe 7: Der komplette Kreislauf – und ein Merge-Konflikt

Jetzt spielst du durch, wie ein Team im Alltag arbeitet: Zwei Personen ändern **gleichzeitig** dieselbe Stelle.

### Schritt 1: Zwei Branches von `main`

```bash
git switch main && git pull
git switch -c feature/ueberschrift-a
```

Ändere in `app/server.js` die Überschrift auf `<h1>Willkommen im Abschlussprojekt! 👋</h1>`.

```bash
git commit -am "Neue Überschrift (Variante A)"
git push -u origin feature/ueberschrift-a

git switch main
git switch -c feature/ueberschrift-b
```

Ändere **dieselbe Zeile** auf `<h1>Servus aus der Pipeline! 🐳</h1>`.

```bash
git commit -am "Neue Überschrift (Variante B)"
git push -u origin feature/ueberschrift-b
```

### Schritt 2: Zwei Pull Requests

1. Erstelle für **beide** Branches einen Pull Request
2. Merge **Variante A** → beobachte, wie die Pipeline sie ausrollt, und lade die Webseite neu
3. Schau dir den Pull Request von **Variante B** an: *This branch has conflicts that must be resolved*

### Schritt 3: Den Konflikt lokal lösen

```bash
git switch feature/ueberschrift-b
git pull origin main          # → CONFLICT (content): Merge conflict in app/server.js
git status
```

Öffne `app/server.js` (z. B. in VS Code), entscheide dich für eine Überschrift (oder kombiniere beide), entferne die Markierungen `<<<<<<<`, `=======` und `>>>>>>>`:

```bash
git add app/server.js
git commit                    # Merge-Commit
git push
```

Der Pull Request ist jetzt konfliktfrei. Warte, bis die CI **grün** ist, und merge ihn.

<details>
<summary>❓ Was hätte der Branch-Schutz verhindert, wenn du den Konflikt falsch gelöst hättest – z. B. die Markierungen stehen gelassen?</summary>

Die Markierungen machen `server.js` zu ungültigem JavaScript. Der Job `App testen` wird rot, und wegen der Regel **Require status checks to pass** lässt GitHub den PR **nicht mergen** – der Fehler kommt nie in Produktion.

</details>

### Schritt 4: Das Ergebnis

Lade die Webseite neu. Version und Überschrift haben sich geändert – **ohne** dass du AWS, Docker oder Terraform auch nur angefasst hast. Das ist CI/CD. 🚀

### Schritt 5 (optional): Rollback

Wie kommst du zurück zur vorherigen Version? Es gibt zwei Wege:

1. **Git-Weg (empfohlen):** Auf GitHub beim gemergten PR auf **Revert** klicken → neuer PR → mergen. Die Pipeline baut und rollt die alte Version aus. Die Historie bleibt nachvollziehbar.
2. **Image-Weg:** Weil jedes Image mit dem Commit-Hash in ECR liegt, könnte man auch direkt ein altes Image starten. Probiere das in der Session-Manager-Shell aus (`sudo docker run …:<alter-hash>`). Was passiert beim nächsten Merge?

---

## Aufgabe 8: Aufräumen

Eine laufende EC2-Instanz kostet Geld. Lege `.github/workflows/destroy.yml` an – wie in Kapitel 09, nur mit `working-directory: infra` und ohne `TF_VAR_key_name`.

<details>
<summary>💡 Lösung anzeigen</summary>

Siehe [loesung/.github/workflows/destroy.yml](./loesung/.github/workflows/destroy.yml).

</details>

Per Branch + Pull Request auf `main` bringen, dann: **Actions** → **Destroy** → **Run workflow** → `destroy` eintippen.

Prüfe danach in der AWS-Konsole: **EC2**, **ECR**, **VPC**, **IAM** → **Roles** – ist alles mit deinem Vornamen weg?

> Wenn du die Zusatzaufgabe noch machen willst, kannst du das Aufräumen auch auf **danach** verschieben.

---

## Zusatzaufgabe: Fargate statt EC2

Bisher kümmerst **du** dich um den Server: Betriebssystem, Docker-Installation, Updates, SSM-Agent. Mit **AWS Fargate** sagst du AWS nur noch: „Starte **dieses Image** mit **so viel CPU und RAM**“ – den Server darunter siehst du nie.

### Grundbegriffe: ECS und Fargate

**ECS** (Elastic Container Service) ist der Container-Dienst von AWS – vergleichbar mit Kubernetes aus Kapitel 07, nur einfacher. **Fargate** ist die „serverlose“ Art, ECS zu betreiben.

| ECS-Begriff         | Bedeutung                                                         | Entspricht in Kubernetes |
| ------------------- | ----------------------------------------------------------------- | ------------------------ |
| **Cluster**         | Logische Gruppe für Services                                      | Cluster / Namespace      |
| **Task Definition** | Bauplan: Image, CPU, RAM, Ports, Umgebungsvariablen, Logs         | Pod-Spezifikation        |
| **Task**            | Ein **laufender** Container (oder mehrere) nach diesem Bauplan    | Pod                      |
| **Service**         | Sorgt dafür, dass immer `desired_count` Tasks laufen              | Deployment               |

|                         | EC2 (Aufgabe 6)                                | Fargate (Zusatzaufgabe)                          |
| ----------------------- | ---------------------------------------------- | ------------------------------------------------ |
| Server verwalten        | Du (AMI, `user_data`, Updates)                 | AWS                                              |
| Docker installieren     | `dnf install docker`                           | Nicht nötig                                      |
| Deployment              | SSM → `docker pull` + `docker run`             | `aws ecs update-service --force-new-deployment` |
| Abgestürzter Container  | `--restart unless-stopped`                     | Service startet automatisch einen neuen Task     |
| Logs                    | `docker logs` auf dem Server                   | CloudWatch Logs in der Konsole                   |
| Port-Mapping            | `-p 80:3000`                                   | Keins – Task-IP:**3000** direkt                  |
| Abrechnung              | Pro Stunde Instanz – auch wenn sie nichts tut  | Pro Sekunde CPU/RAM des Tasks                    |

```
  GitHub Actions                     AWS
 ┌────────────────────────┐        ┌──────────────────────────────────────────────────────┐
 │ terraform apply ───────────────▶│ ECS-Cluster ─ Service (desired_count = 1)            │
 │ docker push ───────────────────▶│ ECR ─ anna-webapp:latest        │                    │
 │ aws ecs update-service          │     ▲                           ▼                    │
 │   --force-new-deployment ──────▶│     └──── zieht Image ──── Fargate-Task ── :3000 ◀── Browser
 └────────────────────────┘        └──────────────────────────────────────────────────────┘
```

```bash
git switch main && git pull
git switch -c feature/fargate
```

### Schritt 1: Fargate parallel zu EC2 anlegen (`infra/fargate.tf`)

Lege [zusatz-fargate/infra/fargate.tf](./zusatz-fargate/infra/fargate.tf) an und lies die Kommentare. Neu sind:

- `aws_ecs_cluster` – der Cluster
- `aws_cloudwatch_log_group` – wohin die Container-Logs gehen
- `aws_iam_role` „Execution Role“ – damit **ECS** das Image aus ECR ziehen und Logs schreiben darf
- `aws_ecs_task_definition` – Image `…:latest`, 0,25 vCPU, 512 MB, Port 3000, `PLATTFORM=Fargate`
- `aws_security_group` – Port **3000** eingehend
- `aws_ecs_service` – 1 Task im öffentlichen Subnetz mit **öffentlicher IP**

Ergänze in `outputs.tf`:

```hcl
output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service" {
  value = aws_ecs_service.app.name
}
```

Lokal prüfen (`terraform fmt`, `terraform validate`), committen, pushen, Pull Request erstellen. Wie viele neue Ressourcen zeigt der Plan? (Lösung: **9** – Cluster, Log Group, Rolle, Policy-Attachment, Task Definition, Security Group, 2 Regeln, Service)

<details>
<summary>❓ Warum braucht der Task eine öffentliche IP (<code>assign_public_ip = true</code>)?</summary>

Aus zwei Gründen: 1. Der Task muss das Image aus **ECR** ziehen – das geht über das Internet Gateway nur mit öffentlicher IP (alternativ bräuchte man ein NAT Gateway oder VPC Endpoints, die extra kosten). 2. Wir wollen die App ohne Load Balancer direkt im Browser aufrufen.

</details>

### Schritt 2: Den Deploy-Job für Fargate

Die Task Definition zeigt auf `:latest` – sie **ändert sich nicht**, wenn ein neues Image gepusht wird. Deshalb sagen wir ECS ausdrücklich: „Starte neue Tasks“ (die dann das neue `latest` ziehen):

```bash
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --force-new-deployment
aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"
```

Ergänze in `cd.yml`:

1. Im Job `infrastruktur` zwei weitere Outputs: `ecs_cluster` und `ecs_service`
2. Einen neuen Job `deploy-fargate` mit `needs: [infrastruktur, build-push]`, der
   - das Deployment startet und wartet, bis der Service stabil ist
   - die **öffentliche IP** des laufenden Tasks herausfindet
   - einen Smoke-Test auf `http://<ip>:3000/health` macht

Die IP herauszufinden ist eine kleine Kette von AWS-CLI-Aufrufen: **Task** → **Netzwerkkarte (ENI)** → **öffentliche IP**:

```bash
TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" \
  --desired-status RUNNING --query "taskArns[0]" --output text)
ENI_ID=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text)
IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" \
  --query "NetworkInterfaces[0].Association.PublicIp" --output text)
```

<details>
<summary>💡 Lösung anzeigen</summary>

Den Job `deploy-fargate` findest du in [zusatz-fargate/.github/workflows/cd.yml](./zusatz-fargate/.github/workflows/cd.yml). Für Schritt 2 behältst du den Job `deploy-ec2` vorerst noch **zusätzlich** – beide Jobs laufen dann parallel.

</details>

Committen, pushen, CI grün → **mergen**. Jetzt läuft die App **zweimal**: auf EC2 (`http://<ec2-ip>`, Plattform `EC2`) und auf Fargate (`http://<task-ip>:3000`, Plattform `Fargate`). Beide zeigen **denselben** Commit-Hash.

### Schritt 3: Logs und Selbstheilung ansehen

1. AWS-Konsole → **Elastic Container Service** → **Clusters** → `<vorname>-cluster` → **Services** → `<vorname>-webapp` → Reiter **Logs**: Hier steht `Web-App läuft auf Port 3000 …`
2. Reiter **Tasks** → Task auswählen → **Stop**. Was passiert nach ca. einer Minute?

<details>
<summary>❓ Antwort</summary>

Der **Service** bemerkt, dass statt 1 nur 0 Tasks laufen, und startet automatisch einen **neuen** Task – mit einer **neuen** öffentlichen IP und einem neuen Hostnamen. Genau wie ein Kubernetes-Deployment, das einen gelöschten Pod ersetzt. (Die wechselnde IP ist der Grund, warum man in Produktion einen **Load Balancer** davorschaltet – siehe Bonus.)

</details>

### Schritt 4: EC2 abschaffen – „Fargate **statt** EC2“

Jetzt brauchst du die EC2-Instanz nicht mehr.

```bash
git switch main && git pull
git switch -c feature/ec2-entfernen
```

1. Lösche `infra/ec2.tf` und `infra/iam.tf`
2. Entferne in `infra/outputs.tf` die Outputs `instance_id`, `public_ip` und `webapp_url` (vgl. [zusatz-fargate/infra/outputs.tf](./zusatz-fargate/infra/outputs.tf))
3. Entferne in `cd.yml` den Job `deploy-ec2` und die Outputs `instance_id`/`webapp_url` des Jobs `infrastruktur` (vgl. [zusatz-fargate/.github/workflows/cd.yml](./zusatz-fargate/.github/workflows/cd.yml))
4. Optional: Die Variable `host_port` in `variables.tf` wird nicht mehr gebraucht – löschen

Committen, pushen, Pull Request erstellen und den **Plan** genau lesen:

<details>
<summary>❓ Was sollte im Plan stehen?</summary>

`0 to add, 0 to change, 8 to destroy`: EC2-Instanz, Security Group, 2 Security-Group-Regeln, IAM-Rolle, 2 Policy-Attachments, Instance Profile. **Wichtig:** ECR, VPC und alles für Fargate dürfen **nicht** in der Liste stehen! Genau dafür ist der Plan im Pull Request da: Man sieht **vor** dem Merge, was gelöscht wird.

</details>

Mergen → Die Pipeline baut, pusht und rollt **nur noch auf Fargate** aus. 🎉

Am Ende: **Destroy**-Workflow ausführen (Aufgabe 8) – er löscht jetzt auch Cluster, Service und Log Group.

---

## Bonus für Schnelle

| Idee                               | Stichworte                                                                                                     |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **Freigabe vor dem Ausrollen**     | Environment `production` mit Required Reviewers (Kapitel 09) im Job `infrastruktur` bzw. `deploy-*`             |
| **Load Balancer vor Fargate**      | `aws_lb`, `aws_lb_target_group` (target_type `ip`), `aws_lb_listener` auf Port 80, `load_balancer`-Block im Service. Braucht **zwei** Subnetze in verschiedenen AZs |
| **Ohne `:latest`**                 | Die Pipeline registriert pro Commit eine neue Task Definition mit `…:<sha>` (`aws ecs register-task-definition`) – sauberer, weil jede Version eindeutig ist |
| **Keine Access Keys mehr**         | GitHub Actions per **OIDC** bei AWS anmelden: `aws-actions/configure-aws-credentials` mit `role-to-assume`     |
| **Pipeline nur bei Änderungen**    | `on.push.paths:` – z. B. den Docker-Build überspringen, wenn sich nur `README.md` geändert hat                 |
| **Sicherheits-Scan als Gate**      | Nach dem Push die ECR-Scan-Ergebnisse abfragen (`aws ecr describe-image-scan-findings`) und bei `CRITICAL` abbrechen |
| **Mehrere Tasks**                  | `desired_count = 2` – lade die Seite mehrfach: Ändert sich der Hostname? (Nur mit Load Balancer!)               |

## Checkliste zum Schluss

- [ ] Jede Änderung kam über einen **Branch + Pull Request** nach `main`
- [ ] Auf deinem Laptop lagen zu keinem Zeitpunkt **AWS-Zugangsdaten** oder ein **Terraform-State**
- [ ] Die Pipeline hat **getestet**, **gebaut**, nach **ECR gepusht** und **ausgerollt**
- [ ] Du kannst erklären, warum die EC2-Instanz eine **IAM-Rolle** statt eines Access Keys hat
- [ ] Du kannst erklären, was bei `-p 80:3000` passiert – und warum es das bei Fargate nicht gibt
- [ ] Der **Destroy**-Workflow ist gelaufen und in AWS ist nichts mehr übrig
