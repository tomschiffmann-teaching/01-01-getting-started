# Beispiel: Fertige Terraform-Pipeline

Die Lösungsdateien zu [TERRAFORM-PIPELINE.md](../TERRAFORM-PIPELINE.md) – jeweils im **Endstand** nach allen Aufgaben.

| Datei                                                                         | Aus Aufgabe | Wann läuft der Workflow?                    |
| ----------------------------------------------------------------------------- | ----------- | ------------------------------------------- |
| [auth-check/main.tf](./auth-check/main.tf)                                    | 1 und 2     | – (Mini-Projekt „Wer bin ich?“)             |
| [.github/workflows/terraform-auth.yml](./.github/workflows/terraform-auth.yml)       | 2           | Push auf `main`, Knopfdruck                 |
| [.github/workflows/terraform-ci.yml](./.github/workflows/terraform-ci.yml)           | 3 und 4     | Pull Request nach `main`, Knopfdruck        |
| [.github/workflows/terraform-deploy.yml](./.github/workflows/terraform-deploy.yml)   | 5 und 6     | Push auf `main` (= gemergter PR), Knopfdruck |
| [.github/workflows/terraform-destroy.yml](./.github/workflows/terraform-destroy.yml) | 8           | Nur per Knopfdruck mit Eingabe `destroy`    |

Der Terraform-Code selbst (`providers.tf`, `vpc.tf`, `ec2.tf`, `variables.tf`, `outputs.tf`, `.gitignore`) kommt aus [08-terraform/beispiel-1](../../08-terraform/beispiel-1/) – mit **einkommentiertem** `backend "s3"`-Block.

> **Wichtig:** GitHub führt Workflows **nur** aus, wenn der Ordner `.github/workflows/` im **Hauptordner** eines Repositories liegt. Hier im Kurs-Repository liegen die Dateien in einem Unterordner und laufen deshalb **nicht** – kopiere sie in dein eigenes Repository `terraform-pipeline`.

Im Repository brauchst du außerdem (siehe Aufgabe 2, 3 und 6):

| Wo                                                   | Name                    | Wert                                         |
| ---------------------------------------------------- | ----------------------- | -------------------------------------------- |
| **Settings** → **Secrets and variables** → Secrets   | `AWS_ACCESS_KEY_ID`     | Access Key ID des IAM-Benutzers `terraform`  |
| **Settings** → **Secrets and variables** → Secrets   | `AWS_SECRET_ACCESS_KEY` | Secret Access Key des IAM-Benutzers `terraform` |
| **Settings** → **Secrets and variables** → Variables | `VORNAME`               | Dein Vorname                                 |
| **Settings** → **Secrets and variables** → Variables | `KEY_NAME`              | Name deines Schlüsselpaars in `us-east-1`    |
| **Settings** → **Environments**                      | `production`            | Required reviewers: du; nur Branch `main`    |
| **Settings** → **Rules** → **Rulesets**              | `main-schutz`           | PR erforderlich, Check `Terraform Plan` muss grün sein |
