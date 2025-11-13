#provider "aws" {
#  region = "ap-south-1"
#}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

terraform {
  backend "s3" {
    bucket = "my-ecs-tf-state-bucket-12344321"
    key    = "ecs/terraform.tfstate"
    region = "ap-south-1"
    encrypt = true
  }
}

# Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for ECS tasks
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Allow HTTP inbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "my-ecs-cluster"
}

# IAM Role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Attach AmazonECSTaskExecutionRolePolicy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


variable "docker_image_tag" {
  description = "Docker image tag for ECS"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "this" {
  family                   = "my-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "my-app"
      image     = "490617140445.dkr.ecr.ap-south-1.amazonaws.com/my-app:${var.docker_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# ALB
#resource "aws_lb" "this" {
#  name               = "ecs-alb"
#  load_balancer_type = "application"
#  security_groups    = [aws_security_group.ecs_sg.id]
#  subnets            = data.aws_subnets.default.ids
#}

#resource "aws_lb_target_group" "this" {
#  name     = "ecs-tg"
#  port     = 80
#  protocol = "HTTP"
#  vpc_id   = data.aws_vpc.default.id
#  target_type = "ip"   # 👈 Important for Fargate

#  health_check {
#    path = "/"
#    port = "80"
#  }
#}

#resource "aws_lb_listener" "http" {
#  load_balancer_arn = aws_lb.this.arn
#  port              = "80"
#  protocol          = "HTTP"
#
#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.this.arn
#  }
#}

# ECS Service
resource "aws_ecs_service" "this" {
  name            = "my-ecs-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  #load_balancer {
  #  target_group_arn = aws_lb_target_group.this.arn
  #  container_name   = "my-app"
  #  container_port   = 80
  #}

  #depends_on = [aws_lb_listener.http]
#}

#output "alb_dns_name" {
#  value = aws_lb.this.dns_name
#}
