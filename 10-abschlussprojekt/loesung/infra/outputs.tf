output "ecr_repository_url" {
  description = "Adresse des ECR-Repositorys (ohne Tag)"
  value       = aws_ecr_repository.app.repository_url
}

output "instance_id" {
  description = "ID der EC2-Instanz – brauchen wir für das Deployment über SSM"
  value       = aws_instance.server.id
}

output "public_ip" {
  description = "Die öffentliche IP-Adresse der Instanz"
  value       = aws_instance.server.public_ip
}

output "webapp_url" {
  description = "Hier ist die Web-App erreichbar"
  value       = "http://${aws_instance.server.public_ip}:${var.host_port}"
}
