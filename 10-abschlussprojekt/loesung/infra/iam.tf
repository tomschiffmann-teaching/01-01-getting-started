# ---------------------------------------------------------------
# IAM-Rolle für die EC2-Instanz
# ---------------------------------------------------------------
# Die Instanz braucht eigene Rechte, um
#  1. Images aus ECR zu ziehen (docker pull)
#  2. Befehle über den SSM-Agenten zu empfangen (Deployment aus der Pipeline)
# Dafür bekommt sie eine ROLLE statt eines Access Keys – die Schlüssel
# erneuert AWS automatisch, nichts Geheimes liegt auf dem Server.

# Wer darf die Rolle annehmen? -> Der EC2-Dienst
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.vorname}-webapp-ec2-rolle"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Recht 1: Images aus ECR lesen
resource "aws_iam_role_policy_attachment" "ecr_lesen" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Recht 2: Vom Systems Manager (SSM) verwaltet werden
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Das Instance Profile ist der "Halter", über den die Rolle an die Instanz kommt
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.vorname}-webapp-ec2-profil"
  role = aws_iam_role.ec2.name
}
