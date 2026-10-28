variable "vorname" {
  description = "Dein Vorname – wird den Namen aller Ressourcen vorangestellt"
  type        = string
}

variable "instance_type" {
  description = "Die Größe der EC2-Instanz"
  type        = string
  default     = "t3.micro"
}

variable "key_name"        {
  description = "Name des Schlüsselpaars, das du in der AWS-Konsole angelegt hast"
  type        = string
  default     = "<DEIN_SCHLUESSELPAAR_NAME>"
}
