# ---------------------------------------------------------------
# Zusatzaufgabe: Die Web-App auf AWS Fargate (ECS) statt auf EC2
# ---------------------------------------------------------------
# Fargate = "Container ohne Server": Wir sagen AWS nur, WELCHES Image
# mit WIE VIEL CPU/RAM laufen soll. Eine EC2-Instanz, Docker-Installation
# oder SSM brauchen wir nicht mehr.

# Der Cluster: eine logische Gruppe für unsere Services
resource "aws_ecs_cluster" "main" {
  name = "${var.vorname}-cluster"
}

# Hier landen die Logs des Containers (statt "docker logs")
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.vorname}-webapp"
  retention_in_days = 7
}

# ---------------------------------------------------------------
# Execution Role: Mit dieser Rolle zieht ECS das Image aus ECR
# und schreibt die Logs nach CloudWatch
# ---------------------------------------------------------------
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${var.vorname}-webapp-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------
# Task Definition: der "Bauplan" – vergleichbar mit einem
# "docker run"-Befehl bzw. einem Kubernetes-Pod
# ---------------------------------------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.vorname}-webapp"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # jeder Task bekommt eine eigene Netzwerkkarte + IP
  cpu                      = "256"    # 0,25 vCPU
  memory                   = "512"    # 512 MB
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "webapp"
    image     = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true

    # Bei awsvpc gibt es kein Port-Mapping: Host-Port = Container-Port
    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = [{
      name  = "PLATTFORM"
      value = "Fargate"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "webapp"
      }
    }
  }])
}

# ---------------------------------------------------------------
# Firewall für die Fargate-Tasks
# ---------------------------------------------------------------
resource "aws_security_group" "fargate" {
  name        = "${var.vorname}-webapp-fargate-sg"
  description = "Firewall fuer die Fargate-Tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.vorname}-webapp-fargate-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "fargate_http" {
  security_group_id = aws_security_group.fargate.id
  description       = "App-Port"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = var.container_port
  to_port           = var.container_port
}

# Ausgehend: nötig, damit der Task das Image aus ECR ziehen kann
resource "aws_vpc_security_group_egress_rule" "fargate_alles" {
  security_group_id = aws_security_group.fargate.id
  description       = "Alles nach draussen"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------------------------------------------------------
# Service: sorgt dafür, dass IMMER desired_count Tasks laufen
# (stirbt einer, startet ECS automatisch einen neuen – wie ein
# Kubernetes-Deployment)
# ---------------------------------------------------------------
resource "aws_ecs_service" "app" {
  name            = "${var.vorname}-webapp"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.fargate.id]
    assign_public_ip = true # ohne öffentliche IP kein Zugriff auf ECR (und kein Browser-Zugriff)
  }
}
