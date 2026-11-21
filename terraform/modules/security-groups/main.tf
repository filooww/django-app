resource "aws_security_group" "django" {
  name        = "${var.name}-django"
  description = "Django application server"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-django" }
}

resource "aws_security_group" "postgres" {
  name        = "${var.name}-postgres"
  description = "PostgreSQL server"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-postgres" }
}

# Django inbound

resource "aws_vpc_security_group_ingress_rule" "django_ssh" {
  count = var.enable_ssh ? 1 : 0

  security_group_id = aws_security_group.django.id
  description       = "SSH from admin"
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "django_app" {
  for_each = toset(concat([var.admin_cidr], var.app_allowed_cidrs))

  security_group_id = aws_security_group.django.id
  description       = "Django app"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = var.app_port
  to_port           = var.app_port
}

# Django outbound

resource "aws_vpc_security_group_egress_rule" "django_to_postgres" {
  security_group_id            = aws_security_group.django.id
  description                  = "PostgreSQL"
  referenced_security_group_id = aws_security_group.postgres.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_egress_rule" "django_https" {
  security_group_id = aws_security_group.django.id
  description       = "HTTPS: GHCR, Docker repo, AWS APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "django_http" {
  security_group_id = aws_security_group.django.id
  description       = "HTTP: Ubuntu apt mirrors"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# PostgreSQL inbound

resource "aws_vpc_security_group_ingress_rule" "postgres_from_django" {
  security_group_id            = aws_security_group.postgres.id
  description                  = "PostgreSQL from Django"
  referenced_security_group_id = aws_security_group.django.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "postgres_ssh" {
  count = var.enable_ssh ? 1 : 0

  security_group_id = aws_security_group.postgres.id
  description       = "SSH from admin"
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

# PostgreSQL outbound

resource "aws_vpc_security_group_egress_rule" "postgres_all" {
  security_group_id = aws_security_group.postgres.id
  description       = "Package updates, CloudWatch, SSM"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
