# Lösung: Abschlussprojekt (EC2)

Die Lösungsdateien zu den Aufgaben 1–8 aus [Readme.md](../Readme.md) – im **Endstand**.

| Datei                                                                  | Aus Aufgabe | Wann läuft der Workflow?                      |
| ---------------------------------------------------------------------- | ----------- | --------------------------------------------- |
| [.gitignore](./.gitignore)                                             | 1           | –                                             |
| [app/server.js](./app/server.js), [app/server.test.js](./app/server.test.js), [app/package.json](./app/package.json) | 2 | – |
| [app/Dockerfile](./app/Dockerfile), [app/.dockerignore](./app/.dockerignore) | 2     | –                                             |
| [infra/providers.tf](./infra/providers.tf), [infra/variables.tf](./infra/variables.tf), [infra/vpc.tf](./infra/vpc.tf) | 3 | – |
| [infra/ecr.tf](./infra/ecr.tf), [infra/iam.tf](./infra/iam.tf), [infra/ec2.tf](./infra/ec2.tf), [infra/outputs.tf](./infra/outputs.tf) | 3 | – |
| [.github/workflows/ci.yml](./.github/workflows/ci.yml)                 | 4           | Pull Request nach `main`, Knopfdruck          |
| [.github/workflows/cd.yml](./.github/workflows/cd.yml)                 | 5 und 6     | Push auf `main` (= gemergter PR), Knopfdruck  |
| [.github/workflows/destroy.yml](./.github/workflows/destroy.yml)       | 8           | Nur per Knopfdruck mit Eingabe `destroy`      |

> **Wichtig:** GitHub führt Workflows **nur** aus, wenn der Ordner `.github/workflows/` im **Hauptordner** eines Repositorys liegt. Hier im Kurs-Repository liegen die Dateien in einem Unterordner und laufen deshalb **nicht** – kopiere den Inhalt dieses Ordners in dein eigenes Repository `abschlussprojekt`.

Vorher anpassen:

- [infra/providers.tf](./infra/providers.tf): `bucket = "terraform-state-DEIN-NAME-12345"` → dein S3-Bucket aus Kapitel 08

Im Repository brauchst du außerdem (siehe Aufgabe 0 und 4):

| Wo                                                   | Name                    | Wert                                                  |
| ---------------------------------------------------- | ----------------------- | ----------------------------------------------------- |
| **Settings** → **Secrets and variables** → Secrets   | `AWS_ACCESS_KEY_ID`     | Access Key ID des IAM-Benutzers `terraform`           |
| **Settings** → **Secrets and variables** → Secrets   | `AWS_SECRET_ACCESS_KEY` | Secret Access Key des IAM-Benutzers `terraform`       |
| **Settings** → **Secrets and variables** → Variables | `VORNAME`               | Dein Vorname in Kleinbuchstaben                       |
| **Settings** → **Rules** → **Rulesets**              | `main-schutz`           | PR erforderlich, Checks `App testen`, `Docker-Image testen`, `Terraform Plan` müssen grün sein |

Lokal ausprobieren (ohne AWS):

```bash
cd app && npm test && cd ..
docker build --build-arg APP_VERSION=lokal -t webapp:lokal app
docker run --rm -p 8080:3000 webapp:lokal     # → http://localhost:8080
cd infra && terraform init -backend=false && terraform validate
```
