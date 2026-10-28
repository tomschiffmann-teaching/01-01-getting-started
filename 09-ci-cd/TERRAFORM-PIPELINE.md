# Teil 2: Das Terraform-Deployment automatisieren

In Kapitel 08 hast du deine Infrastruktur (VPC, Subnetz, Security Group, EC2-Instanz) mit Terraform beschrieben und **von deinem Laptop aus** mit `terraform apply` angelegt. Den State hast du bereits in einen **S3-Bucket** umgezogen, und für Terraform gibt es einen eigenen **IAM-Benutzer** mit Access Key.

Das ist schon ziemlich professionell – hat aber noch drei Schwachstellen:

- Wer darf `terraform apply` ausführen? **Jeder**, der die Zugangsdaten auf seinem Laptop hat
- Wer prüft eine Änderung, **bevor** sie in AWS landet? **Niemand**
- Welche Terraform-Version, welcher Stand des Codes wurde zuletzt ausgerollt? **Weiß keiner so genau**

In diesem Teil baust du Schritt für Schritt eine Pipeline, die das löst. Am Ende gilt:

> **Was auf `main` liegt, ist in AWS ausgerollt.** Änderungen kommen **nur** über einen **Pull Request** auf `main`. Die Pipeline zeigt im PR, **was** sich ändern würde – und erst nach dem Mergen (und einer Freigabe) rollt sie es aus. Niemand braucht mehr AWS-Zugangsdaten auf seinem Laptop.

## Grundbegriffe

### Was sind Umgebungsvariablen?

Eine **Umgebungsvariable** ist ein Name mit einem Wert, den das Betriebssystem jedem Programm **mitgibt**, wenn es startet. Ein paar kennst du schon, ohne es zu wissen:

| Variable | Beispielwert                        | Bedeutung                                  |
| -------- | ----------------------------------- | ------------------------------------------ |
| `HOME`   | `/home/anna`                        | Dein Benutzerverzeichnis (dasselbe wie `~`) |
| `USER`   | `anna`                              | Dein Benutzername                          |
| `PATH`   | `/usr/local/bin:/usr/bin:/bin`      | Wo die Shell nach Programmen sucht         |

Programme können diese Variablen **lesen**. Genau so finden die AWS CLI und Terraform deine Zugangsdaten: Sie schauen nach, ob es Variablen namens `AWS_ACCESS_KEY_ID` und `AWS_SECRET_ACCESS_KEY` gibt.

```
  Terminal (Shell)                        Programm, das du startest
 ┌────────────────────────────────┐      ┌───────────────────────────────────────┐
 │ export AWS_ACCESS_KEY_ID=AKIA… │      │ terraform plan                        │
 │ export AWS_SECRET_ACCESS_KEY=… │─────▶│  → liest AWS_ACCESS_KEY_ID            │
 │ export TF_VAR_vorname=anna     │ erbt │  → liest AWS_SECRET_ACCESS_KEY        │
 │                                │      │  → liest TF_VAR_vorname = var.vorname │
 └────────────────────────────────┘      └───────────────────────────────────────┘
```

Drei Eigenschaften musst du dir merken:

- **Vererbung:** Ein Programm bekommt eine **Kopie** der Variablen der Shell, aus der es gestartet wird – aber nur von den Variablen, die mit `export` markiert sind
- **Lebensdauer:** Die Variablen leben nur so lange wie **dieses eine** Terminal. Neues Fenster = Variablen weg
- **Keine Datei:** Die Werte stehen nirgends im Projektordner – deshalb können sie auch nicht aus Versehen in Git landen

> **Vergleich:** Umgebungsvariablen sind wie ein **Zettel, den du jedem Mitarbeiter in die Hand drückst**, wenn er zur Schicht kommt. Der Mitarbeiter (das Programm) liest ihn, aber der Zettel hängt nicht dauerhaft an der Wand (in einer Datei).

### Umgebungsvariablen in GitHub Actions

In der Pipeline gibt es kein Terminal, in das du `export` tippen kannst. Stattdessen setzt du Variablen mit `env:` in der Workflow-Datei – auf drei Ebenen:

```yaml
env:                       # 1. Workflow-Ebene: gilt für ALLE Jobs
  AWS_REGION: us-east-1

jobs:
  plan:
    env:                   # 2. Job-Ebene: gilt für alle Steps dieses Jobs
      TF_IN_AUTOMATION: "true"
    steps:
      - run: terraform plan
        env:               # 3. Step-Ebene: gilt nur für diesen einen Step
          TF_LOG: INFO
```

Aber woher kommen die **geheimen** Werte? Die gehören auf keinen Fall in die YAML-Datei – die liegt ja in Git. Dafür bietet GitHub zwei Speicher:

| Speicher      | Für                                            | Im Workflow           | Im Log sichtbar?                       | Beispiel                          |
| ------------- | ---------------------------------------------- | --------------------- | -------------------------------------- | --------------------------------- |
| **Secrets**   | Geheimnisse: Passwörter, Access Keys, Tokens   | `${{ secrets.NAME }}` | **Nein** – GitHub ersetzt sie durch `***` | `AWS_SECRET_ACCESS_KEY`           |
| **Variables** | Einstellungen, die nicht geheim sind           | `${{ vars.NAME }}`    | Ja                                     | Dein Vorname, Name des Schlüsselpaars |

Beides findest du im Repository unter **Settings** → **Secrets and variables** → **Actions**. Einen gespeicherten Secret-Wert kann **niemand** mehr ansehen – auch du nicht. Man kann ihn nur überschreiben oder löschen.

### Terraform-Variablen per Umgebungsvariable: `TF_VAR_`

In Kapitel 08 standen deine Werte (`vorname`, `key_name`) in der Datei `terraform.tfvars`. Die ist aber in der `.gitignore` – in der Pipeline gibt es sie also **nicht**.

Terraform hat dafür eine eingebaute Regel: Eine Umgebungsvariable mit dem Präfix **`TF_VAR_`** wird automatisch zur Terraform-Variablen.

| Umgebungsvariable          | wird in Terraform zu |
| -------------------------- | -------------------- |
| `TF_VAR_vorname=anna`      | `var.vorname`        |
| `TF_VAR_key_name=mein-key` | `var.key_name`       |

> Der Teil nach `TF_VAR_` muss **exakt** so geschrieben sein wie der Name in `variables.tf` – auch die Groß- und Kleinschreibung.

### Pull Requests und Branch-Schutz

Ein **Pull Request** (kurz **PR**) ist eine **Anfrage**: „Bitte übernimm die Änderungen aus meinem Branch nach `main`.“ Du kennst PRs schon aus Kapitel 04. In einem PR passiert dreierlei:

1. **Die Pipeline prüft** die Änderung automatisch (bei uns: `terraform fmt`, `validate`, `plan`)
2. **Ein Mensch schaut drüber** (Code Review) und sieht dabei auch den Plan: „Hier würde eine Instanz ersetzt – ist das gewollt?“
3. Erst wenn beides passt, wird **gemergt**

Damit niemand diesen Weg abkürzt, schützt man `main` mit einer **Branch-Regel** (bei GitHub: **Ruleset**):

- Niemand darf direkt auf `main` pushen – **nur** über einen PR
- Ein PR darf nur gemergt werden, wenn die Pipeline **grün** ist
- (Im Team:) Mindestens eine andere Person muss den PR **genehmigen**

### `main` = Produktion

Bei Infrastruktur-Code gilt meistens eine einfache Regel: **Der Branch `main` beschreibt die Produktion.** Was auf `main` liegt, soll genau so in AWS existieren. Ein Merge nach `main` ist also gleichbedeutend mit „Ausrollen“.

```
  feature/neue-regel ──●──●──┐                       ┌────────────────────────────┐
                             │ Pull Request          │ Pipeline auf dem PR:       │
                             │◀──────────────────────│ fmt · validate · plan      │
                             │ + Review              │ "2 to add, 1 to destroy"   │
                             ▼                       └────────────────────────────┘
  main ─────●───────────────●(Merge)─────────────────▶ Pipeline auf main:
                                                       plan → Freigabe → apply → AWS (Produktion)
```

> **Früher hieß `main` meistens `master`.** GitHub verwendet seit 2020 standardmäßig `main`, in älteren Projekten findest du noch `master`. Das Prinzip „Merge auf den Hauptbranch = Deployment in Produktion“ ist dasselbe.

Größere Teams haben oft **mehrere** Umgebungen, jede mit eigenem Branch oder eigenem Ordner:

| Branch / Auslöser     | Umgebung       | Wer nutzt sie?                    |
| --------------------- | -------------- | --------------------------------- |
| Pull Request          | – (nur `plan`) | Reviewer sehen die geplante Änderung |
| `develop`             | Staging        | Interne Tests                     |
| `main` (früher `master`) | **Production** | Echte Kundinnen und Kunden     |

Wir halten es einfach und arbeiten mit **einer** Umgebung: `main` → Production.

### Environments: Die Freigabe vor dem Ausrollen

Ein **Environment** in GitHub ist ein benanntes Ziel (z. B. `production`), an das man **Schutzregeln** hängen kann. Die wichtigste: **Required reviewers**. Ein Job, der in dieses Environment ausrollen will, **pausiert** – bis eine berechtigte Person auf **Approve** klickt.

Damit wird aus Continuous **Deployment** (alles automatisch) ein Continuous **Delivery** (automatisch bis kurz vor Produktion, dann ein Klick). Bei Infrastruktur ist das sehr verbreitet: Ein versehentlich gelöschtes VPC ist schwerer rückgängig zu machen als ein fehlerhafter Webseiten-Text.

### Das Gesamtbild

```
   Dein Laptop                      GitHub                                         AWS (us-east-1)
 ┌───────────────────┐  push   ┌─────────────────────────────────────────┐     ┌──────────────────────┐
 │ *.tf              │────────▶│ Repository terraform-pipeline           │     │ S3-Bucket            │
 │ git switch -c ... │         │  ├─ Secrets: AWS_ACCESS_KEY_ID, ...     │     │  terraform.tfstate   │
 │                   │         │  ├─ Variables: VORNAME, KEY_NAME        │     │        ▲             │
 │ KEINE AWS-Keys    │         │  └─ Ruleset: main nur per PR            │     │        │ State       │
 │ mehr nötig!       │         │                                         │     │        │             │
 └───────────────────┘         │  Actions-Runner (frische VM)            │     │ VPC, Subnetz, SG,    │
                               │   terraform init / plan / apply ────────┼────▶│ EC2-Instanz          │
                               └─────────────────────────────────────────┘     └──────────────────────┘
```

> **Jetzt wird klar, warum das Remote Backend aus Kapitel 08 so wichtig war:** Der Runner ist nach jedem Lauf gelöscht. Läge der State lokal auf dem Runner, hätte Terraform beim nächsten Lauf alles „vergessen“ und würde die Infrastruktur ein zweites Mal anlegen. Mit dem State im S3-Bucket teilen sich dein Laptop und **jeder** Pipeline-Lauf dasselbe Gedächtnis.

## Voraussetzungen

Aus **Kapitel 08** brauchst du:

- Den Terraform-Code aus [08-terraform/beispiel-1](../08-terraform/beispiel-1/) (`providers.tf`, `vpc.tf`, `ec2.tf`, `variables.tf`, `outputs.tf`, `.gitignore`) mit **einkommentiertem** `backend "s3"`-Block und **deinem** Bucket-Namen
- Den **S3-Bucket** für den State
- Den **IAM-Benutzer** `terraform` mit seinem **Access Key** (Access Key ID + Secret Access Key) und den Rechten für VPC, EC2 und S3. Hast du den Secret Access Key nicht mehr? Dann in IAM beim Benutzer einen **neuen** Access Key erstellen und den alten deaktivieren
- Das **Schlüsselpaar** in der AWS-Konsole (Region `us-east-1`) und seinen Namen

Aus **Teil 1** brauchst du: Grundwissen zu Workflows, Jobs, Steps und `actions/checkout`.

> **Öffentliches Repository:** Lege das Repository für diesen Teil **öffentlich** an. Branch-Schutz (Aufgabe 4) und Freigaben über Environments (Aufgabe 6) sind im **kostenlosen** GitHub-Plan nur bei öffentlichen Repositories verfügbar. Das ist unkritisch, denn **im Code stehen keine Geheimnisse** – die liegen als Secrets in GitHub. Sichtbar werden nur der Bucket-Name und in den Logs deine AWS-Account-ID.

> **Kosten:** Wie in Kapitel 08 – die Instanz kostet etwa 1–2 Cent pro Stunde. Die Pipeline-Minuten sind bei öffentlichen Repositories kostenlos. **Aufräumen nicht vergessen** (Aufgabe 8)!

## Überblick: Was machst du in Teil 2?

| Aufgabe          | Inhalt                                                               | Ergebnis                                                         |
| ---------------- | -------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **1**            | Umgebungsvariablen im Terminal verstehen                             | Du weißt, wie Terraform deine Zugangsdaten findet                |
| **2**            | Repository, Secrets – und die **Autorisierung** in der Pipeline prüfen | Die Pipeline weiß, **wer** sie in AWS ist                        |
| **3**            | Terraform-Code ins Repository, `fmt` / `validate` / `plan` in der Pipeline | Die Pipeline zeigt einen Plan                                  |
| **4**            | **Pull Requests** und **Branch-Schutz** für `main`                   | Änderungen nur noch per PR, Plan direkt im PR sichtbar           |
| **5**            | Automatisches **Deployment** nach dem Merge auf `main`               | Merge = `terraform apply` (Continuous Deployment)                |
| **6**            | **Freigabe** über das Environment `production`                       | Vor dem `apply` muss jemand auf **Approve** klicken (Continuous Delivery) |
| **7**            | Eine Änderung einmal komplett durchspielen                           | nginx läuft – ausgerollt ohne ein einziges `terraform apply` von Hand |
| **8**            | Aufräumen per Pipeline (`terraform destroy`)                         | Alles wieder gelöscht                                            |
| Zusatzaufgaben   | Plan als PR-Kommentar, Drift-Erkennung, OIDC statt Access Keys       | Für alle, die schneller fertig sind                              |

Die Aufgaben bauen **aufeinander auf** – bearbeite sie der Reihe nach. Die fertigen Dateien findest du zum Vergleichen in [beispiel-terraform](./beispiel-terraform/).

---

## Aufgabe 1: Umgebungsvariablen im Terminal verstehen

Bevor die Pipeline Umgebungsvariablen bekommt, schauen wir uns an, wie sie auf deinem Laptop funktionieren.

### Schritt 1: Vorhandene Variablen ansehen

```bash
echo $HOME
echo $USER
env | head -20
```

- `echo $NAME` gibt den Wert **einer** Variablen aus. Das `$` heißt: „setze hier den Wert ein“
- `env` listet **alle** Umgebungsvariablen auf

### Schritt 2: Eine eigene Variable – mit und ohne `export`

```bash
GRUSS="Hallo"
echo $GRUSS
bash -c 'echo "Im Kindprozess: $GRUSS"'
```

**Das solltest du sehen:**

```
Hallo
Im Kindprozess:
```

`bash -c '…'` startet ein **neues Programm** (eine zweite Shell). Die sieht `GRUSS` **nicht** – die Variable existiert nur in deiner aktuellen Shell. Jetzt mit `export`:

```bash
export GRUSS="Hallo"
bash -c 'echo "Im Kindprozess: $GRUSS"'
```

```
Im Kindprozess: Hallo
```

Erst `export` macht aus einer Shell-Variablen eine **Umgebungsvariable**, die an gestartete Programme **vererbt** wird. Terraform und die AWS CLI sind solche gestarteten Programme – deshalb steht in Kapitel 08 überall `export`.

Öffne jetzt ein **zweites** Terminal-Fenster und tippe dort `echo $GRUSS`. Die Zeile bleibt leer: Jedes Terminal hat **eigene** Variablen.

Variable wieder entfernen:

```bash
unset GRUSS
```

### Schritt 3: Ein Mini-Projekt, das nur fragt „Wer bin ich?“

Um die Anmeldung zu testen, ohne etwas anzulegen, nutzt du eine **Data Source**: `aws_caller_identity` schlägt nur nach, mit welchem Benutzer Terraform gerade angemeldet ist.

```bash
mkdir -p ~/auth-check
cd ~/auth-check
```

Lege die Datei `main.tf` an:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Data Source: legt nichts an, fragt AWS nur "Wer bin ich?"
data "aws_caller_identity" "aktuell" {}

output "account_id" {
  value = data.aws_caller_identity.aktuell.account_id
}

output "benutzer_arn" {
  value = data.aws_caller_identity.aktuell.arn
}
```

```bash
terraform init
```

### Schritt 4: Ohne Zugangsdaten

Damit der Test aussagekräftig ist, verstecken wir vorübergehend alle anderen Wege, über die Terraform Zugangsdaten finden könnte:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE
mv ~/.aws ~/.aws-versteckt 2>/dev/null
terraform plan
```

**Das solltest du sehen:**

```
Error: No valid credential sources found
```

Terraform hat überall gesucht und nichts gefunden – genau so wird es gleich auch in der Pipeline aussehen, solange dort keine Secrets hinterlegt sind.

### Schritt 5: Mit Zugangsdaten des `terraform`-Benutzers

```bash
export AWS_ACCESS_KEY_ID="<Access Key ID des terraform-Benutzers>"
export AWS_SECRET_ACCESS_KEY="<Secret Access Key des terraform-Benutzers>"
terraform plan
```

**Das solltest du sehen** (mit deinen Werten):

```
Changes to Outputs:
  + account_id   = "123456789012"
  + benutzer_arn = "arn:aws:iam::123456789012:user/terraform"

You can apply this plan to save these new output values to the Terraform
state, without changing any real infrastructure.
```

Am Ende des ARN steht `user/terraform` – Terraform ist also als **dein IAM-Benutzer `terraform`** angemeldet, nicht mit deinem persönlichen Konto. Und es wurde **nichts** angelegt.

### Schritt 6: Terraform-Variablen per `TF_VAR_`

Ergänze in der `main.tf`:

```hcl
variable "vorname" {
  type = string
}

output "gruss" {
  value = "Hallo ${var.vorname}!"
}
```

Führe `terraform plan` aus – Terraform **fragt** nach dem Wert für `var.vorname`. Brich mit `Strg + C` ab und setze die Variable stattdessen per Umgebungsvariable:

```bash
export TF_VAR_vorname="anna"
terraform plan
```

Jetzt fragt Terraform nicht mehr, und im Plan steht `+ gruss = "Hallo anna!"`. Genau diesen Trick nutzt die Pipeline gleich, weil es dort keine `terraform.tfvars` gibt.

### Schritt 7: Aufräumen

```bash
mv ~/.aws-versteckt ~/.aws 2>/dev/null
unset TF_VAR_vorname
```

Den Ordner `~/auth-check` brauchst du in Aufgabe 2 noch.

> **Merke:** Terraform sucht Zugangsdaten in einer festen Reihenfolge – **Umgebungsvariablen zuerst**, danach `~/.aws/credentials`. In der Pipeline gibt es kein `~/.aws`, also setzen wir dort Umgebungsvariablen.

---

## Aufgabe 2: Repository, Secrets – und die Autorisierung in der Pipeline prüfen

Bevor die Pipeline irgendetwas in AWS anlegen darf, prüfst du im allerersten Schritt: **Kommt sie überhaupt in AWS hinein – und als wer?**

### Schritt 1: Das Repository anlegen

1. Auf GitHub ein neues Repository anlegen: Name `terraform-pipeline`, **Public**, Häkchen bei **Add a README file**
2. Klonen und in VS Code öffnen:

```bash
cd ~
git clone git@github.com:<dein-github-name>/terraform-pipeline.git
cd terraform-pipeline
code .
```

3. Den Ordner aus Aufgabe 1 ins Repository kopieren – **ohne** die heruntergeladenen Provider:

```bash
mkdir auth-check
cp ~/auth-check/main.tf auth-check/
```

4. Die `.gitignore` aus Kapitel 08 ins Repository kopieren (sie sorgt u. a. dafür, dass `.terraform/`, `*.tfstate`, `*.tfvars` und `*.pem` nie committet werden):

```bash
cp ~/Pfad/zu/08-terraform/beispiel-1/.gitignore .
```

> Den Pfad musst du an deinen Rechner anpassen – oder du kopierst die Datei aus diesem Kurs-Repository: [08-terraform/beispiel-1/.gitignore](../08-terraform/beispiel-1/.gitignore).

### Schritt 2: Der Workflow – zunächst ohne Secrets

Lege `.github/workflows/terraform-auth.yml` an:

```yaml
name: AWS-Autorisierung prüfen

on:
  push:
    branches:
      - main
  workflow_dispatch:

# Umgebungsvariablen für ALLE Jobs. Die Werte kommen aus den Secrets des Repositories.
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_REGION: us-east-1

jobs:
  auth:
    name: Wer bin ich in AWS?
    runs-on: ubuntu-latest
    steps:
      - name: Code auschecken
        uses: actions/checkout@v5

      - name: Sind die Zugangsdaten gesetzt?
        run: |
          if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
            echo "::error::AWS_ACCESS_KEY_ID oder AWS_SECRET_ACCESS_KEY fehlt – bitte als Secret hinterlegen!"
            exit 1
          fi
          echo "Access Key ID: $AWS_ACCESS_KEY_ID"
          echo "Region:        $AWS_REGION"

      - name: AWS CLI – wer bin ich?
        run: aws sts get-caller-identity

      - name: Terraform installieren
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false

      - name: Terraform – wer bin ich?
        working-directory: auth-check
        run: |
          terraform init -input=false
          terraform plan -input=false
```

| Zeile                                        | Bedeutung                                                                                                                 |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `env:` ganz oben                             | Setzt die Umgebungsvariablen für **alle** Jobs – das `export` der Pipeline                                               |
| `${{ secrets.AWS_ACCESS_KEY_ID }}`           | Holt den Wert aus den Secrets. Gibt es das Secret nicht, ist der Wert **leer**                                           |
| `[ -z "$AWS_ACCESS_KEY_ID" ]`                | `-z` = „ist leer“. So bekommst du eine **verständliche** Fehlermeldung statt eines kryptischen AWS-Fehlers                |
| `::error::…`                                 | Eine spezielle Ausgabe, die GitHub als rote Fehlermeldung oben im Lauf anzeigt                                           |
| `aws sts get-caller-identity`                | Dieselbe Prüfung wie in Kapitel 08. Die AWS CLI ist auf den GitHub-Runnern **vorinstalliert**                            |
| `hashicorp/setup-terraform@v3`               | Fertige Action von HashiCorp: installiert Terraform auf dem Runner                                                        |
| `terraform_wrapper: false`                   | Schaltet eine Zusatzfunktion der Action ab, damit die Ausgaben von Terraform genau so aussehen wie bei dir im Terminal   |
| `working-directory: auth-check`              | Führt die Befehle im Unterordner `auth-check` aus – wie ein `cd auth-check`                                               |
| `-input=false`                               | Terraform darf **nichts fragen**. In der Pipeline kann niemand antworten – fehlt ein Wert, soll sie lieber sofort abbrechen |

Committen und pushen:

```bash
git add .
git commit -m "Autorisierungs-Check hinzufügen"
git push
```

**Das solltest du sehen:** Im Reiter **Actions** einen **roten** Lauf ❌. Oben steht die Meldung

```
AWS_ACCESS_KEY_ID oder AWS_SECRET_ACCESS_KEY fehlt – bitte als Secret hinterlegen!
```

Das ist **gewollt**: Die Pipeline hat (noch) keine Zugangsdaten – genau wie dein Terminal in Aufgabe 1, Schritt 4.

### Schritt 3: Die Secrets hinterlegen

1. Im Repository: **Settings** → links **Secrets and variables** → **Actions**
2. Reiter **Secrets** → **New repository secret**
3. Name: `AWS_ACCESS_KEY_ID`, Secret: die Access Key ID des `terraform`-Benutzers → **Add secret**
4. Noch einmal **New repository secret**: Name `AWS_SECRET_ACCESS_KEY`, Secret: der Secret Access Key → **Add secret**

> **Achte auf die Namen:** Sie müssen **exakt** so geschrieben sein wie hinter `secrets.` im Workflow. Kein Leerzeichen vor oder nach dem Wert einfügen!

### Schritt 4: Den Lauf wiederholen

Reiter **Actions** → den roten Lauf öffnen → oben rechts **Re-run jobs** → **Re-run all jobs**.

**Das solltest du sehen:** einen grünen Lauf ✅ und in den Schritten:

- **Sind die Zugangsdaten gesetzt?**

  ```
  Access Key ID: ***
  Region:        us-east-1
  ```

  Obwohl der Befehl die Access Key ID ausgibt, steht im Log nur `***`. GitHub **maskiert** jeden Secret-Wert automatisch, egal wo er auftaucht.

- **AWS CLI – wer bin ich?**

  ```json
  {
    "UserId": "AIDAEXAMPLEEXAMPLE123",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform"
  }
  ```

- **Terraform – wer bin ich?**

  ```
  Changes to Outputs:
    + account_id   = "123456789012"
    + benutzer_arn = "arn:aws:iam::123456789012:user/terraform"
  ```

Die Pipeline ist in AWS als Benutzer **`terraform`** angemeldet – und Terraform selbst findet die Zugangsdaten über die Umgebungsvariablen. Damit ist die Grundlage für alles Weitere gelegt.

> **Maskierung ist kein Allheilmittel.** GitHub ersetzt nur den **exakten** Secret-Text. Würdest du den Wert z. B. rückwärts oder Base64-kodiert ausgeben, stünde er im Klartext im Log. Deshalb gilt: Secrets **niemals** absichtlich ausgeben – das `echo` oben dient nur der Demonstration und kann wieder raus.

---

## Aufgabe 3: Terraform-Code ins Repository und `plan` in der Pipeline

Jetzt kommt der eigentliche Terraform-Code aus Kapitel 08 ins Repository.

### Schritt 1: Den Code kopieren

Kopiere die folgenden Dateien aus deinem Projektordner von Kapitel 08 (bzw. aus [08-terraform/beispiel-1](../08-terraform/beispiel-1/)) **direkt** in den Hauptordner von `terraform-pipeline`:

| Datei                  | Kopieren? | Warum                                                                                  |
| ---------------------- | --------- | -------------------------------------------------------------------------------------- |
| `providers.tf`         | ✅        | Mit **einkommentiertem** `backend "s3"` und **deinem** Bucket-Namen                    |
| `vpc.tf`, `ec2.tf`     | ✅        | Die Infrastruktur                                                                      |
| `variables.tf`         | ✅        | Die Deklaration der Variablen                                                          |
| `outputs.tf`           | ✅        | Die Ausgaben                                                                           |
| `.terraform.lock.hcl`  | ✅        | Fixiert die Provider-Version – Pipeline und Laptop verwenden dieselbe                  |
| `terraform.tfvars`     | ❌        | Enthält deine Werte, ist in der `.gitignore` – die Werte kommen gleich als **Variables** |
| `*.pem`                | ❌        | Dein privater SSH-Schlüssel gehört **niemals** in ein Repository                       |
| `.terraform/`, `*.tfstate` | ❌    | Provider-Downloads und State – der State liegt im S3-Bucket                            |

Danach sieht dein Repository so aus:

```
terraform-pipeline/
├── .github/
│   └── workflows/
│       └── terraform-auth.yml
├── .gitignore
├── .terraform.lock.hcl
├── auth-check/
│   └── main.tf
├── ec2.tf
├── outputs.tf
├── providers.tf
├── README.md
├── variables.tf
└── vpc.tf
```

> **Keine `.terraform.lock.hcl`?** Dann führe im Repository einmal `terraform init` aus (mit gesetzten Zugangsdaten) – die Datei wird dabei erzeugt. Den Ordner `.terraform/` ignoriert Git automatisch.

Prüfe, dass keine Geheimnisse dabei sind, **bevor** du committest:

```bash
git status
```

In der Liste dürfen **weder** `terraform.tfvars` **noch** eine `.pem`-Datei auftauchen.

### Schritt 2: Die Variables hinterlegen

Die Werte aus deiner `terraform.tfvars` sind nicht geheim – sie kommen deshalb als **Variables** (nicht als Secrets) nach GitHub:

1. **Settings** → **Secrets and variables** → **Actions** → Reiter **Variables**
2. **New repository variable**: Name `VORNAME`, Value: dein Vorname (z. B. `anna`)
3. **New repository variable**: Name `KEY_NAME`, Value: der Name deines Schlüsselpaars (z. B. `my-first-ssh-key`)

### Schritt 3: Der CI-Workflow

Lege `.github/workflows/terraform-ci.yml` an:

```yaml
name: Terraform CI

on:
  pull_request:
    branches:
      - main
  workflow_dispatch:

env:
  # Zugangsdaten für AWS (geheim → Secrets)
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_REGION: us-east-1
  # Terraform-Variablen (nicht geheim → Variables). TF_VAR_vorname wird zu var.vorname
  TF_VAR_vorname: ${{ vars.VORNAME }}
  TF_VAR_key_name: ${{ vars.KEY_NAME }}
  # Terraform weiß dann, dass es in einer Pipeline läuft, und spart sich Tipps wie "run terraform apply"
  TF_IN_AUTOMATION: "true"

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    steps:
      - name: Code auschecken
        uses: actions/checkout@v5

      - name: Terraform installieren
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false

      - name: Formatierung prüfen
        run: terraform fmt -check -diff

      - name: Init
        run: terraform init -input=false

      - name: Validate
        run: terraform validate

      - name: Plan
        run: terraform plan -input=false -out=tfplan
```

| Schritt                     | Was wird geprüft?                                                                                                          |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `terraform fmt -check -diff` | Ist der Code ordentlich formatiert? `-check` ändert nichts, sondern **meldet** nur. `-diff` zeigt, was anders sein müsste |
| `terraform init`            | Provider laden **und** mit dem S3-Backend verbinden – scheitert, wenn die Rechte für den Bucket fehlen                    |
| `terraform validate`        | Ist der Code gültig? Tippfehler, fehlende Argumente, falsche Verweise                                                      |
| `terraform plan`            | Was **würde** sich in AWS ändern? Liest dafür den State aus S3 und den Ist-Zustand aus AWS                                |

Die Reihenfolge ist Absicht: **Billige Prüfungen zuerst.** `fmt` braucht eine Sekunde und keine Zugangsdaten – schlägt es fehl, muss die Pipeline gar nicht erst mit AWS sprechen.

> **Warum läuft hier kein `push`-Event?** Dieser Workflow soll Änderungen **prüfen, bevor** sie nach `main` kommen – also im Pull Request. Für den ersten Test starten wir ihn per Knopfdruck.

Committen und pushen (das geht im Moment noch direkt auf `main` – ab Aufgabe 4 nicht mehr):

```bash
git add .
git commit -m "Terraform-Code und CI-Workflow hinzufügen"
git push
```

### Schritt 4: Den Workflow starten

Reiter **Actions** → links **Terraform CI** → **Run workflow** → **Run workflow**.

**Mögliches Ergebnis 1: ❌ bei „Formatierung prüfen“.** Gar nicht so unwahrscheinlich! Im Log siehst du, welche Datei nicht passt, z. B.:

```
outputs.tf
--- old/outputs.tf
+++ new/outputs.tf
@@ -21,4 +21,4 @@
 output "instance_id" {
   description = "Die Instanz-ID der Instanz"
   value       = aws_instance.server.id
-}
\ No newline at end of file
+}
Error: Process completed with exit code 3.
```

Repariere es lokal und pushe erneut:

```bash
terraform fmt
git commit -am "Code formatieren"
git push
```

Danach den Workflow noch einmal starten.

**Ergebnis 2: ✅ – und im Schritt „Plan“ steht einer dieser beiden Fälle:**

- Hast du die Infrastruktur in Kapitel 08 **nicht** abgeräumt:

  ```
  No changes. Your infrastructure matches the configuration.
  ```

  Die Pipeline liest **denselben** State aus S3 wie dein Laptop – und weiß deshalb, dass schon alles existiert.

- Hast du in Kapitel 08 `terraform destroy` ausgeführt:

  ```
  Plan: 9 to add, 0 to change, 0 to destroy.
  ```

Beides ist richtig. Angelegt wird hier **noch nichts** – `plan` ist nur die Vorschau.

> **Ab jetzt gilt:** Führe auf deinem Laptop **kein** `terraform apply` mehr aus. Ab Aufgabe 5 ist die Pipeline der **einzige** Weg in die Produktion. Würden Laptop und Pipeline abwechselnd ausrollen, wüsste wieder niemand, welcher Stand gerade in AWS läuft.

---

## Aufgabe 4: Pull Requests und Branch-Schutz

Bisher kann jeder mit Schreibrechten direkt auf `main` pushen – an der Pipeline vorbei. Das stellst du jetzt ab.

### Schritt 1: Ein Ruleset für `main` anlegen

1. Im Repository: **Settings** → links unter **Code and automation** auf **Rules** → **Rulesets**
2. **New ruleset** → **New branch ruleset**
3. **Ruleset Name:** `main-schutz`
4. **Enforcement status:** **Active**
5. **Target branches** → **Add target** → **Include default branch**
6. Unter **Rules** folgende Häkchen setzen:

| Regel                                       | Bedeutung                                                                                                     |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| **Restrict deletions**                      | `main` kann nicht gelöscht werden (ist meist schon aktiv)                                                     |
| **Require a pull request before merging**   | Änderungen nur noch über einen PR. **Required approvals:** `0`, wenn du allein arbeitest – im Team mindestens `1` |
| **Require status checks to pass**           | Der PR darf nur gemergt werden, wenn bestimmte Pipeline-Jobs grün sind. → **Add checks** → `Terraform Plan` eintippen und auswählen |
| **Block force pushes**                      | Niemand darf die Historie von `main` überschreiben (ist meist schon aktiv)                                    |

7. Ganz unten **Create**

> **`Terraform Plan` taucht in der Suche nicht auf?** GitHub schlägt nur Checks vor, die in den letzten Tagen mindestens **einmal gelaufen** sind. Hast du Aufgabe 3, Schritt 4 erfolgreich durchgeführt, ist er da. Der Name entspricht dem `name:` des Jobs im Workflow.

> **Und die Admins?** Die Liste **Bypass list** bleibt leer. Dann gelten die Regeln **auch für dich** als Besitzer des Repositories. Genau so soll es sein.

### Schritt 2: Ausprobieren – direkt auf `main` pushen

```bash
git switch main
echo "Test" >> README.md
git commit -am "Direkt auf main"
git push
```

**Das solltest du sehen:**

```
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote:
remote: - Changes must be made through a pull request.
remote:
 ! [remote rejected] main -> main (push declined due to repository rule violations)
```

GitHub lehnt den Push ab. Den lokalen Commit machst du wieder rückgängig:

```bash
git reset --hard origin/main
```

### Schritt 3: Den Plan im PR lesbar machen

Damit Reviewer nicht erst durch das Log scrollen müssen, schreibt die Pipeline den Plan in die **Job-Zusammenfassung** (Job Summary). Das ist eine Seite, die GitHub direkt oben im Lauf anzeigt.

Das ist eine Änderung am Code – und die geht jetzt nur noch per **Branch und PR**:

```bash
git switch -c feature/plan-zusammenfassung
```

Ergänze in `.github/workflows/terraform-ci.yml` **nach** dem Schritt `Plan`:

```yaml
      - name: Plan in die Zusammenfassung schreiben
        run: |
          echo "## Terraform Plan" >> "$GITHUB_STEP_SUMMARY"
          echo '```' >> "$GITHUB_STEP_SUMMARY"
          terraform show -no-color tfplan >> "$GITHUB_STEP_SUMMARY"
          echo '```' >> "$GITHUB_STEP_SUMMARY"
```

| Teil                    | Bedeutung                                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------------------------- |
| `$GITHUB_STEP_SUMMARY`  | Eine **Umgebungsvariable**, die GitHub in jedem Step setzt. Sie enthält den Pfad zu einer Datei – alles, was dort landet, zeigt GitHub als Zusammenfassung an (Markdown) |
| `>>`                    | Hängt die Ausgabe **an** die Datei an (ein `>` würde sie überschreiben)                                 |
| `terraform show tfplan` | Zeigt den in Aufgabe 3 gespeicherten Plan noch einmal an. `-no-color` lässt die Farbcodes weg          |

> Übrigens: GitHub setzt in jedem Lauf von sich aus viele Umgebungsvariablen, z. B. `GITHUB_SHA`, `GITHUB_REF_NAME` oder `GITHUB_ACTOR`. Das sind dieselben Werte, die du in Teil 1 mit `${{ github.sha }}` ausgegeben hast.

### Schritt 4: Eine Infrastruktur-Änderung im selben PR

Damit im Plan auch etwas zu sehen ist, ändere zusätzlich etwas an der Infrastruktur. Ergänze in `ec2.tf` beim Block `aws_instance.server` einen weiteren Tag:

```hcl
  tags = {
    Name       = "${var.vorname}-server"
    Umgebung   = "production"
    Verwaltung = "terraform-pipeline"
  }
```

Committen, pushen, PR öffnen:

```bash
terraform fmt
git add .
git commit -m "Plan-Zusammenfassung und Tags"
git push -u origin feature/plan-zusammenfassung
```

Auf GitHub **Compare & pull request** → **Create pull request**.

### Schritt 5: Den PR prüfen

**Das solltest du sehen:**

1. Unten im PR läuft der Check **Terraform CI / Terraform Plan**. Solange er läuft, ist der Knopf **Merge pull request** grau – darunter steht `Required` neben dem Check
2. Nach dem Lauf: **Details** → oben auf **Summary**. Dort steht der Plan, z. B.:

```
  # aws_instance.server will be updated in-place
  ~ resource "aws_instance" "server" {
        id   = "i-0a1b2c3d4e5f67890"
      ~ tags = {
            "Name"       = "anna-server"
          + "Umgebung"   = "production"
          + "Verwaltung" = "terraform-pipeline"
        }
        # (30 unchanged attributes hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

**Das ist das Review:** Jeder im Team kann jetzt sehen, **was** genau in AWS passieren würde – `~` heißt „wird geändert“, nichts wird gelöscht. Hätte der Plan `-/+` oder `destroy` angezeigt, wäre das der Moment, um nachzufragen.

> **Noch NICHT mergen!** Es gibt noch keinen Deploy-Workflow. Würdest du jetzt mergen, läge die Änderung auf `main`, wäre aber **nicht** in AWS ausgerollt – genau den Zustand wollen wir vermeiden. Lass den PR offen und mach mit Aufgabe 5 weiter.

---

## Aufgabe 5: Automatisches Deployment nach dem Merge

Jetzt kommt das **CD**: Sobald etwas auf `main` landet, soll die Pipeline `terraform apply` ausführen.

### Schritt 1: Der Deploy-Workflow

Bleib auf dem Branch `feature/plan-zusammenfassung` und lege `.github/workflows/terraform-deploy.yml` an:

```yaml
name: Terraform Deploy

on:
  push:
    branches:
      - main
  workflow_dispatch:

# Nie zwei Deployments gleichzeitig – das zweite wartet, bis das erste fertig ist
concurrency:
  group: terraform-production
  cancel-in-progress: false

env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_REGION: us-east-1
  TF_VAR_vorname: ${{ vars.VORNAME }}
  TF_VAR_key_name: ${{ vars.KEY_NAME }}
  TF_IN_AUTOMATION: "true"

jobs:
  deploy:
    name: Terraform Apply
    runs-on: ubuntu-latest
    steps:
      - name: Code auschecken
        uses: actions/checkout@v5

      - name: Terraform installieren
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false

      - name: Init
        run: terraform init -input=false

      - name: Plan
        run: terraform plan -input=false -out=tfplan

      - name: Apply
        run: terraform apply -input=false tfplan

      - name: Outputs anzeigen
        run: terraform output
```

| Teil                                   | Bedeutung                                                                                                                         |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `on: push: branches: [main]`           | Läuft bei jedem Push auf `main` – und weil direktes Pushen verboten ist, heißt das: **bei jedem gemergten PR**                   |
| `concurrency`                          | Alle Läufe mit derselben `group` laufen **nacheinander**. Zusätzlich zum Lock im S3-Bucket verhindert das zwei gleichzeitige `apply` |
| `cancel-in-progress: false`            | Ein laufendes `apply` wird **nie** abgebrochen – ein halbfertiges `apply` wäre schlimmer als ein wartendes                       |
| `terraform plan -out=tfplan`           | Speichert den Plan in einer Datei                                                                                                 |
| `terraform apply tfplan`               | Führt **genau diesen** gespeicherten Plan aus. Terraform fragt dabei **nicht** nach `yes` – die Datei gilt als Bestätigung         |

> **Warum kein `terraform apply -auto-approve`?** Das würde auch funktionieren, rechnet den Plan aber neu aus. Mit `plan -out` + `apply tfplan` steht im Log **genau** der Plan, der danach ausgeführt wurde. Das wird in Aufgabe 6 noch wichtig.

### Schritt 2: Pushen und den PR prüfen

```bash
git add .
git commit -m "Deploy-Workflow hinzufügen"
git push
```

Der PR aktualisiert sich, `Terraform Plan` läuft erneut. Der Deploy-Workflow läuft im PR **nicht** – er reagiert ja nur auf `main`.

### Schritt 3: Mergen = Ausrollen

Sobald der Check grün ist: **Merge pull request** → **Confirm merge**. Danach kannst du auf GitHub **Delete branch** klicken.

Wechsle sofort in den Reiter **Actions**. **Das solltest du sehen:** einen neuen Lauf **Terraform Deploy** (und **AWS-Autorisierung prüfen**, der ebenfalls auf `main` reagiert). Im Schritt **Apply**:

```
aws_instance.server: Modifying... [id=i-0a1b2c3d4e5f67890]
aws_instance.server: Modifications complete after 2s [id=i-0a1b2c3d4e5f67890]

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

(Hattest du in Kapitel 08 aufgeräumt, steht hier `Resources: 9 added, …`. Das dauert dann etwa eine Minute.)

Im Schritt **Outputs anzeigen** findest du die `public_ip` und den fertigen `ssh_befehl`.

### Schritt 4: Nachprüfen

1. In der AWS-Konsole: **EC2** → **Instances** → deine Instanz → Reiter **Tags**. Dort stehen jetzt `Umgebung` und `Verwaltung`
2. Auf deinem Laptop den lokalen Stand aktualisieren:

```bash
git switch main
git pull
```

3. (Optional) Per SSH verbinden – mit dem `ssh_befehl` aus den Outputs und deinem Schlüssel aus Kapitel 08

> **Das ist Continuous Deployment:** Du hast **kein** `terraform apply` getippt und **keine** AWS-Zugangsdaten auf deinem Laptop gebraucht. Merge → Pipeline → AWS.

---

## Aufgabe 6: Freigabe über das Environment `production`

Continuous Deployment ist schnell – aber ein Merge rollt **sofort** aus, auch wenn im Plan `9 to destroy` steht. Bei Produktions-Infrastruktur will man meist noch ein **letztes Okay** von einem Menschen. Dafür gibt es **Environments**.

### Schritt 1: Das Environment anlegen

1. **Settings** → links **Environments** → **New environment**
2. Name: `production` → **Configure environment**
3. Häkchen bei **Required reviewers** → dich selbst (bzw. im Team: die verantwortliche Person) eintragen
4. Das Häkchen **Prevent self-review** **nicht** setzen – sonst könntest du deine eigenen Deployments nicht freigeben
5. Unter **Deployment branches and tags**: **Selected branches and tags** → **Add deployment branch or tag rule** → `main` → **Add rule**. Damit kann **nur** von `main` aus in `production` ausgerollt werden
6. **Save protection rules**

### Schritt 2: Plan und Apply trennen

Die Idee: Ein erster Job erstellt den Plan **ohne** Freigabe. Der zweite Job hängt am Environment `production` – er wartet, bis jemand auf **Approve** klickt, und wendet dann **genau den geprüften Plan** an.

```
   Merge auf main
        │
        ▼
 ┌──────────────────┐    tfplan     ┌────────────────────────┐
 │ Job: plan        │──(Artifact)──▶│ Job: apply             │
 │  init, plan      │               │  environment:          │
 │  Plan → Summary  │               │    production          │
 └──────────────────┘               │  ⏸ wartet auf Approve  │
   Keine Änderungen?                │  apply tfplan          │
   → apply wird übersprungen        └────────────────────────┘
```

Weil `main` geschützt ist: neuer Branch.

```bash
git switch main
git pull
git switch -c feature/freigabe
```

Ersetze den Teil ab `jobs:` in `.github/workflows/terraform-deploy.yml` durch:

```yaml
jobs:
  plan:
    name: Plan (Produktion)
    runs-on: ubuntu-latest
    outputs:
      aenderungen: ${{ steps.plan.outputs.aenderungen }}
    steps:
      - name: Code auschecken
        uses: actions/checkout@v5

      - name: Terraform installieren
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false

      - name: Init
        run: terraform init -input=false

      - name: Plan
        id: plan
        run: |
          set +e
          terraform plan -input=false -detailed-exitcode -out=tfplan
          exitcode=$?
          set -e
          if [ "$exitcode" -eq 1 ]; then
            exit 1
          fi
          if [ "$exitcode" -eq 2 ]; then
            echo "aenderungen=true" >> "$GITHUB_OUTPUT"
          else
            echo "aenderungen=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Plan in die Zusammenfassung schreiben
        run: |
          echo "## Terraform Plan (Produktion)" >> "$GITHUB_STEP_SUMMARY"
          echo '```' >> "$GITHUB_STEP_SUMMARY"
          terraform show -no-color tfplan >> "$GITHUB_STEP_SUMMARY"
          echo '```' >> "$GITHUB_STEP_SUMMARY"

      - name: Plan-Datei für den Apply-Job aufheben
        if: steps.plan.outputs.aenderungen == 'true'
        uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: tfplan
          retention-days: 1

  apply:
    name: Apply (Produktion)
    needs: plan
    if: needs.plan.outputs.aenderungen == 'true'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Code auschecken
        uses: actions/checkout@v5

      - name: Terraform installieren
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false

      - name: Init
        run: terraform init -input=false

      - name: Plan-Datei holen
        uses: actions/download-artifact@v4
        with:
          name: tfplan

      - name: Apply
        run: terraform apply -input=false tfplan

      - name: Outputs anzeigen
        run: terraform output
```

Das ist der anspruchsvollste Workflow des Kapitels – Schritt für Schritt:

| Teil                                         | Bedeutung                                                                                                                              |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `-detailed-exitcode`                         | `terraform plan` meldet dann **drei** verschiedene Exit-Codes: `0` = keine Änderungen, `1` = Fehler, `2` = es gibt Änderungen         |
| `set +e` … `set -e`                          | GitHub bricht einen Step normalerweise beim ersten Exit-Code ≠ 0 ab. Weil `2` hier **kein** Fehler ist, schalten wir das kurz ab       |
| `echo "aenderungen=…" >> "$GITHUB_OUTPUT"`   | Schreibt einen **Ausgabewert** des Steps. `$GITHUB_OUTPUT` funktioniert wie `$GITHUB_STEP_SUMMARY` – nur für Werte statt für Text     |
| `outputs:` beim Job `plan`                   | Reicht den Wert des Steps nach außen weiter, damit **andere Jobs** ihn lesen können                                                    |
| `if: needs.plan.outputs.aenderungen == 'true'` | Der Job `apply` läuft nur, wenn es etwas zu tun gibt. Sonst müsste jemand ein Deployment freigeben, das gar nichts ändert             |
| `actions/upload-artifact` / `download-artifact` | Die beiden Jobs laufen auf **verschiedenen** Runnern (siehe Teil 1, Aufgabe 3). Die Plan-Datei wird deshalb als **Artifact** übergeben |
| `retention-days: 1`                          | Der Plan kann sensible Werte enthalten – GitHub löscht das Artifact nach einem Tag                                                     |
| `environment: production`                    | **Hier** greift die Schutzregel: Bevor der Job startet, wartet er auf eine Freigabe                                                    |

> **Und wenn sich zwischen Plan und Freigabe etwas ändert?** Dann verweigert `terraform apply tfplan` mit der Meldung `Saved plan is stale`. Terraform wendet einen gespeicherten Plan nur an, wenn der State noch genau so ist wie beim Erstellen. Es wird also **nie** etwas anderes ausgerollt als das, was du freigegeben hast.

### Schritt 3: Ausprobieren – ein Merge ohne Infrastruktur-Änderung

```bash
git add .
git commit -m "Freigabe über Environment production"
git push -u origin feature/freigabe
```

PR öffnen, auf den grünen Check warten, mergen.

**Das solltest du sehen:** Im Lauf **Terraform Deploy** ist `Plan (Produktion)` grün, `Apply (Produktion)` ist **übersprungen** (grauer, durchgestrichener Kreis). Richtig so – an der Infrastruktur hat sich ja nichts geändert, nur am Workflow.

Die Freigabe selbst probierst du in Aufgabe 7 aus.

> **Profi-Tipp:** Man kann Secrets auch **an ein Environment** hängen statt an das Repository (**Settings** → **Environments** → `production` → **Environment secrets**). Dann bekommt **nur** ein freigegebener Job die Zugangsdaten. In großen Teams nutzt man so z. B. einen IAM-Benutzer mit **Leserechten** für `plan` und einen mit **Schreibrechten** für `apply`.

---

## Aufgabe 7: Eine Änderung einmal komplett durchspielen

Jetzt alles zusammen – vom Branch bis zur laufenden Webseite. Als Änderung installierst du **nginx** auf dem Server (wie in Kapitel 08, Zusatzaufgabe 1). Hast du das dort schon gemacht, ändere stattdessen den Text der Webseite.

### Schritt 1: Branch anlegen

```bash
git switch main
git pull
git switch -c feature/nginx
```

### Schritt 2: Port 80 öffnen

In `ec2.tf` nach der SSH-Regel ergänzen:

```hcl
# Eingehend: HTTP (Port 80) von überall
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.server.id
  description       = "HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}
```

### Schritt 3: Das Startskript ergänzen

Im Block `aws_instance.server` (vor `tags`):

```hcl
  user_data_replace_on_change = true
  user_data                   = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "<h1>Hallo von ${var.vorname} - ausgerollt per Pipeline!</h1>" > /var/www/html/index.html
  EOF
```

Und in `outputs.tf`:

```hcl
output "webseite" {
  description = "Adresse der Webseite"
  value       = "http://${aws_instance.server.public_ip}"
}
```

### Schritt 4: Lokal vorprüfen

Bevor du pushst, kannst du die **billigen** Prüfungen auch lokal laufen lassen – dafür brauchst du keine AWS-Zugangsdaten:

```bash
terraform fmt
terraform validate
```

> `validate` braucht ein initialisiertes Verzeichnis. Hast du im Repository noch nie `terraform init` ausgeführt, geht das ohne Zugangsdaten mit `terraform init -backend=false`.

### Schritt 5: Pushen und PR öffnen

```bash
git add .
git commit -m "nginx per user_data installieren"
git push -u origin feature/nginx
```

PR öffnen. In der Summary des Checks steht diesmal:

```
  # aws_instance.server must be replaced
-/+ resource "aws_instance" "server" {
      ...
      + user_data                   = "…" # forces replacement
      ...
    }

  # aws_vpc_security_group_ingress_rule.http will be created
  + resource "aws_vpc_security_group_ingress_rule" "http" {
      ...
    }

Plan: 2 to add, 0 to change, 1 to destroy.
```

**Review-Frage:** Die Instanz wird **ersetzt** (`-/+`). Ist das in Ordnung? Ja – auf dem Server liegen keine Daten, die verloren gehen könnten, und alles Nötige steht im `user_data`. In einem echten Team würdest du das im PR kurz begründen.

### Schritt 6: Mergen und freigeben

1. PR mergen
2. Reiter **Actions** → Lauf **Terraform Deploy** öffnen
3. `Plan (Produktion)` wird grün. Danach erscheint oben ein gelber Kasten: **Waiting for review – production needs approval to start deploying changes**
4. Bevor du freigibst: Klick auf **Summary** und lies den Plan ein letztes Mal
5. **Review deployments** → Häkchen bei `production` → optional einen Kommentar schreiben → **Approve and deploy**

**Das solltest du sehen:** `Apply (Produktion)` startet und endet mit

```
Apply complete! Resources: 2 added, 0 changed, 1 destroyed.

Outputs:

public_ip = "54.210.12.34"
ssh_befehl = "ssh -i ~/.ssh/my-first-ssh-key.pem ubuntu@54.210.12.34"
webseite = "http://54.210.12.34"
...
```

Warte etwa **eine Minute** (nginx wird installiert) und öffne die Adresse aus `webseite` im Browser – mit `http://`, **ohne s**.

### Schritt 7: Die Nachvollziehbarkeit bewundern

Schau dir an, was du jetzt alles **ohne Zusatzaufwand** dokumentiert hast:

| Frage                                       | Wo steht die Antwort?                                                    |
| ------------------------------------------- | ------------------------------------------------------------------------ |
| **Was** wurde geändert?                     | Im PR unter **Files changed**                                            |
| **Warum** wurde es geändert?                | In der Beschreibung des PRs und in den Commit-Nachrichten                |
| **Was hat die Änderung in AWS bewirkt?**    | In der Summary des Laufs **Terraform Deploy**                            |
| **Wer** hat es freigegeben – und wann?      | **Settings** → **Environments** bzw. im Repository rechts **Deployments** |
| **Welcher Code** läuft gerade in Produktion? | Der letzte Commit auf `main` mit grünem Deploy-Lauf                     |

---

## Aufgabe 8: Aufräumen per Pipeline

Auch `terraform destroy` läuft jetzt über die Pipeline – mit einer zusätzlichen Sicherung gegen versehentliches Klicken.

### Schritt 1: Der Destroy-Workflow

Branch anlegen (`git switch main && git pull && git switch -c feature/destroy`) und `.github/workflows/terraform-destroy.yml` anlegen:

```yaml
name: Terraform Destroy

on:
  workflow_dispatch:
    inputs:
      bestaetigung:
        description: 'Zum Bestätigen "destroy" eintippen'
        required: true
        type: string

concurrency:
  group: terraform-production
  cancel-in-progress: false

env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_REGION: us-east-1
  TF_VAR_vorname: ${{ vars.VORNAME }}
  TF_VAR_key_name: ${{ vars.KEY_NAME }}
  TF_IN_AUTOMATION: "true"

jobs:
  destroy:
    name: Terraform Destroy
    if: inputs.bestaetigung == 'destroy'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Code auschecken
        uses: actions/checkout@v5

      - name: Terraform installieren
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false

      - name: Init
        run: terraform init -input=false

      - name: Destroy
        run: terraform destroy -input=false -auto-approve
```

| Teil                                   | Bedeutung                                                                                                     |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `inputs:`                              | Beim Klick auf **Run workflow** erscheint ein **Eingabefeld**                                                 |
| `if: inputs.bestaetigung == 'destroy'` | Steht dort etwas anderes als `destroy`, wird der Job übersprungen – ein Tippfehler löscht also nichts         |
| `environment: production`              | Auch das Löschen braucht eine **Freigabe**                                                                    |
| `concurrency: terraform-production`    | Dieselbe Gruppe wie beim Deployment – ein Destroy läuft nie gleichzeitig mit einem Apply                      |
| `-auto-approve`                        | Bei `destroy` gibt es keinen gespeicherten Plan – ohne diese Option würde Terraform auf ein `yes` warten, das nie kommt |

PR öffnen, mergen.

> **Warum läuft hier `Terraform Plan` im PR, obwohl sich an der Infrastruktur nichts ändert?** Der CI-Workflow läuft bei **jedem** PR. Sein Plan zeigt korrekt `No changes`. Der Destroy-Workflow selbst läuft durch das Mergen **nicht** – er hat nur `workflow_dispatch`.

### Schritt 2: Ausführen

1. Reiter **Actions** → links **Terraform Destroy** → **Run workflow**
2. Zuerst zum Testen etwas Falsches eintippen, z. B. `weg damit` → **Run workflow**. Der Job wird **übersprungen**
3. Noch einmal, diesmal mit `destroy`
4. Die Freigabe erteilen (**Review deployments** → **Approve and deploy**)

**Das solltest du am Ende sehen:**

```
Destroy complete! Resources: 10 destroyed.
```

Prüfe in der AWS-Konsole: Die Instanz steht auf **Terminated**, das VPC ist verschwunden.

> **Achtung:** Nach dem Destroy liegt auf `main` immer noch der Code, der die Infrastruktur beschreibt. Der nächste Merge auf `main` würde alles **wieder anlegen**. Das ist kein Fehler, sondern genau das Prinzip: `main` beschreibt den Wunschzustand.

### Schritt 3: Was übrig bleibt

| Was                                     | Aufräumen?                                                                                                                         |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **S3-Bucket** (State)                   | Wie in Kapitel 08: erst **nach** dem Destroy über **S3** → **Empty** → **Delete** – oder für das nächste Mal stehen lassen          |
| **Schlüsselpaar**                       | Kostet nichts, kann bleiben                                                                                                        |
| **Access Key** des `terraform`-Benutzers | Brauchst du die Pipeline nicht mehr: in **IAM** → Benutzer `terraform` → **Security credentials** → Access Key **deaktivieren** und löschen. Danach die Secrets in GitHub löschen |
| **GitHub-Repository**                   | Kann bleiben – ohne gültige Secrets kann die Pipeline nichts mehr in AWS anrichten                                                 |

---

## Zusatzaufgabe 1: Den Plan als Kommentar in den PR schreiben

Die Summary ist praktisch – noch bequemer ist es, wenn der Plan direkt **als Kommentar im PR** erscheint. Ergänze in `terraform-ci.yml`:

1. Auf der obersten Ebene (z. B. direkt vor `env:`) die Berechtigung, Kommentare zu schreiben:

```yaml
permissions:
  contents: read
  pull-requests: write
```

2. Als letzten Step im Job `plan`:

```yaml
      - name: Plan als PR-Kommentar
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const { execSync } = require('child_process');
            const plan = execSync('terraform show -no-color tfplan').toString();
            const body = [
              '### Terraform Plan',
              '<details><summary>Plan anzeigen</summary>',
              '',
              '```',
              plan.length > 60000 ? plan.slice(0, 60000) + '\n… (gekürzt)' : plan,
              '```',
              '</details>',
            ].join('\n');
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body,
            });
```

**Zum Knobeln:** Was ist der Nachteil, wenn bei jedem Push auf den Branch ein **neuer** Kommentar entsteht? Wie könnte man das lösen?

<details>
<summary>Lösung</summary>

Bei vielen Pushes wird der PR mit Kommentaren zugemüllt, und man weiß nicht mehr, welcher Plan aktuell ist. Besser: Mit `github.rest.issues.listComments` den eigenen alten Kommentar suchen (z. B. anhand der Überschrift `### Terraform Plan`) und ihn mit `github.rest.issues.updateComment` **aktualisieren** statt einen neuen anzulegen.

</details>

## Zusatzaufgabe 2: Drift erkennen – jede Nacht

**Drift** heißt: Jemand hat in der AWS-Konsole etwas **von Hand** geändert, und die Wirklichkeit weicht vom Code ab. Ein nächtlicher `plan` findet das.

Lege `.github/workflows/terraform-drift.yml` an (natürlich per PR):

```yaml
name: Terraform Drift

on:
  schedule:
    - cron: "0 6 * * 1-5"   # Mo–Fr um 06:00 UTC
  workflow_dispatch:
```

Übernimm `env:` aus `terraform-ci.yml` und baue einen Job mit `init` und

```bash
terraform plan -input=false -detailed-exitcode
```

Bei Exit-Code `2` (Änderungen gefunden) wird der Lauf **rot** – und GitHub schickt dir eine E-Mail.

Teste es: Ändere in der AWS-Konsole von Hand einen Tag deiner Instanz und starte den Workflow per **Run workflow**.

## Zusatzaufgabe 3: OIDC statt Access Keys

Ein Access Key in den GitHub-Secrets gilt **für immer**, bis jemand ihn löscht. Wird er gestohlen, kann der Dieb ihn ewig verwenden. Moderner ist **OIDC** (OpenID Connect): GitHub weist sich bei jedem Lauf gegenüber AWS aus, und AWS stellt **kurzlebige** Zugangsdaten aus, die nach einer Stunde verfallen. In den Secrets liegt dann **gar kein** Schlüssel mehr.

Grober Ablauf:

1. In **IAM** → **Identity providers** → **Add provider** → **OpenID Connect**, Provider-URL `https://token.actions.githubusercontent.com`, Audience `sts.amazonaws.com`
2. In **IAM** → **Roles** → **Create role** → **Web identity** → diesen Provider auswählen, auf **dein** Repository (und Branch `main`) einschränken, dieselben Rechte wie der Benutzer `terraform` vergeben
3. Im Workflow die Secrets aus `env:` entfernen und stattdessen ergänzen:

```yaml
permissions:
  id-token: write
  contents: read
```

```yaml
      - name: Bei AWS anmelden (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<ACCOUNT-ID>:role/<ROLLEN-NAME>
          aws-region: us-east-1
```

Die Action setzt danach – du ahnst es – die **Umgebungsvariablen** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` und `AWS_SESSION_TOKEN`, nur eben mit kurzlebigen Werten. Terraform merkt keinen Unterschied.

Anleitung: [Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

---

## Fehlerbehebung

| Fehlermeldung / Problem                                                     | Mögliche Ursache und Lösung                                                                                                                                       |
| --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Invalid workflow file` / Workflow taucht nicht auf                          | YAML-Einrückung falsch (Tabs statt Leerzeichen?) oder die Datei liegt nicht in `.github/workflows/`. GitHub zeigt die fehlerhafte Zeile im Reiter **Actions** an |
| `AWS_ACCESS_KEY_ID oder AWS_SECRET_ACCESS_KEY fehlt`                         | Secret nicht angelegt oder anders geschrieben als im Workflow. Groß-/Kleinschreibung prüfen                                                                      |
| `No valid credential sources found`                                          | Wie oben: Die Umgebungsvariablen sind leer                                                                                                                        |
| `InvalidClientTokenId` / `SignatureDoesNotMatch`                             | Wert des Secrets falsch (z. B. Leerzeichen mitkopiert) oder Access Key gelöscht/deaktiviert → Secret neu anlegen                                                  |
| `AccessDenied` bei `terraform init`                                         | Der Benutzer `terraform` darf nicht auf den S3-Bucket zugreifen → in IAM die S3-Rechte prüfen                                                                     |
| `UnauthorizedOperation` bei `plan` oder `apply`                             | Dem Benutzer `terraform` fehlen EC2- oder VPC-Rechte                                                                                                             |
| `No value for required variable` oder Ressourcen heißen nur `-vpc` / `-server` (ohne Vorname) | Die Variable `VORNAME` bzw. `KEY_NAME` fehlt unter **Variables** (nicht unter Secrets!) oder `TF_VAR_…` ist falsch geschrieben. Eine fehlende Variable wird im Workflow zu einem **leeren** Text |
| `terraform fmt -check` schlägt fehl (`exit code 3`)                          | Code lokal mit `terraform fmt` formatieren, committen, pushen                                                                                                     |
| `Backend initialization required` / State scheint leer, Plan will alles neu anlegen | Der `backend "s3"`-Block ist auskommentiert → ohne Remote Backend hat jeder Runner einen leeren State. Block einkommentieren                              |
| `Error acquiring the state lock`                                            | Ein anderer Lauf (oder dein Laptop) führt gerade Terraform aus. Warten. Hängt der Lock nach einem abgebrochenen Lauf: lokal `terraform force-unlock <Lock-ID>`    |
| `the current package for registry.terraform.io/hashicorp/aws … doesn't match any of the checksums` | Die `.terraform.lock.hcl` enthält nur Prüfsummen für dein Betriebssystem → lokal `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64` ausführen und committen |
| `Saved plan is stale`                                                       | Zwischen Plan und Freigabe wurde der State verändert → Deploy-Workflow per **Run workflow** neu starten                                                           |
| `GH013: Repository rule violations`                                          | Direkter Push auf `main` – richtig so! Branch anlegen und PR öffnen                                                                                               |
| Check `Terraform Plan` beim Ruleset nicht auswählbar                         | Der Job ist noch nie gelaufen → Workflow einmal per **Run workflow** starten                                                                                      |
| Merge-Knopf grau, Check steht auf `Expected — Waiting for status to be reported` | Der geforderte Check heißt anders als der Job (`name:`) – oder der Workflow reagiert nicht auf `pull_request`                                                 |
| Kein gelber Kasten **Waiting for review**                                   | Environment heißt nicht exakt `production`, oder **Required reviewers** ist nicht gesetzt (bei privaten Repos im kostenlosen Plan nicht verfügbar)              |
| `Apply (Produktion)` wird immer übersprungen                                | Der Plan hat keine Änderungen gefunden – das ist korrekt. Zum Testen eine Änderung an den `.tf`-Dateien mergen                                                   |
| `InvalidKeyPair.NotFound`                                                   | Wert der Variable `KEY_NAME` stimmt nicht mit dem Schlüsselpaar in `us-east-1` überein                                                                           |

## Kontrollfragen

- Was ist eine **Umgebungsvariable**? Was bewirkt `export`, und wie lange lebt eine Variable?
- In welcher Reihenfolge sucht Terraform nach AWS-Zugangsdaten?
- Wie wird aus der Umgebungsvariablen `TF_VAR_key_name` eine Terraform-Variable?
- Was ist der Unterschied zwischen **Secrets** und **Variables** in GitHub? Nenne je ein Beispiel.
- Warum steht im Log `***`, obwohl der Befehl die Access Key ID ausgibt? Reicht das als Schutz?
- Warum wäre die Pipeline **ohne** Remote Backend unbrauchbar?
- Warum läuft in der Pipeline `terraform fmt` **vor** `terraform plan`?
- Was bewirkt `-input=false`, und warum ist es in einer Pipeline wichtig?
- Was ist ein **Pull Request**, und welche zwei Arten von Prüfung finden darin statt?
- Welche Regeln hast du für `main` eingerichtet – und warum gelten sie auch für Admins?
- Warum gilt bei Infrastruktur-Code oft „`main` = Produktion“?
- Was ist der Unterschied zwischen `terraform apply -auto-approve` und `terraform apply tfplan`?
- Wozu dient `concurrency` im Deploy-Workflow?
- Was bedeuten die Exit-Codes `0`, `1` und `2` bei `terraform plan -detailed-exitcode`?
- Warum braucht der Apply-Job ein **Artifact**, um an die Plan-Datei zu kommen?
- Was ist ein **Environment** in GitHub, und wie macht es aus Continuous Deployment ein Continuous Delivery?
- Nach dem Destroy-Workflow ist alles gelöscht. Was passiert beim nächsten Merge auf `main`?
- Warum ist OIDC sicherer als ein Access Key in den Secrets?
