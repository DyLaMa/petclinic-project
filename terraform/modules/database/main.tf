# Variables d'entrée
variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "team_name" {
  description = "Nom du binôme"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs des subnets privés"
  type        = list(string)
}

variable "app_sg_id" {
  description = "ID du security group de l'application"
  type        = string
}

variable "db_password" {
  description = "Mot de passe de la base"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags communs"
  type        = map(string)
  default     = {}
}

# Subnet group pour RDS
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.team_name}-db-subnet-group"
  description = "Subnet group for RDS"
  subnet_ids  = var.private_subnet_ids
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.team_name}-db-subnet-group"
  })
}

# Security Group - RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.team_name}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from application"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.team_name}-rds-sg"
  })
}

# Instance RDS PostgreSQL Multi-AZ
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.team_name}-db"

  engine         = "postgres"
  engine_version = "16.3"
  instance_class = "db.t4g.micro"

  allocated_storage   = 20
  storage_type        = "gp2"
  storage_encrypted   = true

  db_name  = "petclinic"
  username = "petclinic_user"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  multi_az            = true
  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.team_name}-rds"
  })
}

# AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}-${var.team_name}-db-credentials"
  description = "Credentials for PetClinic database"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = var.db_password
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}

# Outputs
output "db_instance" {
  value = aws_db_instance.main
}

output "db_password" {
  value     = var.db_password
  sensitive = true
}

output "db_credentials_secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}

output "db_security_group_id" {
  value = aws_security_group.rds.id
}

output "db_address" {
  value = aws_db_instance.main.address
}

output "db_username" {
  value = aws_db_instance.main.username
}
