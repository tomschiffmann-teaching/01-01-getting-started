# ---------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------
resource "aws_security_group" "server" {
  name        = "${var.vorname}-webapp-sg"
  description = "Firewall fuer den Web-App-Server"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.vorname}-webapp-sg"
  }
}

# Eingehend: HTTP auf dem Host-Port (Standard: 80) von überall
# Kein SSH (Port 22) nötig – das Deployment läuft über SSM!
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.server.id
  description       = "HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = var.host_port
  to_port           = var.host_port
}

# Ausgehend: alles erlaubt (Pakete installieren, Images aus ECR ziehen, SSM)
resource "aws_vpc_security_group_egress_rule" "alles" {
  security_group_id = aws_security_group.server.id
  description       = "Alles nach draussen"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------------------------------------------------------
# Server
# ---------------------------------------------------------------

# Amazon Linux 2023: AWS CLI und SSM-Agent sind schon vorinstalliert
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.server.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2.name

  # Wird beim ERSTEN Start einmalig als root ausgeführt: Docker installieren
  user_data = <<-SKRIPT
    #!/bin/bash
    set -eux
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user
  SKRIPT

  # Ändert sich das Skript, wird die Instanz neu gebaut (sonst liefe es nie wieder)
  user_data_replace_on_change = true

  tags = {
    Name = "${var.vorname}-webapp-server"
  }
}
