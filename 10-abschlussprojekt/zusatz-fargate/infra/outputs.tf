output "ecr_repository_url" {
  description = "Adresse des ECR-Repositorys (ohne Tag)"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster" {
  description = "Name des ECS-Clusters"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service" {
  description = "Name des ECS-Services"
  value       = aws_ecs_service.app.name
}
