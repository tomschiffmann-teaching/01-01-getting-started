# Lösung: Zusatzaufgabe Fargate

Endstand nach der [Zusatzaufgabe](../Readme.md#zusatzaufgabe-fargate-statt-ec2) – die App läuft **nur noch** auf Fargate, die EC2-Instanz ist abgeschafft.

Ausgangspunkt ist [loesung/](../loesung/). Gegenüber diesem Stand ändert sich:

| Datei                                                        | Änderung                                                                         |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| [infra/fargate.tf](./infra/fargate.tf)                       | **neu**: ECS-Cluster, Log Group, Execution Role, Task Definition, Security Group, Service |
| [infra/outputs.tf](./infra/outputs.tf)                       | **ersetzt**: `ecs_cluster` und `ecs_service` statt `instance_id`, `public_ip`, `webapp_url` |
| [.github/workflows/cd.yml](./.github/workflows/cd.yml)       | **ersetzt**: Job `deploy-fargate` statt `deploy-ec2`                             |
| `infra/ec2.tf`, `infra/iam.tf`                               | **löschen**                                                                      |
| `infra/variables.tf`                                         | optional: Variable `host_port` löschen                                           |

Alle anderen Dateien (`app/`, `ci.yml`, `destroy.yml`, `providers.tf`, `vpc.tf`, `ecr.tf`) bleiben **unverändert**.

> **Zwischenschritt (Schritt 1 und 2 der Zusatzaufgabe):** Wer EC2 und Fargate eine Zeit lang **parallel** betreiben will, behält `ec2.tf`, `iam.tf` und den Job `deploy-ec2`, ergänzt `fargate.tf`, hängt die beiden neuen Outputs an die alte `outputs.tf` an und kopiert den Job `deploy-fargate` zusätzlich in die alte `cd.yml`.

Die App ist danach unter `http://<öffentliche-IP-des-Tasks>:3000` erreichbar – die URL steht in der Zusammenfassung des Workflows **CD**.
