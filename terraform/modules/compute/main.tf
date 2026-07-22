# Variables d'entrée
variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "team_name" {
  description = "Nom du binôme"
  type        = string
}

variable "region" {
  description = "Région AWS"
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

variable "alb_target_group_arn" {
  description = "ARN du target group de l'ALB"
  type        = string
}

variable "db_address" {
  description = "Adresse de la base de données"
  type        = string
}

variable "db_username" {
  description = "Nom d'utilisateur de la base"
  type        = string
}

variable "db_credentials_secret_arn" {
  description = "ARN du secret DB"
  type        = string
}

variable "image_tag" {
  description = "Tag de l'image Docker"
  type        = string
  default     = "latest"
}

variable "tags" {
  description = "Tags communs"
  type        = map(string)
  default     = {}
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-${var.team_name}-app"
  retention_in_days = 7
  tags              = var.tags
}

# Rôle d'exécution ECS
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-${var.team_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Politique d'exécution ECS de base
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Politique pour accéder aux secrets
resource "aws_iam_policy" "ecs_execution_secrets" {
  name        = "${var.project_name}-${var.team_name}-ecs-execution-secrets"
  description = "Permet au role d'exécution ECS de lire les secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect = "Allow"
        Resource = [var.db_credentials_secret_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_secrets" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = aws_iam_policy.ecs_execution_secrets.arn
}

# Politique pour les logs CloudWatch
resource "aws_iam_policy" "ecs_execution_logs" {
  name        = "${var.project_name}-${var.team_name}-ecs-execution-logs"
  description = "Permet à ECS d'écrire les logs dans CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_logs" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = aws_iam_policy.ecs_execution_logs.arn
}

# Rôle de tâche ECS
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-${var.team_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Cluster ECS
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.team_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

# ECR Repository
resource "aws_ecr_repository" "petclinic" {
  name = "${var.project_name}-${var.team_name}-petclinic"
  tags = var.tags
}

# Task Definition ECS
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-${var.team_name}-app"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = 256
  memory                  = 512
  execution_role_arn      = aws_iam_role.ecs_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "petclinic"
      image = "${aws_ecr_repository.petclinic.repository_url}:${var.image_tag}"
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "postgresql"
        },
        {
          name  = "DB_HOST"
          value = var.db_address
        },
        {
          name  = "DB_USER"
          value = var.db_username
        }
      ]
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.db_credentials_secret_arn}:password::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = var.tags
}

# Service ECS Fargate
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-${var.team_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.app_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "petclinic"
    container_port   = 8080
  }

  depends_on = [
    aws_iam_role.ecs_execution,
    aws_iam_role_policy_attachment.ecs_execution_secrets
  ]

  tags = var.tags
}

# Outputs
output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.petclinic.repository_url
}
