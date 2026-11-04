# ---------------------------------------------------------------
# ECR: Unsere private Container-Registry (wie Docker Hub, nur bei AWS)
# ---------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name = "${var.vorname}-webapp"

  # MUTABLE: Der Tag "latest" darf auf ein neues Image zeigen
  image_tag_mutability = "MUTABLE"

  # Erlaubt "terraform destroy", auch wenn noch Images im Repository liegen
  force_delete = true

  # Jedes Image wird beim Push automatisch auf bekannte Sicherheitslücken geprüft
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.vorname}-webapp"
  }
}

# Aufräumregel: Nur die 10 neuesten Images behalten (Speicher kostet Geld)
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Nur die letzten 10 Images behalten"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
