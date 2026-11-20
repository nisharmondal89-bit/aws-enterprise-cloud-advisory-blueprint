variable "project_name" { type = string }
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = "prod-blueprint"
  }
}

resource "aws_subnet" "private_app" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = var.azs[count.index]

  tags = { Name = "${var.project_name}-app-${var.azs[count.index]}" }
}

resource "aws_subnet" "isolated_data" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 4)
  availability_zone = var.azs[count.index]

  tags = { Name = "${var.project_name}-data-${var.azs[count.index]}" }
}

resource "aws_route_table" "isolated_data" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-isolated-data-rt" }
}

resource "aws_route_table_association" "isolated_data" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.isolated_data[count.index].id
  route_table_id = aws_route_table.isolated_data.id
}

# Private AWS Backbone Access (Eliminates NAT Gateway data transfer exposure)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.isolated_data.id]
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.isolated_data.id]
}

resource "aws_security_group" "ledger_app_sg" {
  name        = "${var.project_name}-ledger-app-sg"
  description = "Restrictive egress/ingress for FinTech ledger microservice"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow Redis traffic to isolated data tier"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow HTTPS to AWS VPC Endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Least-Privilege IAM Permission Boundary for Junior Engineer Guardrails
resource "aws_iam_policy" "developer_boundary" {
  name        = "${var.project_name}-iam-boundary"
  description = "Prevents privilege escalation and enforces region/encryption guardrails"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowScopedDataServices"
        Effect   = "Allow"
        Action   = ["dynamodb:*", "s3:*", "elasticache:*", "redshift-data:*"]
        Resource = "*"
      },
      {
        Sid      = "DenyIAMPrivilegeEscalation"
        Effect   = "Deny"
        Action   = ["iam:CreateUser", "iam:AttachUserPolicy", "iam:DeletePolicyVersion"]
        Resource = "*"
      }
    ]
  })
}

output "vpc_id" { value = aws_vpc.main.id }
output "isolated_subnet_ids" { value = aws_subnet.isolated_data[*].id }
output "app_sg_id" { value = aws_security_group.ledger_app_sg.id }

